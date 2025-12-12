import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/database/database_helper.dart';
import '../models/incident.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/connectivity_service.dart';
import 'stats_service.dart';
import 'audio_service.dart';
import 'sync_service.dart';
import 'package:flutter/material.dart';

class IncidentService extends GetxController {
  final _db = DatabaseHelper.instance;
  final _imagePicker = ImagePicker();
  late final AudioService _audioService;
  late final ConnectivityService _connectivityService;
  
  RxList<Incident> incidents = <Incident>[].obs;
  RxBool isRecording = false.obs;
  final RxBool isSyncing = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    // Initialize services safely
    _initializeServices();
    
    // Set up periodic sync
    _setupPeriodicSync();
  }
  
  void _initializeServices() {
    try {
      // Try to find existing services
      _audioService = Get.find<AudioService>();
      developer.log('AudioService found successfully');
    } catch (e) {
      // Create a new instance if not found
      _audioService = Get.put(AudioService());
      developer.log('AudioService created anew');
    }
    
    try {
      _connectivityService = Get.find<ConnectivityService>();
      developer.log('ConnectivityService found successfully');
    } catch (e) {
      _connectivityService = Get.put(ConnectivityService());
      developer.log('ConnectivityService created anew');
    }
  }

  void _setupPeriodicSync() {
    // Sync every 15 minutes if there are pending incidents
    ever(_connectivityService.isConnected, (isConnected) {
      if (isConnected) {
        syncPendingIncidents();
      }
    });
    
    // Also set up a timer to check periodically
    Timer.periodic(const Duration(minutes: 15), (_) async {
      if (_connectivityService.isConnected.value) {
        await syncPendingIncidents();
      }
    });
  }

  // Location handling
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  // Image capture
  Future<String?> captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      return image?.path;
    } catch (e) {
      return null;
    }
  }

  // Voice recording
  Future<bool> startVoiceRecording() async {
    try {
      final success = await _audioService.startRecording();
      if (success) {
        isRecording.value = true;
      }
      return success;
    } catch (e) {
      developer.log('Error starting recording', error: e);
      return false;
    }
  }

  Future<String?> stopVoiceRecording() async {
    try {
      if (!isRecording.value) return null;
      
      final path = await _audioService.stopRecording();
      isRecording.value = false;
      return path;
    } catch (e) {
      developer.log('Error stopping recording', error: e);
      return null;
    }
  }

  // Create a new incident
  Future<bool> createIncident(Incident incident) async {
    try {
      // Create a new incident with 'pending' sync status
      final pendingIncident = incident.copyWith(syncStatus: 'pending');
      
      // Prepare incident map
      final incidentMap = pendingIncident.toMap();
      
      // Force the sync_status to be 'pending' regardless of what was passed
      incidentMap['sync_status'] = 'pending';
      
      // Ensure additional_media is stored as a JSON string
      if (incidentMap['additional_media'] != null && incidentMap['additional_media'] is! String) {
        incidentMap['additional_media'] = jsonEncode(incidentMap['additional_media']);
      }
      
      // Save to database
      final insertedId = await _db.insertIncident(incidentMap);
      developer.log('Incident created with ID: $insertedId');
      
      // Make sure the incident has the correct ID from the database
      final updatedIncident = pendingIncident.copyWith(id: insertedId);
      
      // Add to the observable list with the correct sync status and ID
      incidents.add(updatedIncident);
      developer.log('Added incident to observable list: ${updatedIncident.id}');
      
      // Refresh statistics to update the pending count
      try {
        if (Get.isRegistered<StatsService>()) {
          final statsService = Get.find<StatsService>();
          await statsService.refreshStats();
          developer.log('Statistics refreshed after creating incident');
        }
      } catch (e) {
        developer.log('Error refreshing statistics: $e');
        // Continue anyway, this is not critical
      }
      
      // Try to sync the incident immediately if connected to the internet
      try {
        if (_connectivityService.isConnected.value) {
          developer.log('Attempting to sync newly created incident');
          // Try to get the SyncService and trigger sync
          if (Get.isRegistered<SyncService>()) {
            final syncService = Get.find<SyncService>();
            syncService.syncPendingIncidents();
          }
        }
      } catch (e) {
        developer.log('Error initiating sync after incident creation: $e');
        // Continue anyway, this is not critical
      }
      
      return true;
    } catch (e, stackTrace) {
      developer.log('Error creating incident', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Get incidents for a specific user
  Future<List<Incident>> getUserIncidents(int userId) async {
    try {
      developer.log('Getting incidents for user $userId');
      
      // First, get local incidents from the database
      final dbIncidents = await _db.getIncidentsByUserId(userId);
      developer.log('Found ${dbIncidents.length} local incidents in database');
      
      // Try to fetch remote incidents from the backend and clean up local database
      // Only if we have internet connection - this prevents the issue with incidents not appearing when offline
      if (_connectivityService.isConnected.value) {
        await fetchRemoteIncidents(userId);
        developer.log('Fetched remote incidents and updated local database');
      } else {
        developer.log('Skipping remote fetch - no internet connection');
      }
      
      // Get updated list of incidents from database (includes both local and remote incidents)
      final updatedDbIncidents = await _db.getIncidentsByUserId(userId);
      developer.log('After sync attempt: found ${updatedDbIncidents.length} incidents in database');
      
      // Create a map to track unique incident IDs to prevent duplicates
      // Using a map instead of a set to keep track of the most recent version of each incident
      final Map<int, Map<String, dynamic>> uniqueIncidentsMap = {};
      
      // First pass: collect all incidents by ID
      for (var map in updatedDbIncidents) {
        final newMap = Map<String, dynamic>.from(map);
        final int incidentId = newMap['id'];
        
        // If this ID is already in our map, only replace it if this one is newer or has sync_status = 'synced'
        if (uniqueIncidentsMap.containsKey(incidentId)) {
          final existingIncident = uniqueIncidentsMap[incidentId]!;
          final existingSyncStatus = existingIncident['sync_status'];
          final newSyncStatus = newMap['sync_status'];
          
          // Prefer synced incidents over pending ones
          if (existingSyncStatus == 'pending' && newSyncStatus == 'synced') {
            uniqueIncidentsMap[incidentId] = newMap;
          }
        } else {
          // This is the first time we're seeing this ID
          uniqueIncidentsMap[incidentId] = newMap;
        }
      }
      
      // Convert the map values to a list of Incident objects
      final List<Incident> uniqueIncidents = [];
      
      // Process each unique incident
      for (var newMap in uniqueIncidentsMap.values) {
        
        // Make sure additional_media is properly handled
        if (newMap['additional_media'] is String) {
          try {
            // Try to parse the JSON string
            newMap['additional_media'] = jsonDecode(newMap['additional_media']);
          } catch (e) {
            // If parsing fails, set to empty list
            newMap['additional_media'] = [];
          }
        }
        
        // Add to unique incidents list
        uniqueIncidents.add(Incident.fromMap(newMap));
      }
      
      developer.log('Filtered to ${uniqueIncidents.length} unique incidents');
      
      // Update the observable list
      incidents.value = uniqueIncidents;
      
      return uniqueIncidents;
    } catch (e) {
      developer.log('Error getting user incidents', error: e);
      return [];
    }
  }
  
  // Fetch incidents from the backend and store them locally
  Future<void> fetchRemoteIncidents(int userId) async {
    try {
      // Check connectivity first
      if (!_connectivityService.isConnected.value) {
        developer.log('Cannot fetch remote incidents: No internet connection');
        return;
      }
      
      developer.log('Fetching remote incidents from backend');
      
      // Get the API service
      final apiService = Get.find<ApiService>();
      
      // Check if we have a valid token - use ensureValidToken instead of getStoredToken
      final token = await apiService.ensureValidToken();
      if (token == null) {
        developer.log('Cannot fetch remote incidents: No valid authentication token');
        return;
      }
      
      // Fetch incidents from the backend
      final remoteIncidents = await apiService.getUserIncidents();
      developer.log('Fetched ${remoteIncidents.length} incidents from backend');
      
      // Get existing local incidents
      final localIncidents = await _db.getIncidentsByUserId(userId);
      final localIncidentIds = localIncidents.map((inc) => inc['id'] as int).toSet();
      final remoteIncidentIds = remoteIncidents.map((inc) => inc['id'] as int).toSet();
      
      // Clean up local database - remove any incidents that don't exist in the backend
      // except for pending incidents that haven't been synced yet
      await _cleanupLocalIncidents(userId, localIncidents, remoteIncidentIds);
      
      // Process each remote incident
      int newCount = 0;
      int updatedCount = 0;
      
      for (var remoteIncident in remoteIncidents) {
        final int remoteId = remoteIncident['id'];
        
        // Check if this incident already exists locally
        if (localIncidentIds.contains(remoteId)) {
          // Update existing incident
          await _db.updateIncident(remoteId, {
            'title': remoteIncident['title'],
            'description': remoteIncident['description'],
            'photo_url': remoteIncident['photo_url'],
            'latitude': remoteIncident['latitude'],
            'longitude': remoteIncident['longitude'],
            'status': remoteIncident['status'],
            'incident_type': remoteIncident['incident_type'],
            'sync_status': 'synced',
            // Don't update local paths
            // Ensure additional_media is properly handled
            'additional_media': remoteIncident['additional_media'] != null ? 
                                 (remoteIncident['additional_media'] is String ? 
                                  remoteIncident['additional_media'] : 
                                  jsonEncode(remoteIncident['additional_media'])) : 
                                 '[]',
          });
          updatedCount++;
        } else {
          // Create new incident record locally
          final newIncident = {
            'id': remoteId,
            'title': remoteIncident['title'],
            'description': remoteIncident['description'],
            'photo_path': null,
            'photo_url': remoteIncident['photo_url'],
            'voice_note_path': null,
            'latitude': remoteIncident['latitude'] ?? 0.0,
            'longitude': remoteIncident['longitude'] ?? 0.0,
            'created_at': remoteIncident['created_at'],
            'status': remoteIncident['status'] ?? 'pending',
            'incident_type': remoteIncident['incident_type'] ?? 'general',
            'sync_status': 'synced',
            'user_id': userId,
            'additional_media': remoteIncident['additional_media'] != null ? 
                                (remoteIncident['additional_media'] is String ? 
                                 remoteIncident['additional_media'] : 
                                 jsonEncode(remoteIncident['additional_media'])) : 
                                '[]',
          };
          
          await _db.insertIncident(newIncident);
          newCount++;
        }
      }
      
      developer.log('Sync complete: Added $newCount new incidents, updated $updatedCount existing incidents');
    } catch (e) {
      developer.log('Error fetching remote incidents', error: e);
    }
  }
  
  // Get only pending (not synced) incidents
  Future<List<Incident>> getPendingIncidents() async {
    try {
      // Get current user ID from secure storage
      const storage = FlutterSecureStorage();
      final userIdStr = await storage.read(key: 'user_id');
      final userId = userIdStr != null ? int.parse(userIdStr) : 0;
      
      if (userId <= 0) {
        developer.log('No valid user ID found for getting pending incidents');
        return [];
      }
      
      developer.log('Getting pending incidents for user $userId');
      final dbIncidents = await _db.getIncidentsByUserId(userId);
      
      // Debug log to see all incidents and their sync status
      for (var incident in dbIncidents) {
        developer.log('DB incident ID: ${incident['id']}, sync_status: ${incident['sync_status']}');
      }
      
      // Create a set to track unique incident IDs to prevent duplicates
      final Set<int> processedIds = {};
      final List<Incident> uniquePendingIncidents = [];
      
      // Filter to only include pending incidents and ensure no duplicates
      for (var map in dbIncidents) {
        // Skip if not pending
        if (map['sync_status'] != 'pending') {
          developer.log('Skipping non-pending incident: ${map['id']}');
          continue;
        }
        
        developer.log('Found pending incident: ${map['id']}');
        
        // Create a new map to avoid modifying the original read-only map
        final newMap = Map<String, dynamic>.from(map);
        final int incidentId = newMap['id'];
        
        // Skip if we've already processed this incident
        if (processedIds.contains(incidentId)) continue;
        
        // Add to processed set
        processedIds.add(incidentId);
        
        // Make sure additional_media is properly handled
        if (newMap['additional_media'] is String) {
          try {
            // Try to parse the JSON string
            newMap['additional_media'] = jsonDecode(newMap['additional_media']);
          } catch (e) {
            // If parsing fails, set to empty list
            newMap['additional_media'] = [];
          }
        }
        
        // Add to unique pending incidents list
        uniquePendingIncidents.add(Incident.fromMap(newMap));
      }
      
      developer.log('Found ${uniquePendingIncidents.length} unique pending incidents');
      return uniquePendingIncidents;
    } catch (e) {
      developer.log('Error getting pending incidents', error: e);
      return [];
    }
  }
  
  // Get unsynced incidents (alias for getPendingIncidents for compatibility)
  Future<List<Incident>> getUnsyncedIncidents() async {
    return getPendingIncidents();
  }

  Future<List<Incident>> getUnsyncedIncidentsFromDB() async {
    try {
      final incidents = await _db.getUnsyncedIncidents();
      
      // Create a set to track unique incident IDs to prevent duplicates
      final Set<int> processedIds = {};
      final List<Incident> uniqueUnsyncedIncidents = [];
      
      // Process each incident, ensuring no duplicates
      for (var map in incidents) {
        // Create a new map to avoid modifying the original read-only map
        final newMap = Map<String, dynamic>.from(map);
        final int incidentId = newMap['id'];
        
        // Skip if we've already processed this incident
        if (processedIds.contains(incidentId)) continue;
        
        // Add to processed set
        processedIds.add(incidentId);
        
        // Make sure additional_media is properly handled
        if (newMap['additional_media'] is String) {
          try {
            // Try to parse the JSON string
            newMap['additional_media'] = jsonDecode(newMap['additional_media']);
          } catch (e) {
            // If parsing fails, set to empty list
            newMap['additional_media'] = [];
          }
        }
        
        // Add to unique incidents list
        uniqueUnsyncedIncidents.add(Incident.fromMap(newMap));
      }
      
      developer.log('Found ${uniqueUnsyncedIncidents.length} unique unsynced incidents');
      return uniqueUnsyncedIncidents;
    } catch (e, stackTrace) {
      developer.log('Error getting unsynced incidents', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> syncIncident(Incident incident) async {
    try {
      developer.log('Starting to sync incident with server: ${incident.id}');
      
      // Get the API service
      final apiService = Get.find<ApiService>();
      
      // First check if we have a token
      final token = await apiService.getStoredToken();
      if (token == null) {
        developer.log('Cannot sync incident: No authentication token available');
        
        // Show dialog to prompt re-login
        Get.snackbar(
          'Authentication Required',
          'Please log in again to upload your incident reports',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            child: const Text('Login'),
            onPressed: () => Get.offAllNamed('/login'),
          ),
        );
        
        throw Exception('Not authenticated - token missing');
      }
      
      // Prepare incident data for the API
      final Map<String, dynamic> incidentData = {
        'title': incident.title,
        'description': incident.description,
        'latitude': incident.latitude,
        'longitude': incident.longitude,
        'incident_type': incident.incidentType,
        'created_at': incident.createdAt.toIso8601String(),
        'user': incident.userId,
        'status': 'pending',
        'sync_status': 'pending',
        'photo_path': incident.photoPath,
        'voice_note_path': incident.voiceNotePath,
      };
      
      // Call the API to sync the incident
      developer.log('Sending incident to server: $incidentData');
      final response = await apiService.syncIncident(incidentData);
      
      // ignore: unnecessary_null_comparison
      if (response != null) {
        // Update local status to synced
      await _db.updateIncidentSyncStatus(incident.id, 'synced');
        developer.log('Incident synced successfully: ${incident.id}');
      } else {
        developer.log('Failed to sync incident: ${incident.id}');
      }
    } catch (e, stackTrace) {
      developer.log('Error syncing incident', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Sync operations
  Future<void> syncPendingIncidents() async {
    // Skip if already syncing
    if (isSyncing.value) {
      developer.log('Sync already in progress, skipping');
      return;
    }
    
    try {
      isSyncing.value = true;
      developer.log('-------- STARTING SYNC PROCESS --------');
      developer.log('Attempting to sync pending incidents to backend');
      
      // Check for internet connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      developer.log('Internet connection status: $isConnected');
      
      if (!isConnected) {
        developer.log('No internet connection, sync aborted');
        isSyncing.value = false;
        return;
      }
      
      // Get unsynced incidents
      developer.log('Fetching unsynced incidents from local database');
      final List<Map<String, dynamic>> unsyncedIncidents = 
          await _db.getUnsyncedIncidents();
      
      if (unsyncedIncidents.isEmpty) {
        developer.log('No pending incidents to sync');
        isSyncing.value = false;
        return;
      }
      
      developer.log('Found ${unsyncedIncidents.length} incidents to sync');
      
      // Get API service for sending data
      developer.log('Getting API service for syncing');
      final apiService = Get.find<ApiService>();
      
      // Check for authentication token
      developer.log('Checking for authentication token');
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) {
        developer.log('Syncing incidents failed: No authentication token found');
        isSyncing.value = false;
        return;
      }
      developer.log('Authentication token found, continuing with sync');
      
      int successCount = 0;
      int failCount = 0;
      
      // Process each unsynced incident
      for (var incidentMap in unsyncedIncidents) {
        try {
          final incident = Incident.fromMap(incidentMap);
          
          developer.log('Processing incident ID: ${incident.id} for sync');
          developer.log('Incident details: title=${incident.title}, type=${incident.incidentType}, userId=${incident.userId}');
          
          // Prepare data for API in proper format
          final Map<String, dynamic> incidentData = {
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
            'user': incident.userId, // Make sure to include the user ID
          };
          
          developer.log('Syncing incident ${incident.id} to backend');
          
          // Call API to sync incident
          final response = await apiService.syncIncident(incidentData);
          
          // ignore: unnecessary_null_comparison
          if (response != null) {
            // Update local status to synced
            developer.log('Successfully synced incident ${incident.id} to backend, updating local status');
            await _db.updateIncidentSyncStatus(incident.id, 'synced');
            developer.log('Incident ${incident.id} successfully synced');
            successCount++;
          } else {
            developer.log('Failed to sync incident ${incident.id}: null response from API');
            failCount++;
          }
        } catch (e) {
          developer.log('Error syncing incident: $e');
          failCount++;
        }
      }
      
      developer.log('Sync completed - Success: $successCount, Failed: $failCount');
      
      // Update the incidents list if any were successfully synced
      if (successCount > 0) {
        // Reload incidents to reflect new sync status
        developer.log('Reloading incidents list after successful sync');
        final currentUserId = await const FlutterSecureStorage().read(key: 'user_id');
        if (currentUserId != null) {
          developer.log('Reloading incidents for user ID: $currentUserId');
          await getUserIncidents(int.parse(currentUserId));
        } else {
          developer.log('Cannot reload incidents: user ID not found');
        }
      }
      
      developer.log('-------- SYNC PROCESS COMPLETED --------');
    } catch (e, stackTrace) {
      developer.log('Error during sync process', error: e, stackTrace: stackTrace);
    } finally {
      isSyncing.value = false;
    }
  }

  // Mettre à jour le statut de synchronisation d'un incident
  Future<void> updateIncidentSyncStatus(int incidentId, String syncStatus) async {
    try {
      await _db.updateIncident(incidentId, {'sync_status': syncStatus});
      
      // Update the incident in the list if it exists
      final index = incidents.indexWhere((inc) => inc.id == incidentId);
      if (index != -1) {
        final incident = incidents[index];
        final updatedIncident = incident.copyWith(syncStatus: syncStatus);
        incidents[index] = updatedIncident;
        incidents.refresh();
      }
      
      developer.log('Updated sync status for incident $incidentId to $syncStatus');
    } catch (e) {
      developer.log('Error updating incident sync status', error: e);
    }
  }
  
  // Clean up local incidents that don't exist in the backend
  // This helps prevent duplicate incidents and ensures the local database matches the backend
  Future<void> _cleanupLocalIncidents(int userId, List<Map<String, dynamic>> localIncidents, Set<int> remoteIncidentIds) async {
    try {
      developer.log('Starting local database cleanup for user $userId');
      
      // Track incidents to remove
      final List<int> incidentsToRemove = [];
      
      // Check each local incident
      for (var incident in localIncidents) {
        final int incidentId = incident['id'] as int;
        final String syncStatus = incident['sync_status'] as String;
        
        // Only remove synced incidents that don't exist in the backend
        // Keep pending incidents even if they don't exist in the backend
        if (syncStatus == 'synced' && !remoteIncidentIds.contains(incidentId)) {
          incidentsToRemove.add(incidentId);
        }
      }
      
      // Remove the identified incidents
      if (incidentsToRemove.isNotEmpty) {
        developer.log('Removing ${incidentsToRemove.length} orphaned incidents from local database');
        
        for (var incidentId in incidentsToRemove) {
          await _db.deleteIncident(incidentId);
          developer.log('Deleted orphaned incident $incidentId');
        }
      } else {
        developer.log('No orphaned incidents found during cleanup');
      }
      
      developer.log('Local database cleanup completed');
    } catch (e, stackTrace) {
      developer.log('Error updating incident sync status', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

}
