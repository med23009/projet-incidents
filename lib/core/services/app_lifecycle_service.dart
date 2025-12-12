import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../auth/biometric_auth_service.dart';
import 'dart:developer' as developer;

class AppLifecycleService extends GetxService with WidgetsBindingObserver {
  // Référence au service d'authentification biométrique
  final BiometricAuthService _biometricAuthService = Get.find<BiometricAuthService>();
  
  // État actuel de l'application
  final Rx<AppLifecycleState?> currentState = Rx<AppLifecycleState?>(null);
  
  // Timestamp du dernier passage en arrière-plan
  DateTime? _lastPausedTime;
  
  // Durée après laquelle une nouvelle authentification est requise (en secondes)
  final int _authTimeoutSeconds = 30; // 30 secondes pour les tests, ajustez selon vos besoins
  
  Future<AppLifecycleService> init() async {
    // S'enregistrer comme observateur du cycle de vie de l'application
    WidgetsBinding.instance.addObserver(this);
    developer.log('AppLifecycleService initialized');
    return this;
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    currentState.value = state;
    developer.log('App lifecycle state changed to: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      default:
        break;
    }
  }
  
  void _handleAppPaused() {
    // Enregistrer le moment où l'application est passée en arrière-plan
    _lastPausedTime = DateTime.now();
    developer.log('App paused at: $_lastPausedTime');
  }
  
  void _handleAppResumed() {
    developer.log('App resumed');
    
    // Vérifier si une authentification biométrique est nécessaire
    if (_isAuthenticationRequired()) {
      developer.log('Authentication required after app resume');
      _requestBiometricAuthentication();
    } else {
      developer.log('No authentication required after app resume');
    }
  }
  
  bool _isAuthenticationRequired() {
    // Si l'application n'a jamais été mise en arrière-plan, pas besoin d'authentification
    if (_lastPausedTime == null) {
      return false;
    }
    
    // Calculer le temps écoulé depuis la mise en arrière-plan
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastPausedTime!).inSeconds;
    
    developer.log('Time elapsed since app was paused: $elapsedSeconds seconds');
    
    // Si le temps écoulé est supérieur au seuil, demander l'authentification
    return elapsedSeconds >= _authTimeoutSeconds;
  }
  
  Future<void> _requestBiometricAuthentication() async {
    try {
      final authenticated = await _biometricAuthService.authenticateWithBiometrics();
      
      if (authenticated) {
        developer.log('Biometric authentication successful after app resume');
      } else {
        developer.log('Biometric authentication failed or cancelled after app resume');
        // Vous pouvez ajouter ici une logique pour gérer l'échec de l'authentification
        // Par exemple, rediriger vers l'écran de connexion
      }
    } catch (e) {
      developer.log('Error during biometric authentication after app resume', error: e);
    }
  }
  
  @override
  void onClose() {
    // Se désinscrire comme observateur du cycle de vie de l'application
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
