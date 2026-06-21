import 'package:geolocator/geolocator.dart';
import '../utils/app_logger.dart';
import '../models/pod_model.dart';

class LocationService {
  
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }
  
  // Request location permission
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }
  
  // Get current location
  Future<LocationData?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in your device settings.');
      }
      
      // Check permission
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please grant location access to capture delivery location.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable location access in your device settings.');
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      
      // Get address from coordinates (reverse geocoding)
      String address = await getAddressFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
      );
    } catch (e) {
      AppLogger.error('Failed to get current location', error: e);
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }
  
  // Get last known location
  Future<LocationData?> getLastKnownLocation() async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        String address = await getAddressFromCoordinates(
          position.latitude, 
          position.longitude,
        );
        
        return LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          accuracy: position.accuracy,
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get last known location', error: e);
      return null;
    }
  }
  
  // Convert coordinates to address (simplified version)
  // In production, you'd use a proper geocoding service like Google Maps API
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // This is a placeholder implementation
      // In a real app, you would integrate with a geocoding service
      return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      AppLogger.error('Reverse geocoding failed', error: e);
      return 'Unknown location';
    }
  }
  
  // Calculate distance between two points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
  
  // Check if location is within delivery radius
  bool isWithinDeliveryRadius(
    LocationData currentLocation,
    LocationData deliveryLocation, {
    double radiusInMeters = 100.0,
  }) {
    double distance = calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      deliveryLocation.latitude,
      deliveryLocation.longitude,
    );
    
    return distance <= radiusInMeters;
  }
  
  // Get location settings for high accuracy
  LocationSettings get locationSettings {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }
  
  // Stream of position updates
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
  }
  
  // Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
  
  // Open app settings
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}