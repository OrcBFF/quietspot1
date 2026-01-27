import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PointOfInterest {
  PointOfInterest({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
  });

  final String id;
  final String name;
  final String category; // amenity type (cafe, library, restaurant, etc.)
  final LatLng location;
}

class PoiService {
  static const _overpassEndpoint = 'https://overpass-api.de/api/interpreter';
  static const _defaultRadiusMeters = 1800; // ~10–15 minute walk

  /// Fetch nearby amenities (cafes, food, libraries) around the given center.
  Future<List<PointOfInterest>> fetchNearbyPois(
    LatLng center, {
    int radiusMeters = _defaultRadiusMeters,
  }) async {
    final query = '''
      [out:json][timeout:25];
      (
        node["amenity"~"cafe|coffee_shop|restaurant|fast_food|food_court|library"](around:$radiusMeters,${center.latitude},${center.longitude});
        way["amenity"~"cafe|coffee_shop|restaurant|fast_food|food_court|library"](around:$radiusMeters,${center.latitude},${center.longitude});
        relation["amenity"~"cafe|coffee_shop|restaurant|fast_food|food_court|library"](around:$radiusMeters,${center.latitude},${center.longitude});
      );
      out center 40;
    ''';

    try {
      final response = await http
          .post(
            Uri.parse(_overpassEndpoint),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('PoiService: Overpass responded with ${response.statusCode}');
        return [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = decoded['elements'] as List<dynamic>? ?? [];

      final pois = <PointOfInterest>[];
      final seenIds = <String>{};

      for (final raw in elements) {
        final element = raw as Map<String, dynamic>;
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final amenity = (tags['amenity'] as String? ?? '').trim();

        if (amenity.isEmpty) continue;

        final lat = _getLatitude(element);
        final lon = _getLongitude(element);

        if (lat == null || lon == null) continue;

        final id = '${element['type'] ?? 'element'}-${element['id']}';
        if (seenIds.contains(id)) continue;
        seenIds.add(id);

        final name = (tags['name'] as String?)?.trim();

        pois.add(
          PointOfInterest(
            id: id,
            name: name?.isNotEmpty == true ? name! : _labelForAmenity(amenity),
            category: amenity,
            location: LatLng(lat, lon),
          ),
        );
      }

      return pois;
    } catch (e, stackTrace) {
      debugPrint('PoiService: Failed to fetch POIs: $e');
      debugPrint('PoiService: $stackTrace');
      return [];
    }
  }

  double? _getLatitude(Map<String, dynamic> element) {
    final lat = element['lat'] ?? element['center']?['lat'];
    return (lat is num) ? lat.toDouble() : null;
  }

  double? _getLongitude(Map<String, dynamic> element) {
    final lon = element['lon'] ?? element['center']?['lon'];
    return (lon is num) ? lon.toDouble() : null;
  }

  String _labelForAmenity(String amenity) {
    switch (amenity) {
      case 'cafe':
      case 'coffee_shop':
        return 'Cafe';
      case 'restaurant':
        return 'Restaurant';
      case 'fast_food':
      case 'food_court':
        return 'Food court';
      case 'library':
        return 'Library';
      default:
        return amenity[0].toUpperCase() + amenity.substring(1);
    }
  }
}
