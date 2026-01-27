import 'package:flutter/foundation.dart';
import 'package:quietspot/models/quiet_spot.dart';

/// Time periods for temporal bucketing
enum TimePeriod {
  night,    // 00:00 - 06:00
  morning,  // 06:00 - 12:00
  afternoon, // 12:00 - 18:00
  evening;   // 18:00 - 24:00
  
  String get label {
    switch (this) {
      case TimePeriod.night: return 'Night';
      case TimePeriod.morning: return 'Morning';
      case TimePeriod.afternoon: return 'Afternoon';
      case TimePeriod.evening: return 'Evening';
    }
  }
}

/// Day type categorization
enum DayType {
  weekday,
  weekend;
  
  String get label {
    switch (this) {
      case DayType.weekday: return 'Weekday';
      case DayType.weekend: return 'Weekend';
    }
  }
}

/// Data freshness levels
enum DataFreshness {
  fresh,              // < 60 min old
  predictedConfident, // 40+ measurements
  predictedModerate,  // 20-39 measurements
  predictedLimited,   // < 20 measurements
  unknown;            // No data
  
  String get label {
    switch (this) {
      case DataFreshness.fresh: return 'Fresh Data';
      case DataFreshness.predictedConfident: return 'Confident';
      case DataFreshness.predictedModerate: return 'Moderate Confidence';
      case DataFreshness.predictedLimited: return 'Limited Data';
      case DataFreshness.unknown: return 'Unknown';
    }
  }
  
  String get description {
    switch (this) {
      case DataFreshness.fresh: return 'Updated within the last hour';
      case DataFreshness.predictedConfident: return 'Predicted based on 40+ measurements';
      case DataFreshness.predictedModerate: return 'Predicted based on 20-39 measurements';
      case DataFreshness.predictedLimited: return 'Limited data available';
      case DataFreshness.unknown: return 'No data available';
    }
  }
}

/// Measurement data from API
class Measurement {
  final String id;
  final String spotId;
  final int? userId;
  final double noiseDb;
  final DateTime timestamp;
  
  Measurement({
    required this.id,
    required this.spotId,
    this.userId,
    required this.noiseDb,
    required this.timestamp,
  });
  
  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'].toString(),
      spotId: json['spotId'].toString(),
      userId: json['userId'] as int?,
      noiseDb: (json['noiseDb'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'].toString()),
    );
  }
}

/// Result of prediction calculation
class PredictionResult {
  final double? predictedNoiseDb;
  final DataFreshness freshness;
  final int measurementCount;
  final TimePeriod timePeriod;
  final DayType dayType;
  
  PredictionResult({
    this.predictedNoiseDb,
    required this.freshness,
    required this.measurementCount,
    required this.timePeriod,
    required this.dayType,
  });
}

/// Service for predicting spot values based on temporal patterns
class PredictionService {
  // Constants
  static const int freshnessThresholdMinutes = 60;
  static const int limitedDataThreshold = 20;
  static const int moderateDataThreshold = 40;
  static const int recentDataDays = 30; // Consider last 30 days
  static const int highWeightDays = 14; // Last 14 days get higher weight
  static const double recentDataWeight = 2.0; // 2x weight for recent data
  
  /// Get time period for a given DateTime
  static TimePeriod getTimePeriod(DateTime time) {
    final hour = time.hour;
    if (hour >= 0 && hour < 6) return TimePeriod.night;
    if (hour >= 6 && hour < 12) return TimePeriod.morning;
    if (hour >= 12 && hour < 18) return TimePeriod.afternoon;
    return TimePeriod.evening;
  }
  
  /// Get day type (weekday/weekend) for a given DateTime
  static DayType getDayType(DateTime time) {
    // DateTime.weekday: 1 = Monday, 7 = Sunday
    return (time.weekday == 6 || time.weekday == 7) 
        ? DayType.weekend 
        : DayType.weekday;
  }
  
  /// Calculate data freshness based on lastUpdated and measurement count
  static DataFreshness calculateFreshness({
    required DateTime? lastUpdated,
    required int measurementCount,
  }) {
    if (lastUpdated == null) {
      return measurementCount == 0 
          ? DataFreshness.unknown 
          : DataFreshness.predictedLimited;
    }
    
    final now = DateTime.now();
    final ageMinutes = now.difference(lastUpdated).inMinutes;
    
    // Check if data is fresh (< 60 min old)
    if (ageMinutes < freshnessThresholdMinutes) {
      return DataFreshness.fresh;
    }
    
    // Data is not fresh, determine prediction confidence
    if (measurementCount == 0) {
      return DataFreshness.unknown;
    } else if (measurementCount < limitedDataThreshold) {
      return DataFreshness.predictedLimited;
    } else if (measurementCount < moderateDataThreshold) {
      return DataFreshness.predictedModerate;
    } else {
      return DataFreshness.predictedConfident;
    }
  }
  
