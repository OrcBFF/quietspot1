import 'package:flutter/material.dart';
import 'package:quietspot/services/api_service.dart';
import 'package:quietspot/managers/user_manager.dart';

class ContributionsScreen extends StatefulWidget {
  const ContributionsScreen({super.key});

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  bool _isLoading = true;
  int _measurementsCount = 0;
  int _spotsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final userId = UserManager.instance.userId;
      if (userId != null) {
        final stats = await ApiService.getUserStats(userId);
        if (mounted) {
          setState(() {
            _measurementsCount = stats['measurements'] ?? 0;
            _spotsCount = stats['spots'] ?? 0;
            _isLoading = false;
          });
        }
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contributions')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
                _buildStatItem(
                    icon: Icons.graphic_eq, 
                    title: 'Measurements', 
                    count: _measurementsCount
                ),
                const SizedBox(height: 16),
                _buildStatItem(
                    icon: Icons.add_location_alt, 
                    title: 'New Spots', 
                    subtitle: '(Unexplored spots added)',
                    count: _spotsCount
                ),
            ],
          ),
    );
  }

  Widget _buildStatItem({
    required IconData icon, 
    required String title, 
    String? subtitle,
    required int count,
  }) {
      return Card(
        elevation: 2,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
                children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Theme.of(context).primaryColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                if (subtitle != null)
                                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                        ),
                    ),
                    Text(
                        count.toString(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                ],
            ),
        ),
      );
  }
}
