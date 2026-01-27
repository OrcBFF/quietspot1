import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Request location permission
  Future<bool> requestPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Location services are disabled, opening settings');
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('LocationService: Location services still disabled after settings');
          return false;
        }
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('LocationService: Permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: Permission denied forever');
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('LocationService: Error requesting permission: $e');
      debugPrint('LocationService: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Check if location permission is granted
  Future<bool> hasPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationService: Error checking permission: $e');
      return false;
    }
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e, stackTrace) {
      debugPrint('LocationService: Error getting location: $e');
      debugPrint('LocationService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationService: Error checking if location enabled: $e');
      return false;
    }
  }
}
