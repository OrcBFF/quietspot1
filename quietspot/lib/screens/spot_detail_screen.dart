import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quietspot/models/quiet_spot.dart';
import 'package:quietspot/services/api_service.dart';

class SpotDetailScreen extends StatefulWidget {
  const SpotDetailScreen({
    super.key,
    required this.spot,
    required this.onDeleted,
  });

  final QuietSpot spot;
  final VoidCallback onDeleted;

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedDayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
  
  // Data structure: Map<DayIndex, Map<TimeBlock, List<double>>>
  final Map<int, Map<String, List<double>>> _analyticsData = {};
  
  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      // Fetch historical data
      final measurements = await ApiService.getMeasurements(widget.spot.id);
      
      if (!mounted) return;
      
      setState(() {
        _processData(measurements);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) {
        setState(() {
           _isLoading = false;
           _errorMessage = 'Could not load data. Check connection.'; // Simple user msg
        });
      }
    }
  }

  void _processData(List<dynamic> rawData) {
    _analyticsData.clear();
    
    // Initialize structure
    for (int i = 0; i < 7; i++) {
      _analyticsData[i] = {
        'Morning (6-12)': [],
        'Afternoon (12-18)': [],
        'Evening (18-24)': [],
        'Night (0-6)': [],
      };
    }

    if (rawData.isEmpty) {
       // Keep empty structure
       return;
    }

    for (final item in rawData) {
      if (item is Map<String, dynamic>) {
        // Handle potential field name mismatches from backend
        final rawDb = item['noiseDb'] ?? item['db_value'];
        final rawTime = item['timestamp'] ?? item['measured_at'];

        double? db;
        if (rawDb is num) {
          db = rawDb.toDouble();
        } else if (rawDb is String) {
          db = double.tryParse(rawDb);
        }

        final timestampStr = rawTime as String?;
        
        if (db != null && timestampStr != null) {
          final date = DateTime.tryParse(timestampStr)?.toLocal();
          if (date != null) {
            final dayIndex = date.weekday - 1; // 0=Mon
            final hour = date.hour;
            
            String block;
            if (hour >= 6 && hour < 12) block = 'Morning (6-12)';
            else if (hour >= 12 && hour < 18) block = 'Afternoon (12-18)';
            else if (hour >= 18) block = 'Evening (18-24)';
            else block = 'Night (0-6)';
            
            _analyticsData[dayIndex]![block]!.add(db);
          }
        }
      }
    }
  }

  double? _getAverage(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Color _getColorForDb(double db) {
    if (db < 45) return Colors.green;
    if (db < 65) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.spot.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Delete Spot'),
                    content: const Text('Are you sure you want to delete this spot?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDeleted();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Existing Info ---
                if (widget.spot.location.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.place),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.spot.location,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Icon(Icons.volume_down),
                  const SizedBox(width: 8),
                  Text('Noise level: ${widget.spot.noiseLevel}/5'),
                  if (widget.spot.noiseDb != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.spot.noiseDb!.toStringAsFixed(0)}dB',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
                  const SizedBox(height: 8),
              if (widget.spot.lastUpdated != null)
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateFormat('MMM d, HH:mm').format(widget.spot.lastUpdated!)}'
                      '${widget.spot.noiseDb != null ? " (${widget.spot.noiseDb!.toStringAsFixed(1)} dB)" : ""}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              
              // --- Analytics Section ---
              Text(
                'Noise Trends',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Typical noise levels by time of day',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                 Center(child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     children: [
                       const Icon(Icons.error_outline, color: Colors.red, size: 32),
                       const SizedBox(height: 8),
                       Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                       const SizedBox(height: 8),
                       ElevatedButton(
                         onPressed: () {
                           setState(() {
                             _isLoading = true;
                             _errorMessage = null;
                           });
                           _fetchAnalytics();
                         },
                         child: const Text('Retry'),
                       )
                     ],
                   ),
                 ))
              else ...[
                // Day Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(7, (index) {
                      final isSelected = _selectedDayIndex == index;
                      final dayName = DateFormat('E').format(DateTime(2024, 1, 1).add(Duration(days: index))); // Mon, Tue...
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(dayName),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedDayIndex = index);
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Analytics Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar('Morning', 'Morning (6-12)'),
                          _buildBar('Afternoon', 'Afternoon (12-18)'),
                          _buildBar('Evening', 'Evening (18-24)'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Info for Missing Data (Current Block)
                Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final currentDayIdx = now.weekday - 1;
                    if (_selectedDayIndex != currentDayIdx) return const SizedBox.shrink(); // Only show for "Today"
                    
                    String currentBlock;
                    if (now.hour >= 6 && now.hour < 12) currentBlock = 'Morning (6-12)';
                    else if (now.hour >= 12 && now.hour < 18) currentBlock = 'Afternoon (12-18)';
                    else if (now.hour >= 18) currentBlock = 'Evening (18-24)';
                    else currentBlock = 'Night (0-6)';
                    
                    final data = _analyticsData[currentDayIdx]?[currentBlock];
                    if (data == null || data.isEmpty) {
                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'No noise data for this time yet. Visit this spot to contribute a measurement!',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
              
              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(String label, String blockKey) {
    final values = _analyticsData[_selectedDayIndex]?[blockKey] ?? [];
    final avg = _getAverage(values);
    
    // Scale: 30dB (empty) to 90dB (full)
    // Normalized height 0.0 to 1.0
    final normalized = avg != null 
        ? ((avg - 30) / 60.0).clamp(0.1, 1.0) 
        : 0.0; 
        
    return Column(
      children: [
        if (avg != null)
           Text('${avg.toStringAsFixed(0)}dB', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
        else 
           const Text('?', style: TextStyle(fontSize: 12, color: Colors.grey)),
        
        const SizedBox(height: 4),
        
        Container(
          width: 40,
          height: 100, // Max height
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
             color: Colors.grey[200],
             borderRadius: BorderRadius.circular(6),
          ),
          child: avg != null 
            ? Container(
                width: 40,
                height: 100 * normalized,
                decoration: BoxDecoration(
                  color: _getColorForDb(avg),
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            : const Center(child: Icon(Icons.help_outline, size: 16, color: Colors.grey)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}


