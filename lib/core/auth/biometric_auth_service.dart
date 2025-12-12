import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService extends GetxController {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  final RxBool isBiometricAvailable = false.obs;
  final RxBool isAuthenticated = false.obs;

  // Méthode d'initialisation pour GetX
  Future<BiometricAuthService> init() async {
    await checkBiometricAvailability();
    return this;
  }

  @override
  void onInit() {
    super.onInit();
    checkBiometricAvailability();
  }

  Future<void> checkBiometricAvailability() async {
    try {
      // Check if biometric authentication is available
      final bool canAuthWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuth = canAuthWithBiometrics || await _localAuth.isDeviceSupported();
      isBiometricAvailable.value = canAuth;

      if (canAuth) {
        // Get list of available biometrics
        final List<BiometricType> availableBiometrics = 
            await _localAuth.getAvailableBiometrics();
            
        print('Available biometrics: $availableBiometrics');
      }
    } on PlatformException catch (e) {
      print('Error checking biometric availability: $e');
      isBiometricAvailable.value = false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!isBiometricAvailable.value) {
      return false;
    }

    try {
      isAuthenticated.value = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (isAuthenticated.value) {
        // Store the biometric authentication state
        await _storage.write(key: 'biometric_authenticated', value: 'true');
      }

      return isAuthenticated.value;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        print('Biometric authentication not available');
      } else if (e.code == auth_error.notEnrolled) {
        print('No biometrics enrolled on this device');
      } else if (e.code == auth_error.lockedOut) {
        print('Biometric authentication is temporarily locked');
      } else if (e.code == auth_error.permanentlyLockedOut) {
        print('Biometric authentication is permanently locked');
      }
      return false;
    }
  }

  Future<void> logout() async {
    isAuthenticated.value = false;
    await _storage.delete(key: 'biometric_authenticated');
  }

  Future<bool> checkBiometricAuthStatus() async {
    final status = await _storage.read(key: 'biometric_authenticated');
    return status == 'true';
  }
} 