import 'dart:async';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/api_service.dart';
import '../models/incident.dart';
import 'incident_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'stats_service.dart';

class SyncService extends GetxService {
  final RxBool isSyncing = false.obs;
  Worker? _connectivityWorker;
  Timer? _periodicSyncTimer;
  
  // Add a lock to prevent multiple syncs from running simultaneously
  bool _syncLock = false;
  DateTime? _lastSyncTime;
  
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  final IncidentService _incidentService = Get.find<IncidentService>();
  final ApiService _apiService = Get.find<ApiService>();
  
  // Implement async initialization pattern
  Future<SyncService> init() async {
    developer.log('Initializing SyncService');
    _setupConnectivityListener();
    _setupPeriodicSync();
    
    // Try to sync on startup if internet is available
    // But only do it once, not in both init() and onInit()
    if (_connectivityService.isConnected.value) {
      Future.delayed(const Duration(seconds: 2), () => syncPendingIncidents());
    }
    
    developer.log('SyncService initialized');
    return this;
  }
  
  @override
  void onClose() {
    _connectivityWorker?.dispose();
    _periodicSyncTimer?.cancel();
    super.onClose();
  }
  
  // Set up periodic sync to run more frequently (every 5 minutes)
  void _setupPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_connectivityService.isConnected.value) {
        developer.log('Running periodic sync (every 5 minutes)');
        syncPendingIncidents();
      }
    });
  }
  
  // Configurer l'écouteur de connectivité
  void _setupConnectivityListener() {
    _connectivityWorker = ever(
      _connectivityService.isConnected, 
      (bool isConnected) {
        if (isConnected) {
          developer.log('SyncService: Connection restored, starting auto-sync...');
          
          // Check if we've synced recently (within the last 10 seconds)
          final now = DateTime.now();
          final shouldSync = _lastSyncTime == null || 
              now.difference(_lastSyncTime!).inSeconds > 10;
          
          // Only sync if we haven't synced recently and no sync is in progress
          if (shouldSync && !_syncLock && !isSyncing.value) {
            // Set the lock before starting sync
            _syncLock = true;
            syncPendingIncidents();
          } else {
            developer.log('SyncService: Sync already in progress or ran recently, skipping');
          }
        } else {
          developer.log('SyncService: Connection lost, sync paused');
        }
      },
    );
  }
  
  // Synchroniser les incidents en attente
  Future<void> syncPendingIncidents() async {
    try {
      // Record the sync attempt time
      _lastSyncTime = DateTime.now();
      
      // Double-check the lock to prevent multiple syncs
      if (_syncLock && isSyncing.value) {
        developer.log('Sync already in progress (lock active), skipping');
        return;
      }
      
      // Set syncing flag to true
      isSyncing.value = true;
      
      // Check for internet connection
      if (!_connectivityService.isConnected.value) {
        developer.log('No internet connection, skipping sync');
        isSyncing.value = false;
        _syncLock = false;
        return;
      }
      
      // Check if there are any pending incidents before starting sync
      final pendingIncidents = await _incidentService.getPendingIncidents();
      if (pendingIncidents.isEmpty) {
        developer.log('No pending incidents to sync');
        isSyncing.value = false;
        _syncLock = false;
        return;
      }
      
      developer.log('Found ${pendingIncidents.length} pending incidents to sync');
      developer.log('SyncService: ---------- STARTING SYNC OPERATION ----------');
      
      // Vérifier la connectivité avant de commencer
      final isConnected = await _connectivityService.checkConnectivity();
      developer.log('SyncService: Internet connection available: $isConnected');
      
      if (!isConnected) {
        developer.log('SyncService: No connection available, skipping sync');
        isSyncing.value = false;
        return;
      }
      
      // Verify authentication - use ensureValidToken to get a valid token
      final token = await _apiService.ensureValidToken();
      if (token == null) {
        developer.log('SyncService: No valid authentication token found, skipping sync');
        isSyncing.value = false;
        return;
      }
      developer.log('SyncService: Valid authentication token found, proceeding with sync');
      
      // Récupérer les incidents non synchronisés
      final unsyncedIncidents = await _incidentService.getUnsyncedIncidents();
      developer.log('SyncService: Found ${unsyncedIncidents.length} unsynced incidents');
      
      if (unsyncedIncidents.isEmpty) {
        developer.log('SyncService: No incidents to sync, operation completed');
        isSyncing.value = false;
        return;
      }
      
      // Synchroniser chaque incident
      int successCount = 0;
      int failCount = 0;
      
      for (final incident in unsyncedIncidents) {
        try {
          developer.log('SyncService: Processing incident ID ${incident.id}');
          await _syncIncident(incident);
          successCount++;
        } catch (e) {
          developer.log('SyncService: Error syncing incident ${incident.id}', error: e);
          failCount++;
          // Continuer avec le prochain incident même si celui-ci échoue
        }
      }
      
      // Refresh incidents list after syncing
      if (successCount > 0) {
        try {
          // Get the current user ID from storage or use default value 1 for testing
          const storage = FlutterSecureStorage();
          final userIdStr = await storage.read(key: 'user_id');
          final userId = userIdStr != null ? int.parse(userIdStr) : 1; 
          
          // Reload incidents with the correct user ID
          await _incidentService.getUserIncidents(userId);
          
          // Also refresh the stats if StatsService is available
          try {
            final statsService = Get.find<StatsService>();
            await statsService.refreshStats();
          } catch (e) {
            // Stats service might not be initialized yet, ignore error
          }
        } catch (e) {
          developer.log('Error refreshing incidents after sync', error: e);
        }
      }
      
      // Reset syncing flag and lock
      isSyncing.value = false;
      _syncLock = false;
      developer.log('SyncService: Sync completed - Success: $successCount, Failed: $failCount');
      developer.log('SyncService: ---------- SYNC OPERATION COMPLETED ----------');
    } catch (e) {
      // Reset syncing flag and lock in case of error
      isSyncing.value = false;
      _syncLock = false;
      developer.log('Error during sync operation: $e');
      developer.log('SyncService: ---------- SYNC OPERATION FAILED ----------');
    }
  }
  
  // Synchroniser un incident spécifique
  Future<void> _syncIncident(Incident incident) async {
    try {
      developer.log('SyncService: -------- SYNCING INCIDENT ${incident.id} --------');
      developer.log('SyncService: Incident details: ${incident.title}, type: ${incident.incidentType}, userID: ${incident.userId}');
      
      // Check user ID
      // ignore: unnecessary_null_comparison
      if (incident.userId == null || incident.userId <= 0) {
        developer.log('SyncService: WARNING - Invalid user ID: ${incident.userId}. Setting to default value 1.');
        // Set a default value for testing
        incident = incident.copyWith(userId: 1);
      }
      
      // Convertir l'incident en format approprié pour l'API
      final incidentData = {
        'title': incident.title,
        'description': incident.description,
        'latitude': incident.latitude,
        'longitude': incident.longitude,
        'incident_type': incident.incidentType,
        'created_at': incident.createdAt.toIso8601String(),
        'photo_path': incident.photoPath,
        'voice_note_path': incident.voiceNotePath,
        'status': 'pending',
        'sync_status': 'pending',
        'user': incident.userId, // Make sure to include the user ID for the API
        // Convert additional_media to JSON string if it's not empty
        'additional_media': incident.additionalMedia.isEmpty ? '[]' : jsonEncode(incident.additionalMedia),
      };
      
      developer.log('SyncService: Incident data prepared for API: $incidentData');
      
      // Get a valid authentication token using ensureValidToken
      final token = await _apiService.ensureValidToken();
      developer.log('SyncService: Using auth token: ${token != null ? 'valid token exists' : 'token is null'}');
      
      if (token == null) {
        developer.log('SyncService: Failed to sync incident ${incident.id} - Invalid or missing token');
        throw Exception('Invalid or missing authentication token');
      }
      
      // Check connectivity again before API call
      final isConnected = await _connectivityService.checkConnectivity();
      developer.log('SyncService: Connectivity check before API call: $isConnected');
      
      if (!isConnected) {
        developer.log('SyncService: Failed to sync incident ${incident.id} - No internet connection');
        throw Exception('No internet connection');
      }
      
      // Envoyer l'incident au serveur
      developer.log('SyncService: Sending incident to API...');
      final response = await _apiService.syncIncident(incidentData);
      
      // ignore: unnecessary_null_comparison
      if (response == null) {
        developer.log('SyncService: API returned null response for incident ${incident.id}');
        throw Exception('API returned null response');
      }
      
      developer.log('SyncService: API response for incident ${incident.id}: $response');
      
      // Si la synchronisation réussit, mettre à jour l'état de l'incident local
      await _incidentService.updateIncidentSyncStatus(incident.id, 'synced');
      
      developer.log('SyncService: Incident ${incident.id} synced successfully');
      developer.log('SyncService: -------- SYNC COMPLETE FOR INCIDENT ${incident.id} --------');
    } catch (e) {
      developer.log('SyncService: Failed to sync incident ${incident.id}', error: e);
      developer.log('SyncService: -------- SYNC FAILED FOR INCIDENT ${incident.id} --------');
      rethrow; // Propager l'erreur pour la gestion par l'appelant
    }
  }
  
  // Méthode publique pour déclencher manuellement la synchronisation
  Future<void> manualSync() async {
    developer.log('Manual sync requested');
    return syncPendingIncidents();
  }
} 