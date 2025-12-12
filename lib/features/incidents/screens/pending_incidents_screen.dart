import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../controllers/incident_controller.dart';
import '../widgets/incident_card.dart';
import '../models/incident.dart';
import '../../../core/network/connectivity_service.dart';
import '../services/sync_service.dart';

class PendingIncidentsScreen extends StatefulWidget {
  const PendingIncidentsScreen({super.key});

  @override
  State<PendingIncidentsScreen> createState() => _PendingIncidentsScreenState();
}

class _PendingIncidentsScreenState extends State<PendingIncidentsScreen> {
  final IncidentController _incidentController = Get.find<IncidentController>();
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  
  // Pagination
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    // Load incidents when the screen initializes
    Future.microtask(() {
      _incidentController.loadIncidents();
    });
  }
  
  // Get only pending (not synced) incidents, sorted by most recent date
  List<Incident> _getPendingIncidents() {
    return _incidentController.incidents
        .where((i) => i.syncStatus == 'pending')
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by most recent
  }
  
  void _syncPendingIncidents() {
    if (!_connectivityService.isConnected.value) {
      Get.snackbar(
        'Synchronization unavailable',
        'Please check your internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    // Get SyncService and trigger manual sync
    try {
      final syncService = Get.find<SyncService>();
      syncService.manualSync();
      Get.snackbar(
        'Synchronization',
        'Synchronizing incidents...',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to synchronize: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncPendingIncidents,
            tooltip: 'Sync all',
          ),
        ],
      ),
      body: Obx(() {
        if (_incidentController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final pendingIncidents = _getPendingIncidents();
        
        if (pendingIncidents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_done, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'All incidents are synchronized',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'No incidents pending synchronization',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Add pagination
        final pageSize = 5; // Number of items per page
        final totalPages = (pendingIncidents.length / pageSize).ceil();
        final currentPage = _currentPage.clamp(0, totalPages - 1);
        final startIndex = currentPage * pageSize;
        final endIndex = min((currentPage + 1) * pageSize, pendingIncidents.length);
        
        // Get current page items
        final pageItems = pendingIncidents.sublist(startIndex, endIndex);
        
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pageItems.length,
                itemBuilder: (context, index) {
                  final incident = pageItems[index];
                  return IncidentCard(
                    incident: incident,
                    onTap: () => Get.toNamed('/incident/details', arguments: incident),
                  );
                },
              ),
            ),
            // Pagination controls
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text('${currentPage + 1} / $totalPages',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: currentPage < totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}
