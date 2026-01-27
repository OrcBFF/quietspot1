/// Tracks user reputation and trustworthiness for measurements
class UserTrustProfile {
  UserTrustProfile({
    required this.userId,
    this.deviceId,
    this.totalMeasurements = 0,
    this.validatedMeasurements = 0,
    this.outlierMeasurements = 0,
    this.averageTrustScore = 0.5,
    this.lastMeasurementDate,
    this.calibrationOffset,
    this.calibrationConfidence,
  });

  final String userId;
  final String? deviceId;
  final int totalMeasurements;
  final int validatedMeasurements;
  final int outlierMeasurements;
  final double averageTrustScore; // 0.0 to 1.0
  final DateTime? lastMeasurementDate;
  final double? calibrationOffset; // User's calibration offset in dB
  final double? calibrationConfidence; // How confident we are in the calibration (0.0 to 1.0)

  /// Calculate overall trust score
  double get overallTrustScore {
    if (totalMeasurements == 0) return 0.5; // Neutral for new users
    
    // Base score from validation rate
    final validationRate = validatedMeasurements / totalMeasurements;
    
    // Penalty for outliers
    final outlierRate = outlierMeasurements / totalMeasurements;
    
    // Combine factors
    final score = (validationRate * 0.7) + (averageTrustScore * 0.3) - (outlierRate * 0.2);
    
    return score.clamp(0.0, 1.0);
  }

  /// Check if user is considered trustworthy
  bool get isTrustworthy => overallTrustScore >= 0.6;

  UserTrustProfile copyWith({
    String? userId,
    String? deviceId,
    int? totalMeasurements,
    int? validatedMeasurements,
    int? outlierMeasurements,
    double? averageTrustScore,
    DateTime? lastMeasurementDate,
    double? calibrationOffset,
    double? calibrationConfidence,
  }) {
    return UserTrustProfile(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      totalMeasurements: totalMeasurements ?? this.totalMeasurements,
      validatedMeasurements: validatedMeasurements ?? this.validatedMeasurements,
      outlierMeasurements: outlierMeasurements ?? this.outlierMeasurements,
      averageTrustScore: averageTrustScore ?? this.averageTrustScore,
      lastMeasurementDate: lastMeasurementDate ?? this.lastMeasurementDate,
      calibrationOffset: calibrationOffset ?? this.calibrationOffset,
      calibrationConfidence: calibrationConfidence ?? this.calibrationConfidence,
    );
  }

  factory UserTrustProfile.fromJson(Map<String, dynamic> json) {
    return UserTrustProfile(
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String?,
      totalMeasurements: json['totalMeasurements'] as int? ?? 0,
      validatedMeasurements: json['validatedMeasurements'] as int? ?? 0,
      outlierMeasurements: json['outlierMeasurements'] as int? ?? 0,
      averageTrustScore: json['averageTrustScore'] != null 
          ? (json['averageTrustScore'] as num).toDouble() 
          : 0.5,
      lastMeasurementDate: json['lastMeasurementDate'] != null
          ? DateTime.parse(json['lastMeasurementDate'] as String)
          : null,
      calibrationOffset: json['calibrationOffset'] != null
          ? (json['calibrationOffset'] as num).toDouble()
          : null,
      calibrationConfidence: json['calibrationConfidence'] != null
          ? (json['calibrationConfidence'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      if (deviceId != null) 'deviceId': deviceId,
      'totalMeasurements': totalMeasurements,
      'validatedMeasurements': validatedMeasurements,
      'outlierMeasurements': outlierMeasurements,
      'averageTrustScore': averageTrustScore,
      if (lastMeasurementDate != null) 'lastMeasurementDate': lastMeasurementDate!.toIso8601String(),
      if (calibrationOffset != null) 'calibrationOffset': calibrationOffset,
      if (calibrationConfidence != null) 'calibrationConfidence': calibrationConfidence,
    };
  }
}

