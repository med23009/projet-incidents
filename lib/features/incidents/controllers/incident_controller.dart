import 'package:accidentsapp/features/auth/services/auth_service.dart';
import 'package:accidentsapp/features/incidents/models/incident.dart';
import 'package:accidentsapp/features/incidents/services/incident_service.dart';
import 'package:accidentsapp/features/auth/controllers/auth_controller.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;
import '../../../core/network/api_service.dart';
import '../services/sync_service.dart';
import 'package:flutter/material.dart';

class IncidentController extends GetxController {
  final IncidentService _incidentService = Get.find<IncidentService>();
  
  final RxList<Incident> incidents = <Incident>[].obs;
  final RxBool isLoading = false.obs;
  final RxString filterStatus = 'all'.obs;
  final RxString filterType = 'all'.obs;
  final RxString sortBy = 'date'.obs;
  
  @override
  void onInit() {
    super.onInit();
    // Execution différée pour éviter de bloquer le thread principal
    Future.delayed(Duration.zero, () async {
      await loadIncidents();
    });
  }

  Future<void> loadIncidents() async {
    try {
      final authService = Get.find<AuthService>();
      final userId = authService.currentUserId.value;
      
      if (userId == null) {
        developer.log('User ID not found, unable to load incidents');
        // Ne pas utiliser Get.snackbar pendant le build d'un widget
        // Get.snackbar('Erreur', 'Identifiant utilisateur non trouvé');
        isLoading.value = false;
        return;
      }
      
      final loadedIncidents = await _incidentService.getUserIncidents(userId);
      
      // S'assurer qu'il n'y a pas de doublons (par ID)
      final Map<int, Incident> uniqueIncidents = {};
      for (var incident in loadedIncidents) {
        uniqueIncidents[incident.id] = incident;
      }
      
      incidents.value = uniqueIncidents.values.toList();
      // ignore: invalid_use_of_protected_member
      developer.log('Loaded ${incidents.value.length} incidents');
    } catch (e) {
      developer.log('Error loading incidents', error: e);
      // Ne pas utiliser Get.snackbar pendant le build d'un widget
      // Get.snackbar('Erreur', 'Impossible de charger les incidents');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createIncident({
    required String title,
    required String description,
    String? photoPath,
    String? voiceNotePath,
    required double latitude,
    required double longitude,
    required String incidentType,
    List<Map<String, dynamic>>? additionalMedia,
  }) async {
    try {
      isLoading.value = true;
      
      // Vérifier si l'AuthController est disponible
      AuthController? authController;
      int userId = 1; // Valeur par défaut si aucun ID n'est trouvé
      
      try {
        authController = Get.find<AuthController>();
        // Récupérer l'ID de l'utilisateur ou utiliser la valeur par défaut
        userId = authController.userData.value?['id'] ?? 1;
      } catch (e) {
        developer.log('AuthController not found, using default user ID', error: e);
      }
      
      // Générer un ID unique basé sur le timestamp
      final incidentId = DateTime.now().millisecondsSinceEpoch;
      
      // Vérifier si un incident similaire existe déjà (dans les 2 dernières secondes)
      final duplicateCheck = incidents.any((inc) => 
        (incidentId - inc.id).abs() < 2000 && // Créé dans les 2 dernières secondes
        inc.title == title &&
        inc.latitude == latitude &&
        inc.longitude == longitude
      );
      
      if (duplicateCheck) {
        developer.log('Duplicate incident detected, ignoring');
        return;
      }
      
      // Créer l'incident avec l'ID utilisateur récupéré ou la valeur par défaut
      final incident = Incident(
        id: incidentId,
        title: title,
        description: description,
        photoPath: photoPath,
        voiceNotePath: voiceNotePath,
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
        incidentType: incidentType,
        syncStatus: 'pending',
        userId: userId,
        additionalMedia: additionalMedia ?? [],
      );

      // Enregistrer l'incident et l'ajouter à la liste
      await _incidentService.createIncident(incident);
      incidents.add(incident);
      developer.log('Created new incident: ${incident.id}');
    } catch (e, stackTrace) {
      developer.log('Error creating incident', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncIncidents() async {
    try {
      isLoading.value = true;
      
      // Check for authentication token first
      final apiService = Get.find<ApiService>();
      final token = await apiService.getStoredToken();
      
      if (token == null) {
        developer.log('Cannot sync incidents: No authentication token found');
        Get.snackbar(
          'Authentication Required',
          'Please log in again to sync your incidents',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 5),
        );
        return;
      }
      
      final unsyncedIncidents = await _incidentService.getUnsyncedIncidents();
      developer.log('Found ${unsyncedIncidents.length} unsynced incidents');

      for (final incident in unsyncedIncidents) {
        try {
          await _incidentService.syncIncident(incident);
          developer.log('Synced incident: ${incident.id}');
        } catch (e) {
          developer.log('Error syncing incident ${incident.id}', error: e);
        }
      }

      await loadIncidents();
    } catch (e, stackTrace) {
      developer.log('Error syncing incidents', error: e, stackTrace: stackTrace);
      Get.snackbar(
        'Error',
        'Failed to sync incidents: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Add a method to manually trigger syncing with detailed logs
  Future<void> manualSyncIncidents() async {
    try {
      developer.log('-------- MANUAL SYNC TRIGGERED --------');
      isLoading.value = true;
      
      developer.log('Getting API service to check token');
      final apiService = Get.find<ApiService>();
      
      // Check token validity first
      developer.log('Checking authentication token validity');
      final validToken = await apiService.ensureValidToken();
      
      if (validToken == null) {
        developer.log('No valid token available, prompting for login');
        isLoading.value = false;
        promptReLogin();
        return;
      }
      
      developer.log('Token is valid, proceeding with sync');
      
      // Check API endpoints
      developer.log('Checking API endpoints before sync');
      await apiService.checkApiEndpoints();
      
      developer.log('Getting SyncService for manual sync');
      final syncService = Get.find<SyncService>();
      
      // Perform the sync
      developer.log('Triggering manual sync process');
      await syncService.manualSync();
      
      developer.log('Manual sync completed, refreshing incident list');
      await loadIncidents();
      
      // Show success message
      Get.snackbar(
        'Sync Complete',
        'Incidents have been synced with the server',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
      );
      
      developer.log('-------- MANUAL SYNC COMPLETED --------');
    } catch (e, stackTrace) {
      developer.log('Error during manual sync', error: e, stackTrace: stackTrace);
      Get.snackbar(
        'Sync Failed',
        'Could not sync incidents: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Add a method to handle missing tokens by triggering a re-login
  void promptReLogin() {
    Get.dialog(
      AlertDialog(
        title: Text('Authentication Required'),
        content: Text('Please log in again to upload your incident reports.'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Get.back(),
          ),
          ElevatedButton(
            child: Text('Login Now'),
            onPressed: () {
              Get.back();
              Get.offAllNamed('/login');
            },
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