  /// Predict noise level based on historical measurements
  static PredictionResult predictValues({
    required List<Measurement> measurements,
    DateTime? targetTime,
  }) {
    final target = targetTime ?? DateTime.now();
    final targetPeriod = getTimePeriod(target);
    final targetDayType = getDayType(target);
    
    if (measurements.isEmpty) {
      return PredictionResult(
        predictedNoiseDb: null,
        freshness: DataFreshness.unknown,
        measurementCount: 0,
        timePeriod: targetPeriod,
        dayType: targetDayType,
      );
    }
    
    // Determine freshness level
    final latestMeasurement = measurements.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
    final freshness = calculateFreshness(
      lastUpdated: latestMeasurement.timestamp,
      measurementCount: measurements.length,
    );
    
    // If data is fresh, use the latest measurement directly
    if (freshness == DataFreshness.fresh) {
      return PredictionResult(
        predictedNoiseDb: latestMeasurement.noiseDb,
        freshness: freshness,
        measurementCount: measurements.length,
        timePeriod: targetPeriod,
        dayType: targetDayType,
      );
    }
    
    // Apply prediction logic based on confidence tier
    double predictedDb;
    
    if (measurements.length < limitedDataThreshold) {
      // Limited data: Simple average
      predictedDb = _calculateSimpleAverage(measurements);
    } else if (measurements.length < moderateDataThreshold) {
      // Moderate data: Filter by time period only
      predictedDb = _calculateModerateAverage(measurements, targetPeriod, target);
    } else {
      // Confident prediction: Full temporal filtering
      predictedDb = _calculateConfidentAverage(
        measurements, 
        targetPeriod, 
        targetDayType,
        target,
      );
    }
    
    return PredictionResult(
      predictedNoiseDb: predictedDb,
      freshness: freshness,
      measurementCount: measurements.length,
      timePeriod: targetPeriod,
      dayType: targetDayType,
    );
  }
  
  /// Simple average of all measurements
  static double _calculateSimpleAverage(List<Measurement> measurements) {
    if (measurements.isEmpty) return 0.0;
    
    final sum = measurements.fold<double>(
      0.0, 
      (sum, m) => sum + m.noiseDb,
    );
    return sum / measurements.length;
  }
  
  /// Moderate average: Filter by time period with recent data weighting
  static double _calculateModerateAverage(
    List<Measurement> measurements,
    TimePeriod targetPeriod,
    DateTime targetTime,
  ) {
    final cutoffDate = targetTime.subtract(Duration(days: recentDataDays));
    final recentWeightCutoff = targetTime.subtract(Duration(days: highWeightDays));
    
    // Filter by time period and recency
    final relevant = measurements.where((m) {
      return m.timestamp.isAfter(cutoffDate) &&
             getTimePeriod(m.timestamp) == targetPeriod;
    }).toList();
    
    if (relevant.isEmpty) {
      // Fallback to simple average if no matching time period
      return _calculateSimpleAverage(measurements);
    }
    
    // Apply time decay weighting
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (final m in relevant) {
      final weight = m.timestamp.isAfter(recentWeightCutoff) 
          ? recentDataWeight 
          : 1.0;
      weightedSum += m.noiseDb * weight;
      totalWeight += weight;
    }
    
    return weightedSum / totalWeight;
  }
  
  /// Confident average: Full temporal filtering + exponential decay
  static double _calculateConfidentAverage(
    List<Measurement> measurements,
    TimePeriod targetPeriod,
    DayType targetDayType,
    DateTime targetTime,
  ) {
    final cutoffDate = targetTime.subtract(Duration(days: recentDataDays));
    final recentWeightCutoff = targetTime.subtract(Duration(days: highWeightDays));
    
    // Filter by time period, day type, and recency
    final relevant = measurements.where((m) {
      return m.timestamp.isAfter(cutoffDate) &&
             getTimePeriod(m.timestamp) == targetPeriod &&
             getDayType(m.timestamp) == targetDayType;
    }).toList();
    
    if (relevant.isEmpty) {
      // Fallback to moderate average if no matching pattern
      debugPrint('No matching temporal pattern, falling back to moderate average');
      return _calculateModerateAverage(measurements, targetPeriod, targetTime);
    }
    
    // Apply exponential time decay weighting
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (final m in relevant) {
      final weight = m.timestamp.isAfter(recentWeightCutoff) 
          ? recentDataWeight 
          : 1.0;
      weightedSum += m.noiseDb * weight;
      totalWeight += weight;
    }
    
    return weightedSum / totalWeight;
  }
}
