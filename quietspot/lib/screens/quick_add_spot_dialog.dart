import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:quietspot/models/measurement_record.dart';
import 'package:quietspot/models/quiet_spot.dart';

import 'package:quietspot/services/geocoding_service.dart';
import 'package:quietspot/services/location_service.dart';
import 'package:quietspot/services/measurement_validation_service.dart';
import 'package:quietspot/services/noise_measurement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final double startAngle;
  final double sweepAngle;

  _CircularGaugePainter({
    required this.progress,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class QuickAddSpotDialog extends StatefulWidget {
  const QuickAddSpotDialog({
    super.key,
    this.initialLocation,
    this.existingSpots = const [],
  });

  final LatLng? initialLocation;
  final List<QuietSpot> existingSpots;

  @override
  State<QuickAddSpotDialog> createState() => _QuickAddSpotDialogState();
}

class _QuickAddSpotDialogState extends State<QuickAddSpotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noiseService = NoiseMeasurementService();
  final _locationService = LocationService();
  final _geocodingService = GeocodingService();
  final _validationService = MeasurementValidationService();




  // State
  bool _isMeasuring = true; // Auto-start
  StreamSubscription<UserAccelerometerEvent>? _motionSubscription;
  static const double _motionThreshold = 2.0;
  String _debugSensorData = "";
  int _motionRestartCount = 0;
  DateTime? _lastMotionTime;
  bool _isSettling = false; // Settling period after motion detection

  // Shouting detection
  static const double _shoutingDbThreshold = 80.0; // High dB threshold
  static const double _shoutingVarianceThreshold = 15.0; // High variance threshold
  final List<double> _recentDbReadings = []; // For variance calculation
  static const int _varianceWindowSize = 10; // Last 10 readings


  int _elapsedSeconds = 0;

  static const int _measurementDuration = 5;
  
  double? _currentDb;
  double? _avgDb;
  double? _finalDb;

  ValidationResult? _validationResult;
  String? _errorMessage;
  String? _warningMessage;

  // Form Fields
  String _name = '';
  String _address = 'Detecting location...';
  String _description = '';
  PlaceType _placeType = PlaceType.other;
  LatLng? _location;
  
  // Nearby Spots
  List<QuietSpot> _nearbySpots = [];
  String? _selectedSpotId; // null = Create New, non-null = Update existing
  bool _isNewSpot = true;
  
  // Metadata
  String? _deviceId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserAndDeviceInfo();
    _startMeasurement(); // Auto-start measurement
    _fetchLocation();    // Auto-fetch location
  }


  Future<void> _loadUserAndDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    _userId = prefs.getString('user_id') ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    
    if (_deviceId == null) {
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', _deviceId!);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      if (_location == null) {
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          _location = LatLng(position.latitude, position.longitude);
        }
      }

      if (_location != null && mounted) {
        final result = await _geocodingService.getFullDetailsFromCoordinates(_location!);
        if (mounted && result != null) {
           setState(() {
             _address = result.displayName;
             _placeType = result.placeType;
             // Heuristic for name
             if (!result.displayName.startsWith(result.street ?? '')) {
                _name = result.displayName.split(',').first;
             }
           });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _address = 'Location unknown');
    }
  }

  Future<void> _startMeasurement() async {
      setState(() {
        _isMeasuring = true;
        _errorMessage = null;
        _warningMessage = null;
        _elapsedSeconds = 0;
        _currentDb = null;
        _motionRestartCount = 0;
        _lastMotionTime = null;
        _isSettling = false;
      });

      // Configure Audio Session for interruptions
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.record, // 'record' is simpler if we don't need output (except vibration). 'playAndRecord' is complex.
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers, // Revert to basic options compatible with 'record'
        avAudioSessionMode: AVAudioSessionMode.measurement,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.game, // Standard app usage. Ensures incoming calls steal focus (trigger interruption).
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientExclusive, // FORCE pause of other audio. Do not allow ducking.
        androidWillPauseWhenDucked: true,
      ));

      // ACTIVATE the session to actually take focus and get interruption callbacks
      // ACTIVATE the session to actually take focus and get interruption callbacks
      final bool activated = await session.setActive(true);
      if (activated) {
         debugPrint("AudioSession activated successfully");
      } else {
         debugPrint("AudioSession activation failed");
         // FAIL IMMEDIATELY if we can't take focus (e.g. Call in progress)
         _failMeasurement("Measurement Failed: Could not acquire audio focus. Are you in a call?");
         return;
      }

      // Listen for interruptions (e.g. phone call, alarm, other app audio)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
           if (mounted && _isMeasuring) {
             _failMeasurement("Measurement Failed: Audio interruption detected (call/notification/alarm).");
           }
        }
      });

      session.becomingNoisyEventStream.listen((_) {
         if (mounted && _isMeasuring) {
            _failMeasurement("Measurement Failed: Audio output changed (headphones unplugged/noisy).");
         }
      });
      
      // Also potentially listen to device changes if relevant, but becomingNoisy covers unplugging.

      // Start Motion Detection
      // Use UserAccelerometer to exclude gravity (simpler vibration/shake detection)
      // Add initial grace period (1 second) so the tap vibration doesn't trigger motion detection
      await Future.delayed(const Duration(milliseconds: 1000));
      
      _motionSubscription = userAccelerometerEventStream().listen((event) async {
          // Calculate magnitude of linear acceleration (gravity excluded)
          final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          
          // Threshold for "shaking" or "significant movement"
          // UserAccelerometer is sensitive. 0.5 - 1.0 is usually a good range for handling tremor vs shake.
          // Let's use the previously defined _motionThreshold or adjust it.
          // Since we compare against 0 now (no gravity), a threshold of 0.5 m/s^2 is sensitive enough for "holding steady".
          // REVISED: 1.5 - More forgiving for natural hand movement, still catches aggressive handling
          const double shakeThreshold = 1.5;

          if (magnitude > shakeThreshold) {
              if (mounted && !_isSettling) {
                // Debounce check
                if (_lastMotionTime != null && DateTime.now().difference(_lastMotionTime!) < const Duration(milliseconds: 300)) {
                   return;
                }
                _lastMotionTime = DateTime.now();

                // Vibrate warning
                if (await Vibration.hasVibrator() == true) {
                  Vibration.vibrate(duration: 200);
                }
                
                setState(() {
                   _motionRestartCount++;
                   
                   // 3 Strikes Logic (0, 1 = Warning; 2 = Fail on 3rd strike)
                   if (_motionRestartCount >= 3) {
                      _failMeasurement("Measurement Failed: Too much movement! Please keep the phone steady.");
                   } else {
                      _elapsedSeconds = 0; // Restart timer!
                      _isSettling = true; // Enter settling period
                      _warningMessage = "Settling... place phone down";
                   }
                });
                
                // Start settling period (1.5 seconds to place phone down)
                if (_isSettling && mounted) {
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (mounted && _isMeasuring) {
                    setState(() {
                      _isSettling = false;
                      _warningMessage = null; // Just clear the message
                    });
                  }
                }
              }
          }
      });

      // Start Noise Service
      final started = await _noiseService.startMeasuring(
        onData: (db) {
          if (mounted) {
            // Add to recent readings for variance calculation
            _recentDbReadings.add(db);
            if (_recentDbReadings.length > _varianceWindowSize) {
              _recentDbReadings.removeAt(0);
            }

            // Check for shouting pattern: high dB + high variance
            if (_recentDbReadings.length >= 5) {
              final variance = _calculateVariance(_recentDbReadings);
              if (db > _shoutingDbThreshold && variance > _shoutingVarianceThreshold) {
                _failMeasurement("Measurement failed: Voice detected! Please stay quiet.");
                return;
              }
            }

            setState(() {
               _currentDb = db;
            });
          }
        },
        onError: (err) {
          if (mounted) setState(() { _isMeasuring = false; _errorMessage = err; });
        },
      );

      if (!started) {
        if (_errorMessage == null && mounted) {
          setState(() {
            _isMeasuring = false;
            _errorMessage = 'Could not start microphone';
          });
        }
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel(); 
          return;
        }
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= _measurementDuration) {
          timer.cancel();
          _stopMeasurement();
        }
      });
  }

  Future<void> _stopMeasurement() async {
    _noiseService.stopMeasuring();
    
    final allMeasurements = _noiseService.getMeasurements();
    if (allMeasurements.isNotEmpty) {
      final rawAvg = allMeasurements.reduce((a, b) => a + b) / allMeasurements.length;
      
      final calibratedDb = rawAvg;
      
      // Validate
      // Load nearby spots for validation
      final location = _location ?? const LatLng(37.9838, 23.7275);
      // NOTE: Ideally we pass existing spots into this widget to avoid reloading pref twice
      // For now we'll do a quick load or skip advanced validation details if slow
      // BUT for "trusted" we need validation. simpler:
      
      final validation = await _validationService.validateMeasurement(
        noiseDb: calibratedDb,
        location: location,
        spotId: 'temp_new', // ID doesn't exist yet
        userId: _userId,
        deviceId: _deviceId,
      );

      if (mounted) {
        setState(() {
           _isMeasuring = false;
           _finalDb = calibratedDb;

           _validationResult = validation;
           
           // Find nearby spots
           _findNearbySpots();
         });
      }
    } else {
      if (mounted) {
         setState(() {
           _isMeasuring = false;
           _errorMessage = "No audio collected";
         });
      }
    }
  }
  
  @override
  void dispose() {
    _motionSubscription?.cancel();
    _recentDbReadings.clear();
    _noiseService.dispose();
    super.dispose();
  }

  void _failMeasurement(String reason) {
    if (!mounted || !_isMeasuring) return;
    setState(() {
      _isMeasuring = false;
      _errorMessage = reason;
    });
    _motionSubscription?.cancel();
    _recentDbReadings.clear();
    _noiseService.stopMeasuring();
    Vibration.vibrate(duration: 500);
  }

  /// Calculate variance of dB readings to detect voice patterns
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  void _findNearbySpots() {
    if (_location == null) return;
    
    final distance = const Distance();
    
    final nearby = widget.existingSpots.where((spot) {
      if (spot.latitude == null || spot.longitude == null) return false;
      
      final spotLoc = LatLng(spot.latitude!, spot.longitude!);
      final d = distance.as(LengthUnit.Meter, _location!, spotLoc);
      
      return d <= 50; // 50 meters radius
    }).toList();
    
    // Sort by distance
    nearby.sort((a, b) {
      final distA = distance.as(LengthUnit.Meter, _location!, LatLng(a.latitude!, a.longitude!));
      final distB = distance.as(LengthUnit.Meter, _location!, LatLng(b.latitude!, b.longitude!));
      return distA.compareTo(distB);
    });
    
    setState(() {
      _nearbySpots = nearby;
      // If we found spots, default to "New Spot" but show the list
      _isNewSpot = true;
      _selectedSpotId = null;
    });
  }

  void _onSpotSelectionChanged(String? spotId) {
    setState(() {
      _selectedSpotId = spotId;
      _isNewSpot = spotId == null;
      
      if (spotId != null) {
        // Pre-fill data from selected spot
        final spot = _nearbySpots.firstWhere((s) => s.id == spotId);
        _name = spot.name;
        // logic to keep other fields optional or pre-filled? 
        // Let's keep name pre-filled. Capacity should be updated by user now.
      } else {
        // Reset to "New Spot" defaults if we just switched back
        if (_name.isEmpty) {
           // Maybe re-apply heuristic?
           if (!_address.startsWith('Lat')) {
              _name = _address.split(',').first;
           }
        }
      }
    });
  }

  void _save() async {
     if (!_formKey.currentState!.validate()) return;
     if (_location == null) return;
     if (_finalDb == null) return;
     
     _formKey.currentState!.save();
     
     final spotId = DateTime.now().millisecondsSinceEpoch.toString();
     
     // Determine ID
     final String finalId = _isNewSpot ? spotId : _selectedSpotId!;
     
     // Store measurement record
     if (_validationResult != null) {
        final record = MeasurementRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          spotId: finalId, // Use the actual spot ID (new or existing)
          noiseDb: _finalDb!,
          timestamp: DateTime.now(),
          userId: _userId,
          deviceId: _deviceId,
          trustScore: _validationResult!.trustScore,
          isValidated: _validationResult!.isValid,
          validationNotes: _validationResult!.notes,
        );
        await _validationService.storeMeasurement(record);
     }
     
     // Map dB to Level
     int noiseLevel = 3;
     if (_finalDb! < 40) noiseLevel = 1;
     else if (_finalDb! < 55) noiseLevel = 2;
     else if (_finalDb! < 70) noiseLevel = 3;
     else if (_finalDb! < 85) noiseLevel = 4;
     else noiseLevel = 5;

     final spot = QuietSpot(
        id: finalId,
        name: _name.isNotEmpty ? _name : 'Quiet Spot',
        location: _address,
        description: _description,
        noiseLevel: noiseLevel,
        noiseDb: _finalDb,
        placeType: _placeType,
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        lastUpdated: DateTime.now(),
     );

     if (mounted) Navigator.of(context).pop(spot);
  }

  @override
  Widget build(BuildContext context) {


    // 1. Measuring Phase
    if (_isMeasuring) {
       return AlertDialog(
         title: const Text('Measuring Noise...'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             SizedBox(
               height: 150,
               width: 150,
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: _CircularGaugePainter(
                         progress: ((_currentDb ?? 30) - 30) / 70.0,
                         startAngle: -225 * (math.pi / 180),
                         sweepAngle: (((_currentDb ?? 30) - 30) / 70.0) * 270 * (math.pi / 180),
                      ),
                    ),
                    Text(
                      _currentDb != null ? '${_currentDb!.toStringAsFixed(0)} dB' : '--',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                 ],
               ),
             ),
             const SizedBox(height: 16),
             Text('Please stay quiet for ${_measurementDuration - _elapsedSeconds}s'),
             const SizedBox(height: 8),
              LinearProgressIndicator(value: _elapsedSeconds / _measurementDuration),
              if (_warningMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _warningMessage!,
                          style: const TextStyle(color: Colors.deepOrange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
           ],
         ),
       );
    }
    
    // 2. Error Phase
    if (_errorMessage != null) {
      return AlertDialog(
        title: const Text('Measurement Failed'),
        content: Text(_errorMessage!),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(onPressed: _startMeasurement, child: const Text('Retry')),
        ],
      );
    }

    // 3. Review & Add Details Phase
    return AlertDialog(
      scrollable: true,
      title: const Text('New Quiet Spot'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Result Header
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.blue[50],
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_finalDb!.toStringAsFixed(1)} dB', 
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),

                      ],
                    ),
                    if (_validationResult?.isOutlier == true)
                       const Icon(Icons.warning, color: Colors.orange)
                    else 
                       const Icon(Icons.check_circle, color: Colors.green),
                 ],
               ),
             ),
             const SizedBox(height: 16),
             
             // Location (Read-onlyish)
             Text('Location', style: Theme.of(context).textTheme.labelMedium),
             const SizedBox(height: 4),
             Text(_address, style: Theme.of(context).textTheme.bodyMedium),
             const SizedBox(height: 16),
             
             // Nearby Spots Selection
             if (_nearbySpots.isNotEmpty) ...[
               Container(
                 decoration: BoxDecoration(
                   border: Border.all(color: Colors.blue.shade200),
                   borderRadius: BorderRadius.circular(8),
                   color: Colors.blue.shade50.withOpacity(0.5),
                 ),
                 padding: const EdgeInsets.all(8),
                 margin: const EdgeInsets.only(bottom: 16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Icon(Icons.near_me, size: 16, color: Colors.blue.shade700),
                         const SizedBox(width: 8),
                         Text(
                           "Nearby Spots Found", 
                           style: TextStyle(
                             fontWeight: FontWeight.bold, 
                             color: Colors.blue.shade900
                           )
                         ),
                       ],
                     ),
                     const SizedBox(height: 8),
                     
                     // Option: New Spot
                     RadioListTile<String?>(
                       title: const Text("This is a new spot"),
                       value: null,
                       groupValue: _selectedSpotId,
                       onChanged: _onSpotSelectionChanged,
                       dense: true,
                       contentPadding: EdgeInsets.zero,
                     ),
                     
                     // Options: Nearby Spots
                     ..._nearbySpots.map((spot) {
                        final distance = const Distance().as(
                          LengthUnit.Meter, 
                          _location!, 
                          LatLng(spot.latitude!, spot.longitude!)
                        );
                        return RadioListTile<String?>(
                          title: Text(spot.name),
                          subtitle: Text("${distance}m away • ${spot.noiseLevel}/5 noise"),
                          value: spot.id,
                          groupValue: _selectedSpotId,
                          onChanged: _onSpotSelectionChanged,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                     }).toList(),
                   ],
                 ),
               ),
             ],

             // Name
             TextFormField(
               initialValue: _name,
               decoration: const InputDecoration(
                 labelText: 'Name (Optional)',
                 border: OutlineInputBorder(),
                 isDense: true,
               ),
               onSaved: (v) => _name = v ?? '',
             ),
             const SizedBox(height: 24),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Spot'),
        ),
      ],
    );
  }
}
