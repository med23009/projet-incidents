import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'package:get/get.dart';

class LocationService extends GetxService {
  // Add observable state
  final RxBool locationPermissionGranted = false.obs;
  
  // Implement async initialization
  Future<LocationService> init() async {
    developer.log('Initializing LocationService');
    // Check location permission on init
    final permissionStatus = await Permission.location.status;
    locationPermissionGranted.value = permissionStatus.isGranted;
    
    if (locationPermissionGranted.value) {
      developer.log('LocationService: Location permission already granted');
    } else {
      developer.log('LocationService: Location permission not granted. Will request when needed.');
    }
    
    return this;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      // Check location permission
      final status = await Permission.location.request();
      locationPermissionGranted.value = status.isGranted;
      
      if (!locationPermissionGranted.value) {
        developer.log('Location permission denied');
        return null;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('Location services are disabled');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      developer.log('Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e, stackTrace) {
      developer.log('Error getting location', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      locationPermissionGranted.value = status.isGranted;
      developer.log('Location permission status: $status');
      return locationPermissionGranted.value;
    } catch (e, stackTrace) {
      developer.log('Error requesting location permission', error: e, stackTrace: stackTrace);
      return false;
    }
  }
} 