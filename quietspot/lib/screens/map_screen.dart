import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:quietspot/models/quiet_spot.dart';

import 'package:quietspot/screens/spot_detail_screen.dart';
import 'package:quietspot/services/api_service.dart';
import 'package:quietspot/services/location_service.dart';
import 'package:quietspot/screens/quick_add_spot_dialog.dart';
import 'package:quietspot/services/prediction_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const String _mapboxStyleId = String.fromEnvironment(
    'MAPBOX_STYLE_ID',
    defaultValue: 'mapbox/streets-v12',
  );
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  
  List<QuietSpot> _spots = [];
  bool _isLoading = true;
  LatLng _center = const LatLng(37.9838, 23.7275); // Default to Athens, Greece
  double _zoom = 13.0;
  LatLng? _userLocation;
  double _mapRotation = 0.0; // Track map rotation in degrees
  Timer? _autoRefreshTimer; // Periodic refresh timer

  // Filter state
  int _filterMaxNoise = 5; // 1-5, default 5 = show all
  DataFreshness _filterMinTrust = DataFreshness.unknown; // Minimum trust level

  bool get _hasMapboxToken => _mapboxAccessToken.isNotEmpty;

  String get _tileLayerUrl =>
      'https://api.mapbox.com/styles/v1/{styleId}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}';

  Map<String, String> get _tileLayerOptions => {
        'accessToken': _mapboxAccessToken,
        'styleId': _mapboxStyleId,
      };

  @override
  void initState() {
    super.initState();
    _loadSpots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
    
    // Start periodic auto-refresh (every 60 seconds)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !_isLoading) {
        _loadSpots();
      }
    });
  }



  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final spots = await ApiService.getLocations();
      setState(() {
        _spots = spots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading spots: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _upsertSpot(QuietSpot spot) async {
    try {
      QuietSpot saved;
      if (spot.id.isEmpty || !_spots.any((s) => s.id == spot.id)) {
        // Create new spot
        saved = await ApiService.createLocation(spot);
      } else {
        // Update existing spot
        saved = await ApiService.updateLocation(spot.id, spot);
      }
      
      setState(() {
        final index = _spots.indexWhere((s) => s.id == saved.id);
        if (index >= 0) {
          _spots[index] = saved;
        } else {
          _spots.add(saved);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spot saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving spot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initLocation() async {
    await _getUserLocation();
  }

  // Legacy no-op: POI loading was removed; kept to avoid stale references during hot reload.
  Future<void> _loadNearbyPois({LatLng? center}) async {}

  Future<bool> _getUserLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        debugPrint(
          'Location fix: lat=${position.latitude}, lon=${position.longitude}, accuracy=${position.accuracy}m',
        );
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _center = _userLocation!;
          _zoom = 14.0;
        });
        
        // Move map to user location
        _mapController.move(_center, _zoom);
        setState(() {
          _mapRotation = _mapController.camera.rotation;
        });
        return true;
      }
    } catch (e) {
      // Silently handle error - location is optional
      debugPrint('Error getting location: $e');
    }
    return false;
  }



  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Tapping on empty map space does nothing
    // Tapping on existing spot markers is handled by the marker's GestureDetector
  }

  Future<void> _showCreateSpotDialog(LatLng location) async {
    // Show Quick Add Dialog with initial location
    final created = await showDialog<QuietSpot>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickAddSpotDialog(initialLocation: location),
    );

    if (created != null) {
      await _upsertSpot(created);
      // Immediate refresh for user feedback (freshness badge update)
      // Other users' updates are synced via periodic auto-refresh
      await _loadSpots();
    }
  }

  /// Get count of active filters
  int get _activeFilterCount {
    int count = 0;
    if (_filterMaxNoise < 5) count++;
    if (_filterMinTrust != DataFreshness.unknown) count++;
    return count;
  }

  /// Get filtered spots based on current filter settings
  List<QuietSpot> _getFilteredSpots() {
    return _spots.where((spot) {
      
      // Filter by noise level
      if (spot.noiseLevel > _filterMaxNoise) return false;
      
      // Filter by trust level (freshness)
      if (_filterMinTrust != DataFreshness.unknown) {
        final freshness = PredictionService.calculateFreshness(
          lastUpdated: spot.lastUpdated,
          measurementCount: spot.measurementCount ?? 1,
        );
        // Trust levels in order: Best -> Worst
        final trustOrder = [
          DataFreshness.fresh,
          DataFreshness.predictedConfident,
          DataFreshness.predictedModerate,
          DataFreshness.predictedLimited,
          DataFreshness.unknown
        ];
        
        final spotTrustIndex = trustOrder.indexOf(freshness);
        final selectedTrustIndex = trustOrder.indexOf(_filterMinTrust);
        
        // We want spots that are "better or equal" (lower or equal index)
        // e.g. if selected is Moderate (2), we accept Fresh(0), Confident(1), Moderate(2)
        if (spotTrustIndex > selectedTrustIndex) return false;
      }
      
      return true;
    }).toList();
  }

  /// Show filter bottom sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Spots',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _filterMaxNoise = 5;
                          _filterMinTrust = DataFreshness.unknown;
                        });
                        setState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Noise Level Slider
                const SizedBox(height: 8),
                Text(
                  'Maximum Noise Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _filterMaxNoise == 5 ? 'Any noise level' : 'Up to level $_filterMaxNoise',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                Slider(
                  value: _filterMaxNoise.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _filterMaxNoise == 5 ? 'Any' : _filterMaxNoise.toString(),
                  onChanged: (value) {
                    setSheetState(() => _filterMaxNoise = value.round());
                    setState(() {});
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Very Quiet', style: Theme.of(context).textTheme.bodySmall),
                    Text('Any', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const Divider(),
                
                // Trust Level Slider
                const SizedBox(height: 8),
                Text(
                  'Minimum Data Trust',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _filterMinTrust == DataFreshness.unknown 
                      ? 'Any trust level' 
                      : 'At least ${_filterMinTrust.label}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                Builder(
                  builder: (context) {
                    // Logic: Strict (Fresh) -> Lenient (Any)
                    // Matches the "Show More" direction of the Noise slider
                    final trustOrder = [
                      DataFreshness.fresh,
                      DataFreshness.predictedConfident,
                      DataFreshness.predictedModerate,
                      DataFreshness.predictedLimited,
                      DataFreshness.unknown
                    ];
                    final currentIndex = trustOrder.indexOf(_filterMinTrust).toDouble();
                    
                    return Column(
                      children: [
                        Slider(
                          value: currentIndex,
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: _filterMinTrust == DataFreshness.unknown ? 'Any' : _filterMinTrust.label,
                          onChanged: (value) {
                            setSheetState(() => _filterMinTrust = trustOrder[value.round()]);
                            setState(() {});
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Fresh Only', style: Theme.of(context).textTheme.bodySmall),
                            Text('Any', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    );
                  }
                ),
                
                const SizedBox(height: 24),
                
                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Show ${_getFilteredSpots().length} spots'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchMapsUrl(double lat, double lon) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');
    try {
      // Try to launch in external app (Google Maps)
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      
      if (!launched) {
        // Fallback to browser behavior
        launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      }
      
      if (!launched) {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final filteredSpots = _getFilteredSpots();
    
    for (final spot in filteredSpots) {
      if (spot.latitude != null && spot.longitude != null) {
        final freshness = PredictionService.calculateFreshness(
          lastUpdated: spot.lastUpdated,
          measurementCount: spot.measurementCount ?? 1,
        );
        
        // SIMPLE DESIGN:
        // - Pin color: Noise level (green→red) only
        // - Top-right badge: Trust indicator only
        
        final noiseLevel = spot.noiseLevel.clamp(1, 5);
        final pinColor = _getNoiseColor(noiseLevel);
        
        markers.add(
          Marker(
            point: LatLng(spot.latitude!, spot.longitude!),
            width: 90,
            height: 90,
            child: GestureDetector(
              onLongPress: () => _launchMapsUrl(spot.latitude!, spot.longitude!),
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SpotDetailScreen(
                      spot: spot,
                      onDeleted: () {
                        _loadSpots();
                      },
                    ),
                  ),
                );

                if (result == 'MEASURE' && mounted) {
                  _showCreateSpotDialog(LatLng(spot.latitude!, spot.longitude!));
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main pin body
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: pinColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.volume_down,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          spot.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // TOP-RIGHT: Trust badge only
                  Positioned(
                    top: -5,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getFreshnessBadgeColor(freshness),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getFreshnessBadgeIcon(freshness),
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    
    // Add user location marker if available
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 30,
          ),
        ),
      );
    }
    
    return markers;
  }

  Color _getFreshnessBadgeColor(DataFreshness freshness) {
    switch (freshness) {
      case DataFreshness.fresh:
        return Colors.green.shade700;
      case DataFreshness.predictedConfident:
        return Colors.blue.shade700;
      case DataFreshness.predictedModerate:
        return Colors.amber.shade700;
      case DataFreshness.predictedLimited:
        return Colors.orange.shade700;
      case DataFreshness.unknown:
        return Colors.grey.shade700;
    }
  }

  IconData _getFreshnessBadgeIcon(DataFreshness freshness) {
    switch (freshness) {
      case DataFreshness.fresh:
        return Icons.check;
      case DataFreshness.predictedConfident:
        return Icons.insights;
      case DataFreshness.predictedModerate:
        return Icons.trending_up;
      case DataFreshness.predictedLimited:
        return Icons.help_outline;
      case DataFreshness.unknown:
        return Icons.question_mark;
    }
  }

  // Returns color for noise level badge (1=quiet/green, 5=loud/red)
  Color _getNoiseColor(int level) {
    switch (level) {
      case 1:
        return Colors.green.shade600;  // Very quiet
      case 2:
        return Colors.lightGreen.shade600;  // Quiet
      case 3:
        return Colors.amber.shade600;  // Moderate
      case 4:
        return Colors.orange.shade600;  // Loud
      case 5:
        return Colors.red.shade600;  // Very loud
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _addSpot() async {
    // Show Quick Add Dialog directly (auto-detect location)
    final created = await showDialog<QuietSpot>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickAddSpotDialog(
        existingSpots: _spots,
      ),
    );
    
    if (created != null) {
      await _upsertSpot(created);
      // Immediate refresh for user feedback (freshness badge update)
      // Other users' updates are synced via periodic auto-refresh
      await _loadSpots();
    }
  }

  Future<void> _centerOnUserLocation() async {
    if (_userLocation == null) {
      await _getUserLocation();
    }

    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
      setState(() {
        _mapRotation = _mapController.camera.rotation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuietSpot'),
        actions: [
          // Refresh button
          IconButton(
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh locations',
            onPressed: _isLoading ? null : _loadSpots,
          ),
          // Filter button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter spots',
                onPressed: _showFilterBottomSheet,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _activeFilterCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on my location',
            onPressed: () => _centerOnUserLocation(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasMapboxToken)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Set MAPBOX_ACCESS_TOKEN via --dart-define to load the map.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                minZoom: 3,
                maxZoom: 20,
                onTap: _onMapTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapEvent: (event) {
                  // Update rotation when map is rotated or moved
                  if (mounted) {
                    setState(() {
                      _mapRotation = _mapController.camera.rotation;
                    });
                  }
                },
              ),
              children: [
                // Map tiles (Mapbox)
                TileLayer(
                  urlTemplate: _tileLayerUrl,
                  userAgentPackageName: 'com.example.quietspot',
                  maxZoom: 20,
                  tileSize: 512,
                  // Mapbox tiles are 512px; adjust zoom for Leaflet compatibility
                  retinaMode: true,
                  additionalOptions: _tileLayerOptions,
                  zoomOffset: -1,
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('Tile load error ${tile.coordinates}: $error');
                  },
                ),
                // Markers layer
                MarkerLayer(
                  markers: _buildMarkers(),
                ),
                RichAttributionWidget(
                  attributions: const [
                    TextSourceAttribution(
                      'Mapbox',
                      prependCopyright: true,
                    ),
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      prependCopyright: true,
                    ),
                  ],
                ),
              ],
            ),

          // Compass button
          Positioned(
            top: 16,
            right: 16,
            child: _CompassWidget(
              rotation: _mapRotation,
              onTap: () {
                // Reset rotation to north (0 degrees)
                _mapController.rotate(0.0);
                setState(() {
                  _mapRotation = 0.0;
                });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "map_fab",
        onPressed: _addSpot,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}

/// Compass widget that shows map rotation and allows resetting to north
class _CompassWidget extends StatelessWidget {
  const _CompassWidget({
    required this.rotation,
    required this.onTap,
  });

  final double rotation; // Map rotation in degrees
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRotated = rotation.abs() > 0.1;
    
    return Tooltip(
      message: isRotated 
          ? 'Tap to reset map to north (${rotation.toStringAsFixed(0)}°)'
          : 'Compass - Tap to reset to north',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating compass icon (counter-rotates to keep north indicator up)
                Transform.rotate(
                  angle: isRotated ? -rotation * math.pi / 180 : 0, // Negative to counter-rotate
                  child: Icon(
                    Icons.explore,
                    color: isRotated ? Colors.blue[700] : Colors.blue,
                    size: 32,
                  ),
                ),
                // North indicator (always pointing up, only visible when rotated)
                if (isRotated)
                  Positioned(
                    top: 4,
                    child: Container(
                      width: 4,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
