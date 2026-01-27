import 'package:flutter/material.dart';
import 'package:quietspot/models/quiet_spot.dart';
import 'package:quietspot/screens/spot_detail_screen.dart';
import 'package:quietspot/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<QuietSpot> _favorites = [];
  bool _isLoading = true;
  int _currentUserId = 1; // Default user ID

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadFavorites();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    setState(() {
      _currentUserId = userId;
    });
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final favorites = await ApiService.getFavorites(_currentUserId);
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFavorite(QuietSpot spot) async {
    try {
      await ApiService.removeFavorite(_currentUserId, spot.id);
      setState(() {
        _favorites.removeWhere((s) => s.id == spot.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Favourites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Text(
                    'No favorites yet.\nAdd spots to favorites to see them here.',
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
        padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final spot = _favorites[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.star, color: Colors.amber),
                          title: Text(spot.name),
                          subtitle: Text(
                            'Noise: ${spot.noiseLevel}/5${spot.noiseDb != null ? ' • ${spot.noiseDb!.toStringAsFixed(0)}dB' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeFavorite(spot),
                            tooltip: 'Remove from favorites',
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SpotDetailScreen(
                                  spot: spot,
                                  onDeleted: () {
                                    _loadFavorites();
                                  },
        ),
      ),
    );
                          },
                        ),
                      );
                    },
        ),
      ),
    );
  }
}


