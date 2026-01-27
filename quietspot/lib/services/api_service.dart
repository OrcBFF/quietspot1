import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:quietspot/models/quiet_spot.dart';
import 'package:quietspot/managers/user_manager.dart';

class ApiService {
  // Change this to your backend URL
  // For Android emulator: use http://10.0.2.2:3000
  // For physical device: use your computer's IP address (e.g., http://192.168.1.100:3000)
  // For localhost testing: use http://localhost:3000
  static String get baseUrl {
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://quietspot-api.onrender.com',  // Production on Render
    );
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static const String apiPrefix = '/api';

  // Helper method for GET requests
  static Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helper method for GET requests returning list
  static Future<List<dynamic>> _getList(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$apiPrefix$endpoint');
      debugPrint('ApiService: Calling GetList on: $url');
      debugPrint('ApiService: BaseURL is: $baseUrl');

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 90));

      debugPrint('ApiService: Response Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helper method for POST requests
  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90));

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        // Extract error message from response body
        final errorMessage = responseBody['error'] ?? 'Request failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  // Helper method for PUT requests
  static Future<Map<String, dynamic>> _put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to update: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helper method for DELETE requests
  static Future<void> _delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$apiPrefix$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        // Try to parse error message
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          throw Exception(body['error'] ?? 'Delete failed: ${response.statusCode}');
        } catch (_) {
          throw Exception('Delete failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  // Locations API
  static Future<List<QuietSpot>> getLocations() async {
    final data = await _getList('/locations');
    return data.map((json) => QuietSpot.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<QuietSpot> getLocation(String id) async {
    final data = await _get('/locations/$id');
    return QuietSpot.fromJson(data);
  }

  static Future<QuietSpot> createLocation(QuietSpot spot) async {
    final body = spot.toJson();
    if (UserManager.instance.userId != null) {
      body['userId'] = UserManager.instance.userId;
    }
    final data = await _post('/locations', body);
    return QuietSpot.fromJson(data);
  }

  static Future<QuietSpot> updateLocation(String id, QuietSpot spot) async {
    final body = spot.toJson();
    if (UserManager.instance.userId != null) {
      body['userId'] = UserManager.instance.userId;
    }
    final data = await _put('/locations/$id', body);
    return QuietSpot.fromJson(data);
  }

  static Future<void> deleteLocation(String id) async {
    await _delete('/locations/$id');
  }

  // Measurements API
  static Future<List<Map<String, dynamic>>> getMeasurements(String locationId) async {
    final data = await _getList('/measurements/location/$locationId');
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>> createMeasurement({
    required String locationId,
    required double noiseDb,
    int? userId,
  }) async {
    return await _post('/measurements', {
      'locationId': locationId,
      'userId': userId ?? UserManager.instance.userId ?? 1,  // Use logged-in user, fallback to 1
      'noiseDb': noiseDb,
    });
  }

  static Future<List<Map<String, dynamic>>> getNearbyMeasurements({
    required double latitude,
    required double longitude,
    double radiusMeters = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/measurements/nearby')
            .replace(queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'radiusMeters': radiusMeters.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Favorites API
  static Future<List<QuietSpot>> getFavorites(int userId) async {
    final data = await _getList('/favorites/user/$userId');
    return data.map((json) => QuietSpot.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<void> addFavorite(int userId, String locationId) async {
    await _post('/favorites', {
      'userId': userId,
      'locationId': locationId,
    });
  }

  static Future<void> removeFavorite(int userId, String locationId) async {
    await _delete('/favorites/$userId/$locationId');
  }

  static Future<bool> isFavorited(int userId, String locationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/favorites/check/$userId/$locationId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['isFavorited'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Health check
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$apiPrefix/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Auth API
  static Future<Map<String, dynamic>> login(String username, String password) async {
    return await _post('/auth/login', {
      'username': username,
      'password': password,
    });
  }



  static Future<Map<String, dynamic>> signup(String username, String email, String password) async {
    return await _post('/auth/signup', {
      'username': username,
      'email': email,
      'password': password,
    });
  }



  static Future<void> changePassword(int userId, String oldPassword, String newPassword) async {
    await _post('/auth/change-password', {
      'userId': userId,
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  static Future<void> deleteAccount(int userId) async {
    await _delete('/users/$userId');
  }

  static Future<Map<String, dynamic>> getUserStats(int userId) async {
    final response = await _get('/users/$userId/stats');
    return response as Map<String, dynamic>;
  }


}

