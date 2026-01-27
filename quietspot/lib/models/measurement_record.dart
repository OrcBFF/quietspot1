/// Represents a single noise measurement record with metadata
import 'package:quietspot/models/noise_level.dart';

class MeasurementRecord {
  MeasurementRecord({
    required this.id,
    required this.spotId,
    required this.noiseDb,
    this.noiseLevel,
    required this.timestamp,
    this.userId,
    this.deviceId,
    this.trustScore,
    this.isValidated,
    this.validationNotes,
  });

  final String id;
  final String spotId; // ID of the spot being measured
  final double noiseDb; // Measured dB value
  final NoiseLevel? noiseLevel; // Classified noise level
  final DateTime timestamp;
  final String? userId; // User who made the measurement (optional for privacy)
  final String? deviceId; // Device identifier for tracking device-specific issues
  final double? trustScore; // 0.0 to 1.0, calculated trustworthiness
  final bool? isValidated; // Whether this measurement passed validation
  final String? validationNotes; // Notes about validation (e.g., "outlier", "matches nearby")

  MeasurementRecord copyWith({
    String? id,
    String? spotId,
    double? noiseDb,
    NoiseLevel? noiseLevel,
    DateTime? timestamp,
    String? userId,
    String? deviceId,
    double? trustScore,
    bool? isValidated,
    String? validationNotes,
  }) {
    return MeasurementRecord(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      noiseDb: noiseDb ?? this.noiseDb,
      noiseLevel: noiseLevel ?? this.noiseLevel,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      trustScore: trustScore ?? this.trustScore,
      isValidated: isValidated ?? this.isValidated,
      validationNotes: validationNotes ?? this.validationNotes,
    );
  }

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) {
    return MeasurementRecord(
      id: json['id'] as String,
      spotId: json['spotId'] as String,
      noiseDb: (json['noiseDb'] as num).toDouble(),
      noiseLevel: json['noiseLevel'] != null 
          ? NoiseLevel.values.firstWhere((e) => e.name == json['noiseLevel'], orElse: () => NoiseLevel.moderate)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String?,
      deviceId: json['deviceId'] as String?,
      trustScore: json['trustScore'] != null ? (json['trustScore'] as num).toDouble() : null,
      isValidated: json['isValidated'] as bool?,
      validationNotes: json['validationNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'spotId': spotId,
      'noiseDb': noiseDb,
      if (noiseLevel != null) 'noiseLevel': noiseLevel!.name,
      'timestamp': timestamp.toIso8601String(),
      if (userId != null) 'userId': userId,
      if (deviceId != null) 'deviceId': deviceId,
      if (trustScore != null) 'trustScore': trustScore,
      if (isValidated != null) 'isValidated': isValidated,
      if (validationNotes != null) 'validationNotes': validationNotes,
    };
  }
}

