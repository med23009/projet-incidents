import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;

class PermissionService extends GetxService {
  final RxBool locationPermissionGranted = false.obs;
  final RxBool cameraPermissionGranted = false.obs;
  final RxBool microphonePermissionGranted = false.obs;

  // Add async initialization pattern
  Future<PermissionService> init() async {
    developer.log('Initializing PermissionService');
    await _checkInitialPermissions();
    developer.log('PermissionService initialized successfully');
    return this;
  }

  @override
  void onInit() {
    super.onInit();
    // Initialization moved to init() method
  }

  Future<void> _checkInitialPermissions() async {
    try {
      developer.log('Checking initial permissions...');
      
      // Vérifier les autorisations sans les demander
      locationPermissionGranted.value = await Permission.location.isGranted;
      cameraPermissionGranted.value = await Permission.camera.isGranted;
      microphonePermissionGranted.value = await Permission.microphone.isGranted;
      
      developer.log('Initial permissions status - '
          'Location: ${locationPermissionGranted.value}, '
          'Camera: ${cameraPermissionGranted.value}, '
          'Microphone: ${microphonePermissionGranted.value}');
    } catch (e) {
      developer.log('Error checking initial permissions', error: e);
    }
  }

  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      locationPermissionGranted.value = status.isGranted;
      developer.log('Location permission request result: ${status.name}');
      return status.isGranted;
    } catch (e) {
      developer.log('Error requesting location permission', error: e);
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      cameraPermissionGranted.value = status.isGranted;
      developer.log('Camera permission request result: ${status.name}');
      return status.isGranted;
    } catch (e) {
      developer.log('Error requesting camera permission', error: e);
      return false;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      microphonePermissionGranted.value = status.isGranted;
      developer.log('Microphone permission request result: ${status.name}');
      return status.isGranted;
    } catch (e) {
      developer.log('Error requesting microphone permission', error: e);
      return false;
    }
  }

  Future<void> requestAllPermissions() async {
    developer.log('Requesting all required permissions...');
    
    final locationGranted = await requestLocationPermission();
    final cameraGranted = await requestCameraPermission();
    final microphoneGranted = await requestMicrophonePermission();
    
    developer.log('All permissions requested - '
        'Location: $locationGranted, '
        'Camera: $cameraGranted, '
        'Microphone: $microphoneGranted');
  }
  
  // Ouvrir les paramètres de l'application pour que l'utilisateur puisse gérer manuellement les autorisations
  Future<void> openSettings() async {
    try {
      final opened = await openAppSettings();
      developer.log('App settings opened: $opened');
    } catch (e) {
      developer.log('Error opening app settings', error: e);
    }
  }
} 