import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

class NoiseMeasurementService {
  NoiseReading? _noiseReading;
  StreamSubscription<NoiseReading>? _subscription;
  bool _isRecording = false;
  final List<double> _measurements = [];

  /// Request microphone permission
  Future<bool> requestPermission() async {
    debugPrint('NoiseMeasurementService: Requesting microphone permission...');
    try {
      final status = await Permission.microphone.request();
      debugPrint('NoiseMeasurementService: Permission status = $status');
      debugPrint('NoiseMeasurementService: Permission isGranted = ${status.isGranted}');
      debugPrint('NoiseMeasurementService: Permission isDenied = ${status.isDenied}');
      debugPrint('NoiseMeasurementService: Permission isPermanentlyDenied = ${status.isPermanentlyDenied}');
      debugPrint('NoiseMeasurementService: Permission isLimited = ${status.isLimited}');
      debugPrint('NoiseMeasurementService: Permission isRestricted = ${status.isRestricted}');
      return status.isGranted;
    } catch (e, stackTrace) {
      debugPrint('NoiseMeasurementService: Error requesting permission: $e');
      debugPrint('NoiseMeasurementService: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start measuring noise level
  /// Returns true if started successfully, false otherwise
  Future<bool> startMeasuring({
    required Function(double db) onData,
    Function(String error)? onError,
  }) async {
    if (_isRecording) {
      return true;
    }

    // Clear previous measurements
    _measurements.clear();

    // Check permission first
    debugPrint('NoiseMeasurementService: Checking permission...');
    final hasPerm = await hasPermission();
    debugPrint('NoiseMeasurementService: hasPermission = $hasPerm');
    
    if (!hasPerm) {
      debugPrint('NoiseMeasurementService: Requesting permission...');
      // Request permission
      final granted = await requestPermission();
      debugPrint('NoiseMeasurementService: Permission granted = $granted');
      
      if (!granted) {
        final currentStatus = await Permission.microphone.status;
        debugPrint('NoiseMeasurementService: Current permission status after request: $currentStatus');
        if (currentStatus.isPermanentlyDenied) {
          onError?.call('Permission has been permanently denied. Please enable it from device settings.');
        } else {
          onError?.call('Microphone permission not granted. Please enable it from settings.');
        }
        return false;
      }
    }

    // Double check permission after request
    final finalPermissionCheck = await hasPermission();
    debugPrint('NoiseMeasurementService: Final permission check = $finalPermissionCheck');
    
    if (!finalPermissionCheck) {
      onError?.call('No microphone access permission');
      return false;
    }

    try {
      debugPrint('NoiseMeasurementService: Creating NoiseMeter...');
      final noiseMeter = NoiseMeter();
      
      debugPrint('NoiseMeasurementService: Starting to listen to noise stream...');
      _subscription = noiseMeter.noise.listen(
        (NoiseReading reading) {
          if (!_isRecording) {
            debugPrint('NoiseMeasurementService: Received reading but not recording, ignoring');
            return;
          }
          
          _noiseReading = reading;
          // Convert to dB (noise_meter gives meanDecibel)
          final db = reading.meanDecibel;
          debugPrint('NoiseMeasurementService: Received dB reading: $db');
          
          // Validate dB value (should be reasonable)
          if (db.isFinite && !db.isNaN) {
            // Store measurement for averaging
            _measurements.add(db);
            onData(db);
          } else {
            debugPrint('NoiseMeasurementService: Invalid dB value: $db');
          }
        },
        onError: (error) {
          debugPrint('NoiseMeasurementService: Stream error: $error');
          _isRecording = false;
          onError?.call('Error during measurement: $error');
        },
        cancelOnError: false,
      );
      
      _isRecording = true;
      debugPrint('NoiseMeasurementService: Started successfully, isRecording = $_isRecording');
      return true;
    } catch (e, stackTrace) {
      debugPrint('NoiseMeasurementService: Exception: $e');
      debugPrint('NoiseMeasurementService: Stack trace: $stackTrace');
      _isRecording = false;
      onError?.call('Unable to start measurement: $e');
      return false;
    }
  }

  /// Stop measuring
  void stopMeasuring() {
    _subscription?.cancel();
    _subscription = null;
    _isRecording = false;
    _noiseReading = null;
  }

  /// Get last measured value
  double? getLastValue() {
    return _noiseReading?.meanDecibel;
  }

  /// Get average of all measurements
  double? getAverageValue() {
    if (_measurements.isEmpty) {
      return null;
    }
    final sum = _measurements.reduce((a, b) => a + b);
    return sum / _measurements.length;
  }

  /// Get all measurements
  List<double> getMeasurements() {
    return List.unmodifiable(_measurements);
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Dispose resources
  void dispose() {
    stopMeasuring();
    _measurements.clear();
  }
}

