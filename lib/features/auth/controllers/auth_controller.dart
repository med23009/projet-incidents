import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import 'dart:developer' as developer;

class AuthController extends GetxController {
  final AuthRepository _authRepository = AuthRepository();
  final AuthService _authService = Get.find<AuthService>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  
  final RxBool isLoading = false.obs;
  final RxBool isRegistering = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isCheckingAuth = false.obs;
  final Rx<Map<String, dynamic>?> userData = Rx<Map<String, dynamic>?>(null);
  
  // Ajouter un observable pour suivre l'état de la boîte de dialogue de demande de biométrie
  final RxBool shouldAskForBiometric = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  Future<void> checkAuthStatus() async {
    if (isCheckingAuth.value) return;
    isCheckingAuth.value = true;
    
    try {
      // Vérifier d'abord si la biométrie est disponible et activée
      final canUseBiometric = await _authService.canUseBiometrics();
      final biometricEnabled = await _authService.checkBiometricEnabled();
      
      // Si la biométrie est disponible et activée, essayer de se connecter automatiquement
      if (canUseBiometric && biometricEnabled) {
        developer.log('Biometric login is enabled, attempting automatic authentication');
        
        // Demander à l'utilisateur de s'authentifier avec la biométrie
        final success = await _authService.authenticateWithBiometrics();
        if (success) {
          userData.value = await _authRepository.getUserData();
          developer.log('Automatic biometric authentication successful, user data: ${userData.value}');
          Get.offAllNamed('/home');
          isCheckingAuth.value = false;
          return;
        } else {
          developer.log('Biometric authentication failed, falling back to token check');
        }
      } else {
        developer.log('Biometric authentication not available or not enabled');
      }
      
      // Si la biométrie ne fonctionne pas ou n'est pas configurée, vérifier le token JWT classique
      final isAuth = await _authRepository.isAuthenticated();
      if (isAuth) {
        userData.value = await _authRepository.getUserData();
        Get.offAllNamed('/home');
      } else {
        if (Get.currentRoute != '/login') {
          Get.offAllNamed('/login');
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error checking auth status', error: e, stackTrace: stackTrace);
    } finally {
      isCheckingAuth.value = false;
    }
  }

  void toggleRegistration() {
    isRegistering.value = !isRegistering.value;
    errorMessage.value = '';
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      errorMessage.value = 'Please fill all fields';
      return;
    }
    
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      final success = await _authService.login(
        emailController.text, 
        passwordController.text
      );
      
      if (success) {
        Get.offAllNamed('/home');
        
        // Après la première connexion réussie, vérifier si on peut demander l'activation de la biométrie
        final bool canUseBio = await _authService.canUseBiometrics();
        if (canUseBio && !_authService.isBiometricEnabled.value) {
          // Indiquer qu'on doit demander à l'utilisateur s'il veut activer la biométrie
          shouldAskForBiometric.value = true;
        }
      } else {
        errorMessage.value = 'Incorrect email or password';
      }
    } catch (e) {
      developer.log('Error during login', error: e);
      errorMessage.value = 'An error occurred during login';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register() async {
    if (emailController.text.isEmpty || 
        passwordController.text.isEmpty || 
        phoneController.text.isEmpty) {
      errorMessage.value = 'Please fill all fields';
      return;
    }
    
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      final success = await _authService.register(
        emailController.text,
        passwordController.text,
        phoneController.text,
      );
      
      if (success) {
        // Récupérer les données utilisateur après inscription
        userData.value = await _authRepository.getUserData();
        
        // Après la première inscription réussie, vérifier si on peut demander l'activation de la biométrie
        final bool canUseBio = await _authService.canUseBiometrics();
        developer.log('Registration successful, canUseBiometrics: $canUseBio');
        
        if (canUseBio) {
          // Indiquer qu'on doit demander à l'utilisateur s'il veut activer la biométrie
          shouldAskForBiometric.value = true;
          developer.log('Setting shouldAskForBiometric to TRUE');
        }
        
        // D'abord afficher le dialogue, puis rediriger vers l'écran d'accueil
        if (shouldAskForBiometric.value) {
          Get.offAllNamed('/home');
          // Attendre un court délai pour s'assurer que l'écran d'accueil est chargé
          await Future.delayed(Duration(milliseconds: 800));
          _showBiometricPrompt();
        } else {
          Get.offAllNamed('/home');
        }
      } else {
        errorMessage.value = 'An account with this email already exists';
      }
    } catch (e) {
      developer.log('Error during registration', error: e);
      errorMessage.value = 'An error occurred during registration';
    } finally {
      isLoading.value = false;
    }
  }

  void _showBiometricPrompt() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
    
    // Utiliser un délai supplémentaire pour éviter les conflits avec d'autres dialogs
    Future.delayed(Duration(milliseconds: 300), () {
      Get.dialog(
        AlertDialog(
          title: const Text('Enable biometrics'),
          content: const Text(
            'Would you like to enable fingerprint or facial recognition to make future logins easier?'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                cancelBiometricEnabling();
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await enableBiometricAuthentication();
              },
              child: const Text('Enable'),
            ),
          ],
        ),
        barrierDismissible: false,
        name: 'biometricPrompt',
      );
    });
  }
  
  Future<void> loginWithBiometrics() async {
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      final canUseBiometrics = await _authService.canUseBiometrics();
      if (!canUseBiometrics) {
        errorMessage.value = 'La biométrie n\'est pas disponible sur cet appareil';
        return;
      }
      
      final success = await _authService.authenticateWithBiometrics();
      if (success) {
        Get.offAllNamed('/home');
      } else {
        errorMessage.value = 'Biometric authentication failed or no associated account found';
      }
    } catch (e) {
      developer.log('Error during biometric authentication', error: e);
      errorMessage.value = 'An error occurred during biometric authentication';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      userData.value = null;
      Get.offAllNamed('/login');
    } catch (e) {
      developer.log('Error during logout', error: e);
      errorMessage.value = 'An error occurred during logout';
    }
  }

  bool get isAdmin => userData.value?['role'] == 'admin';

  // Nouvelle méthode pour activer la biométrie pour le compte connecté
  Future<bool> enableBiometricAuthentication() async {
    isLoading.value = true;
    try {
      final bool success = await _authService.associateBiometricWithAccount();
      if (success) {
        // Réinitialiser le flag pour ne plus afficher la demande
        shouldAskForBiometric.value = false;
        Get.snackbar(
          'Success',
          'Biometric authentication successfully enabled',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Error',
          'Unable to enable biometric authentication',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
      return success;
    } catch (e) {
      developer.log('Error enabling biometric authentication', error: e);
      Get.snackbar(
        'Error',
        'An error occurred while enabling biometrics',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Réinitialiser le flag si l'utilisateur refuse d'activer la biométrie
  void cancelBiometricEnabling() {
    shouldAskForBiometric.value = false;
  }

  // Nouvelle méthode pour essayer la connexion biométrique depuis l'écran de login
  Future<void> tryBiometricLogin() async {
    if (isLoading.value) return;
    isLoading.value = true;
    
    try {
      // Vérifier si la biométrie est disponible et activée
      final canUseBiometric = await _authService.canUseBiometrics();
      final biometricEnabled = await _authService.checkBiometricEnabled();
      
      if (canUseBiometric && biometricEnabled) {
        final success = await _authService.authenticateWithBiometrics();
        if (success) {
          userData.value = await _authRepository.getUserData();
          developer.log('Biometric login successful from login screen, user data: ${userData.value}');
          Get.offAllNamed('/home');
          return;
        } else {
          Get.snackbar(
            'Authentication failed', 
            'Please log in with your email and password',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        Get.snackbar(
          'Biometrics unavailable', 
          'Please log in with your email and password',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      developer.log('Error during biometric login attempt', error: e);
    } finally {
      isLoading.value = false;
    }
  }
}
