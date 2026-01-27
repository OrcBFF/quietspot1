import 'package:quietspot/models/noise_level.dart';

class NoiseClassificationService {
  /// Maps a decibel value to a [NoiseLevel].
  /// 
  /// Thresholds are approx:
  /// < 40: Silent
  /// < 60: Quiet
  /// < 75: Moderate
  /// < 90: Loud
  /// >= 90: Extreme
  NoiseLevel classify(double db) {
    if (db < 40) return NoiseLevel.silent;
    if (db < 60) return NoiseLevel.quiet;
    if (db < 75) return NoiseLevel.moderate;
    if (db < 90) return NoiseLevel.loud;
    return NoiseLevel.extreme;
  }


}
