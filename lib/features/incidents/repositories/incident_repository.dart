import 'package:get/get.dart';
import 'dart:developer' as developer;
import '../../../core/database/database_helper.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/connectivity_service.dart';
import '../models/incident.dart';

class IncidentRepository {
  // Utiliser ApiService au lieu de ApiClient
  final ApiService _apiService = Get.find<ApiService>();
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  final _db = DatabaseHelper.instance;
  final RxBool isSyncing = false.obs;

  Future<List<Incident>> getIncidents() async {
    try {
      // Vérifier d'abord la connectivité
      if (!_connectivityService.isConnected.value) {
        throw Exception('No internet connection');
      }
      
      // Obtenir les incidents du serveur
      final incidents = await _apiService.getUserIncidents();
      
      // Obtenir les incidents locaux avec statut 'pending'
      final localIncidents = await _db.getUnsyncedIncidents();
      
      // Convertir les incidents du serveur en objets Incident
      final serverIncidents = incidents.map((data) => Incident.fromMap(data)).toList();
      
      // Convertir les incidents locaux en objets Incident
      final pendingIncidents = localIncidents.map((data) => Incident.fromMap(data)).toList();
      
      // Fusionner les deux listes
      final mergedIncidents = [...serverIncidents];
      
      // Ajouter tous les incidents locaux avec statut 'pending'
      // car ils ne sont pas encore sur le serveur
      mergedIncidents.addAll(pendingIncidents);
      
      developer.log('Merged incidents: ${mergedIncidents.length} (${serverIncidents.length} from server, ${pendingIncidents.length} pending)');
      
      return mergedIncidents;
    } catch (e) {
      developer.log('Error fetching incidents from API: $e');
      // Si l'API échoue, retourner les incidents locaux
      final localIncidents = await _db.getIncidentsByUserId(1); // Utiliser l'ID utilisateur 1 par défaut
      return localIncidents.map((data) => Incident.fromMap(data)).toList();
    }
  }

  Future<bool> createIncident(Incident incident) async {
    try {
      // S'assurer que le statut de synchronisation est 'pending' par défaut
      final pendingIncident = incident.copyWith(syncStatus: 'pending');
      final incidentMap = pendingIncident.toMap();
      
      // Toujours enregistrer localement d'abord
      final localId = await _db.insertIncident(incidentMap);
      developer.log('Incident saved locally with ID: $localId');
      
      // Si connecté, essayer de synchroniser immédiatement
      if (_connectivityService.isConnected.value) {
        try {
          developer.log('Connected to network, attempting to sync incident');
          final response = await _apiService.syncIncident(incidentMap);
          
          // Mettre à jour l'incident local avec le statut 'synced'
          if (response.containsKey('id')) {
            await _db.updateIncidentSyncStatus(localId, 'synced');
            // Mettre à jour l'incident avec les données du serveur
            final updatedData = {
              'sync_status': 'synced',
              // Stocker l'ID du serveur dans un champ de la base de données locale si nécessaire
              // Pour l'instant, nous utilisons simplement le statut de synchronisation
            };
            await _db.updateIncident(localId, updatedData);
            developer.log('Incident synced successfully with server ID: ${response['id']}');
          }
        } catch (syncError) {
          developer.log('Failed to sync incident: $syncError');
          // L'incident reste en statut 'pending' dans la base de données locale
        }
      } else {
        developer.log('No network connection, incident will be synced later');
      }
      
      return true;
    } catch (e) {
      developer.log('Error creating incident: $e');
      return false;
    }
  }

  Future<void> syncOfflineIncidents() async {
    if (isSyncing.value) return;
    
    try {
      isSyncing.value = true;
      developer.log('Starting sync of offline incidents');
      
      // Vérifier la connectivité
      if (!_connectivityService.isConnected.value) {
        developer.log('No network connection, sync aborted');
        return;
      }
      
      final unsyncedIncidents = await _db.getUnsyncedIncidents();
      developer.log('Found ${unsyncedIncidents.length} unsynced incidents');
      
      if (unsyncedIncidents.isEmpty) return;
      
      // Synchroniser chaque incident individuellement
      for (var incident in unsyncedIncidents) {
        try {
          developer.log('Syncing incident ID: ${incident['id']}');
          final response = await _apiService.syncIncident(incident);
          
          // Mettre à jour le statut de synchronisation
          if (response.containsKey('id')) {
            await _db.updateIncidentSyncStatus(incident['id'], 'synced');
            // Mettre à jour l'incident avec les données du serveur
            final updatedData = {
              'sync_status': 'synced',
              // D'autres champs pourraient être mis à jour ici si nécessaire
            };
            await _db.updateIncident(incident['id'], updatedData);
            developer.log('Incident ${incident['id']} synced successfully with server ID: ${response['id']}');
          }
        } catch (e) {
          developer.log('Failed to sync incident ${incident['id']}: $e');
          // Continuer avec le prochain incident même si celui-ci échoue
          continue;
        }
      }
      
      developer.log('Sync completed');
    } catch (e) {
      developer.log('Error during sync process: $e');
    } finally {
      isSyncing.value = false;
    }
  }
  
  // Méthode pour obtenir tous les incidents (locaux + serveur)
  Future<List<Incident>> getAllIncidents() async {
    // Obtenir d'abord les incidents du serveur si possible
    List<Incident> allIncidents = [];
    
    try {
      if (_connectivityService.isConnected.value) {
        final serverIncidents = await _apiService.getUserIncidents();
        allIncidents = serverIncidents.map((data) => Incident.fromMap(data)).toList();
        developer.log('Retrieved ${allIncidents.length} incidents from server');
      }
    } catch (e) {
      developer.log('Failed to get incidents from server: $e');
    }
    
    // Ensuite, obtenir tous les incidents locaux
    final localIncidents = await _db.getIncidentsByUserId(1); // Utiliser l'ID utilisateur 1 par défaut
    final localIncidentObjects = localIncidents.map((data) => Incident.fromMap(data)).toList();
    developer.log('Retrieved ${localIncidentObjects.length} incidents from local database');
    
    // Ajouter les incidents locaux qui ne sont pas déjà dans la liste des incidents du serveur
    for (var localIncident in localIncidentObjects) {
      // Si l'incident a un statut 'pending', l'ajouter à la liste
      if (localIncident.syncStatus == 'pending') {
        allIncidents.add(localIncident);
      }
    }
    
    developer.log('Total merged incidents: ${allIncidents.length}');
    return allIncidents;
  }
}
