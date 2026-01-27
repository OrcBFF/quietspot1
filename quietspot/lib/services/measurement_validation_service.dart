import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:quietspot/models/measurement_record.dart';
import 'package:quietspot/models/quiet_spot.dart';
import 'package:quietspot/models/user_trust_profile.dart';
import 'package:quietspot/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for validating noise measurements and detecting outliers
class MeasurementValidationService {
  static const String _measurementsKey = 'measurement_records';
  static const String _trustProfilesKey = 'user_trust_profiles';
  
  // Validation parameters
  static const double _maxReasonableDb = 120.0; // Max reasonable dB for normal environments
  static const double _minReasonableDb = 20.0; // Min reasonable dB (absolute silence is ~0dB)
  static const double _outlierThreshold = 2.5; // Standard deviations for outlier detection
  static const double _nearbyRadiusMeters = 100.0; // Radius to consider "nearby" spots

  /// Validate a measurement against nearby spots and historical data
  Future<ValidationResult> validateMeasurement({
    required double noiseDb,
    required LatLng location,
    required String spotId,
    String? userId,
    String? deviceId,
    List<QuietSpot>? nearbySpots,
  }) async {
    // Basic sanity check
    if (noiseDb < _minReasonableDb || noiseDb > _maxReasonableDb) {
      return ValidationResult(
        isValid: false,
        trustScore: 0.1,
        notes: 'Measurement outside reasonable range (${noiseDb.toStringAsFixed(1)}dB)',
        isOutlier: true,
      );
    }

    // Load historical measurements for this spot
    final spotHistory = await _getSpotMeasurementHistory(spotId);
    
    // Load nearby measurements from API if not provided
    final nearbyMeasurements = <double>[];
    try {
      final nearbyData = await ApiService.getNearbyMeasurements(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusMeters: _nearbyRadiusMeters,
      );
      
      for (final data in nearbyData) {
        if (data['avgDb'] != null) {
          nearbyMeasurements.add((data['avgDb'] as num).toDouble());
        }
      }
    } catch (e) {
      debugPrint('Error fetching nearby measurements from API: $e');
      // Fallback to provided nearbySpots if API fails
      if (nearbySpots != null) {
    for (final spot in nearbySpots) {
      if (spot.noiseDb != null && spot.latitude != null && spot.longitude != null) {
        final distance = _calculateDistance(
          location,
          LatLng(spot.latitude!, spot.longitude!),
        );
        if (distance <= _nearbyRadiusMeters) {
          nearbyMeasurements.add(spot.noiseDb!);
            }
          }
        }
      }
    }

    // Combine spot history and nearby measurements
    final allMeasurements = <double>[
      ...spotHistory.map((r) => r.noiseDb),
      ...nearbyMeasurements,
    ];

    double trustScore = 0.5; // Start with neutral score
    String? notes;
    bool isOutlier = false;

    if (allMeasurements.isNotEmpty) {
      // Statistical analysis
      final mean = _calculateMean(allMeasurements);
      final stdDev = _calculateStdDev(allMeasurements, mean);
      
      // Check if measurement is an outlier
      final zScore = (noiseDb - mean) / (stdDev > 0 ? stdDev : 1.0);
      isOutlier = zScore.abs() > _outlierThreshold;

      if (isOutlier) {
        trustScore = 0.3;
        notes = 'Measurement differs significantly from nearby spots (${noiseDb.toStringAsFixed(1)}dB vs avg ${mean.toStringAsFixed(1)}dB)';
      } else {
        // Calculate trust score based on how close to mean
        final distanceFromMean = (noiseDb - mean).abs();
        final normalizedDistance = stdDev > 0 ? distanceFromMean / stdDev : 0.0;
        
        // Trust score: closer to mean = higher trust
        trustScore = (1.0 - (normalizedDistance / _outlierThreshold)).clamp(0.3, 1.0);
        
        if (normalizedDistance < 0.5) {
          notes = 'Measurement matches nearby spots well';
        } else {
          notes = 'Measurement slightly differs from nearby spots';
        }
      }
    } else {
      // First measurement at this location - moderate trust
      trustScore = 0.6;
      notes = 'First measurement at this location';
    }

    // Adjust trust score based on user history
    if (userId != null) {
      final userProfile = await getUserTrustProfile(userId);
      if (userProfile != null) {
        // Weight: 70% current validation, 30% user history
        trustScore = (trustScore * 0.7) + (userProfile.overallTrustScore * 0.3);
      }
    }

    return ValidationResult(
      isValid: trustScore >= 0.4, // Accept if trust score >= 0.4
      trustScore: trustScore,
      notes: notes,
      isOutlier: isOutlier,
      meanNearby: allMeasurements.isNotEmpty ? _calculateMean(allMeasurements) : null,
      stdDevNearby: allMeasurements.isNotEmpty ? _calculateStdDev(allMeasurements, _calculateMean(allMeasurements)) : null,
    );
  }

