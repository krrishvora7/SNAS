import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';

class LocationService {
  /// Get current device location with high accuracy
  /// Throws exception if location services are disabled or permission denied
  /// Timeout after 10 seconds
  Future<LocationData> getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await isLocationEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services to mark attendance.');
    }

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestLocationPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied. Please grant location permission to mark attendance.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable location permission in settings.');
    }

    // Get current position with high accuracy and timeout
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('time')) {
        throw Exception('Unable to determine location. Request timed out after 10 seconds.');
      }
      throw Exception('Unable to get location: ${e.toString()}');
    }
  }

  /// Check if location services are enabled on the device
  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission from the user
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }
}
