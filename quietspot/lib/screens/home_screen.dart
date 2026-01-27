import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quietspot/models/quiet_spot.dart';

import 'package:quietspot/screens/spot_detail_screen.dart';
import 'package:quietspot/services/api_service.dart';
import 'package:quietspot/services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  List<QuietSpot> _spots = [];
  bool _isLoading = true;
  String? _errorMessage;
  Position? _userLocation;
  double? _maxDistance; // in meters, null means no limit

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (mounted && position != null) {
      setState(() {
        _userLocation = position;
      });
    }
  }

  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spots = await ApiService.getLocations();
      setState(() {
        _spots = spots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load spots: $e';
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

  Future<void> _deleteSpot(QuietSpot spot) async {
    try {
      await ApiService.deleteLocation(spot.id);
      setState(() {
        _spots.removeWhere((s) => s.id == spot.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spot deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting spot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempDistance = _maxDistance ?? 5000;
        bool filterEnabled = _maxDistance != null;

        return StatefulBuilder(
          builder: (context, setState) {
            final walkingTime = (tempDistance / 83).round(); // approx 83m/min (5km/h)
            
            return AlertDialog(
              title: const Text('Filter Spots'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: filterEnabled,
                        onChanged: (val) {
                          setState(() => filterEnabled = val ?? false);
                        },
                      ),
                      const Text('Filter by Distance'),
                    ],
                  ),
                  if (filterEnabled) ...[
                    const SizedBox(height: 8),
                    Text('Max Distance: ${tempDistance.round()}m'),
                    Text(
                      'Approx. Walking Time: $walkingTime min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: tempDistance,
                      min: 100,
                      max: 5000,
                      divisions: 49,
                      label: '${tempDistance.round()}m',
                      onChanged: (val) {
                        setState(() => tempDistance = val);
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {
                      _maxDistance = filterEnabled ? tempDistance : null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate distances and filter
    final processedSpots = _spots.map((spot) {
      double? distance;
      if (_userLocation != null && spot.latitude != null && spot.longitude != null) {
        distance = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          spot.latitude!,
          spot.longitude!,
        );
      }
      return {'spot': spot, 'distance': distance};
    }).where((item) {
      final distance = item['distance'] as double?;

      if (_maxDistance != null) {
        if (distance == null) return false; // If we can't calculate distance, hide it when filtering by distance
        if (distance > _maxDistance!) return false;
      }
      return true;
    }).toList();
    
    // Sort by distance if user location is available
    if (_userLocation != null) {
      processedSpots.sort((a, b) {
        final distA = a['distance'] as double? ?? double.infinity;
        final distB = b['distance'] as double? ?? double.infinity;
        return distA.compareTo(distB);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuietSpot'),
        actions: [
          IconButton(
            tooltip: 'Filter Spots',
            icon: Icon(
              (_maxDistance != null) 
                  ? Icons.filter_alt 
                  : Icons.filter_alt_outlined,
            ),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSpots,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
          : processedSpots.isEmpty
              ? Center(
                  child: Text(
                    _spots.isEmpty
                        ? 'No saved quiet spots.\nTap the + to add one.'
                        : 'No spots match your filters.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: processedSpots.length,
                  itemBuilder: (context, index) {
                    final item = processedSpots[index];
                    final spot = item['spot'] as QuietSpot;
                    final distance = item['distance'] as double?;
                    
                    String distanceText = '';
                    if (distance != null) {
                      final walkingMinutes = (distance / 83).round();
                      distanceText = '\n${distance.round()}m • $walkingMinutes min walk';
                    }

                    // Determine color based on noise level
                    Color iconColor;
                    if (spot.noiseLevel <= 2) {
                      iconColor = Colors.green;
                    } else if (spot.noiseLevel <= 3) {
                      iconColor = Colors.orange;
                    } else {
                      iconColor = Colors.redAccent;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.volume_up,
                          color: iconColor,
                        ),
                         title: Text(spot.name),
                        subtitle: Builder(
                          builder: (context) {
                            // Freshness logic
                            String timeAgo = '';
                            if (spot.lastUpdated != null) {
                              final diff = DateTime.now().difference(spot.lastUpdated!);
                              if (diff.inMinutes < 60) {
                                timeAgo = '\nUpdated: ${diff.inMinutes}m ago';
                              } else if (diff.inHours < 24) {
                                timeAgo = '\nUpdated: ${diff.inHours}h ago';
                              } else {
                                timeAgo = '\nUpdated: >1d ago';
                              }
                            }
                            
                            return Text(
                              '${spot.location}\nNoise: ${spot.noiseLevel}/5${spot.noiseDb != null ? ' • ${spot.noiseDb!.toStringAsFixed(0)}dB' : ''}$distanceText$timeAgo',
                            );
                          }
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SpotDetailScreen(
                                spot: spot,
                                onDeleted: () => _deleteSpot(spot),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}