  /// Store a measurement record
  Future<void> storeMeasurement(MeasurementRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_measurementsKey) ?? [];
    
    recordsJson.add(jsonEncode(record.toJson()));
    await prefs.setStringList(_measurementsKey, recordsJson);
    
    // Update user trust profile
    if (record.userId != null) {
      await _updateUserTrustProfile(record);
    }

    // Upload to backend if possible
    try {
      final int? locationId = int.tryParse(record.spotId);
      final int? userId = int.tryParse(record.userId ?? '');
      
      // Only upload if we have a valid location ID (existing spot)
      // If locationId is null (e.g. "new_..."), we can't upload yet.
      // Ideally, the spot creation should handle uploading pending measurements,
      // but for now we fix the case for existing spots.
      if (locationId != null) {
        await ApiService.createMeasurement(
          locationId: locationId.toString(),
          userId: userId, // Can be null (anonymous)
          noiseDb: record.noiseDb,
        );
      }
    } catch (e) {
      debugPrint('Failed to upload measurement: $e');
    }
  }

  /// Get measurement history for a specific spot
  Future<List<MeasurementRecord>> _getSpotMeasurementHistory(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_measurementsKey) ?? [];
    
    final records = <MeasurementRecord>[];
    for (final jsonStr in recordsJson) {
      try {
        final record = MeasurementRecord.fromJson(jsonDecode(jsonStr));
        if (record.spotId == spotId) {
          records.add(record);
        }
      } catch (e) {
        debugPrint('Error parsing measurement record: $e');
      }
    }
    
    return records;
  }

  /// Get user trust profile
  Future<UserTrustProfile?> getUserTrustProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_trustProfilesKey);
    
    if (profilesJson == null) return null;
    
    try {
      final profiles = jsonDecode(profilesJson) as Map<String, dynamic>;
      final userProfileJson = profiles[userId];
      
      if (userProfileJson == null) return null;
      
      return UserTrustProfile.fromJson(userProfileJson as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading user trust profile: $e');
      return null;
    }
  }

  /// Update user trust profile based on a new measurement
  Future<void> _updateUserTrustProfile(MeasurementRecord record) async {
    if (record.userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_trustProfilesKey);
    
    Map<String, dynamic> profiles = {};
    if (profilesJson != null) {
      try {
        profiles = jsonDecode(profilesJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing trust profiles: $e');
      }
    }
    
    final existingProfile = profiles[record.userId!] != null
        ? UserTrustProfile.fromJson(profiles[record.userId!] as Map<String, dynamic>)
        : UserTrustProfile(userId: record.userId!, deviceId: record.deviceId);
    
    final newTotal = existingProfile.totalMeasurements + 1;
    final newValidated = existingProfile.validatedMeasurements + (record.isValidated == true ? 1 : 0);
    final newOutliers = existingProfile.outlierMeasurements + (record.trustScore != null && record.trustScore! < 0.4 ? 1 : 0);
    
    // Update average trust score
    final currentAvg = existingProfile.averageTrustScore;
    final newAvg = record.trustScore != null
        ? ((currentAvg * existingProfile.totalMeasurements) + record.trustScore!) / newTotal
        : currentAvg;
    
    final updatedProfile = existingProfile.copyWith(
      totalMeasurements: newTotal,
      validatedMeasurements: newValidated,
      outlierMeasurements: newOutliers,
      averageTrustScore: newAvg,
      lastMeasurementDate: record.timestamp,
    );
    
    profiles[record.userId!] = updatedProfile.toJson();
    await prefs.setString(_trustProfilesKey, jsonEncode(profiles));
  }

  /// Calculate distance between two coordinates in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  /// Calculate mean of a list of values
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation
  double _calculateStdDev(List<double> values, double mean) {
    if (values.isEmpty || values.length == 1) return 0.0;
    
    final variance = values
        .map((v) => math.pow(v - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(variance);
  }

  /// Get all measurements (for admin/debugging purposes)
  Future<List<MeasurementRecord>> getAllMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_measurementsKey) ?? [];
    
    final records = <MeasurementRecord>[];
    for (final jsonStr in recordsJson) {
      try {
        records.add(MeasurementRecord.fromJson(jsonDecode(jsonStr)));
      } catch (e) {
        debugPrint('Error parsing measurement record: $e');
      }
    }
    
    return records;
  }
}

/// Result of measurement validation
class ValidationResult {
  ValidationResult({
    required this.isValid,
    required this.trustScore,
    this.notes,
    this.isOutlier = false,
    this.meanNearby,
    this.stdDevNearby,
  });

  final bool isValid;
  final double trustScore; // 0.0 to 1.0
  final String? notes;
  final bool isOutlier;
  final double? meanNearby;
  final double? stdDevNearby;
}

