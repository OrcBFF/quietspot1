import 'package:flutter/foundation.dart';
import 'package:quietspot/services/prediction_service.dart';

enum PlaceType {
  library,
  cafe,
  park,
  office,
  home,
  other;

  String get label {
    switch (this) {
      case PlaceType.library: return 'Library/Study';
      case PlaceType.cafe: return 'Cafe/Restaurant';
      case PlaceType.park: return 'Park/Outdoor';
      case PlaceType.office: return 'Office/Cowork';
      case PlaceType.home: return 'Home/Private';
      case PlaceType.other: return 'Other';
    }
  }
}

class QuietSpot {
  QuietSpot({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.noiseLevel,
    this.noiseDb,
    this.placeType = PlaceType.other,
    this.latitude,
    this.longitude,
    this.lastUpdated,
    this.dataFreshness,
    this.measurementCount,
    this.trustTier,
    this.confidence,
  });

  final String id;
  final String name;
  final String location;
  final String description;
  final int noiseLevel; // 1–5
  final double? noiseDb; // dB measurement from microphone (null if not measured)
  final PlaceType placeType; // New field
  final double? latitude; // Map coordinates
  final double? longitude; // Map coordinates
  final DateTime? lastUpdated; // When the data was last refreshed
  final DataFreshness? dataFreshness; // Client-side: Freshness indicator
  final int? measurementCount; // Client-side: Number of measurements
  final String? trustTier; // Backend: Data Trust Policy tier (FRESH_DATA, CONFIDENT_PREDICTION, etc.)
  final String? confidence; // Backend: Confidence level (highest, high, medium, low, none)

  QuietSpot copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    int? noiseLevel,
    double? noiseDb,
    PlaceType? placeType,
    double? latitude,
    double? longitude,
    DateTime? lastUpdated,
    DataFreshness? dataFreshness,
    int? measurementCount,
    String? trustTier,
    String? confidence,
  }) {
    return QuietSpot(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      noiseLevel: noiseLevel ?? this.noiseLevel,
      noiseDb: noiseDb ?? this.noiseDb,
      placeType: placeType ?? this.placeType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dataFreshness: dataFreshness ?? this.dataFreshness,
      measurementCount: measurementCount ?? this.measurementCount,
      trustTier: trustTier ?? this.trustTier,
      confidence: confidence ?? this.confidence,
    );
  }

  factory QuietSpot.fromJson(Map<String, dynamic> json) {
    try {
      // Calculate noise level from dB value if available
      int calculatedNoiseLevel = 3; // default
      final noiseDb = json['noiseDb'] != null ? (json['noiseDb'] as num).toDouble() : null;
      if (noiseDb != null) {
        // Map dB to 1-5 scale
        if (noiseDb < 50) {
          calculatedNoiseLevel = 1; // Very quiet
        } else if (noiseDb < 60) {
          calculatedNoiseLevel = 2; // Quiet
        } else if (noiseDb < 70) {
          calculatedNoiseLevel = 3; // Moderate
        } else if (noiseDb < 80) {
          calculatedNoiseLevel = 4; // Loud
        } else {
          calculatedNoiseLevel = 5; // Very loud
        }
      }
      
      return QuietSpot(
        id: json['id'].toString(), // Safely convert to string
        name: json['name'] as String,
        location: json['location'] as String,
        description: json['description'] as String? ?? '', // Handle null description
        noiseLevel: json['noiseLevel'] is int ? json['noiseLevel'] as int : calculatedNoiseLevel,
        noiseDb: noiseDb,
        placeType: json['placeType'] != null 
            ? PlaceType.values.firstWhere(
                (e) => e.toString() == json['placeType'], 
                orElse: () => PlaceType.other
              )
            : PlaceType.other,
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
        lastUpdated: json['lastUpdated'] != null ? DateTime.tryParse(json['lastUpdated'].toString()) : null,
        measurementCount: json['measurementCount'] is int ? json['measurementCount'] as int : null,
        trustTier: json['trustTier'] as String?,
        confidence: json['confidence'] as String?,
      );
    } catch (e, stack) {
      debugPrint('Error parsing QuietSpot: $e');
      debugPrint('JSON was: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'noiseLevel': noiseLevel,
      'noiseDb': noiseDb,
      'placeType': placeType.toString(),
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }
}
