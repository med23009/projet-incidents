import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;

class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final RxBool isConnected = false.obs;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  // Événement auquel les autres services peuvent s'abonner
  final connectivityChangedEvent = RxBool(false);

  // Add async initialization
  Future<ConnectivityService> init() async {
    developer.log('Initializing ConnectivityService');
    await _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    developer.log('ConnectivityService initialized with status: ${isConnected.value}');
    return this;
  }

  @override
  void onInit() {
    super.onInit();
    // We'll initialize in the init() method instead
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  // Initialiser l'état de connectivité
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      developer.log('Connectivity initialization error', error: e);
      isConnected.value = false;
    }
  }

  // Mettre à jour l'état de connexion lorsqu'il change
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = isConnected.value;
    
    // Si n'importe quelle connexion est active, considérer comme connecté
    isConnected.value = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet);
    
    developer.log('Connectivity status changed: ${results.map((r) => r.name).join(', ')}, isConnected: ${isConnected.value}');
    
    // Si nous passons de déconnecté à connecté, déclencher l'événement
    // mais ne pas déclencher de sync directement - laissez SyncService gérer cela
    if (!wasConnected && isConnected.value) {
      developer.log('Network reconnected - connectivity status changed');
      connectivityChangedEvent.toggle(); // Déclencher l'événement sans mentionner le sync
    }
  }

  // Méthode pour vérifier manuellement la connectivité
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      
      // Si n'importe quelle connexion est active, considérer comme connecté
      isConnected.value = results.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
      
      return isConnected.value;
    } catch (e) {
      developer.log('Error checking connectivity', error: e);
      return false;
    }
  }
} 