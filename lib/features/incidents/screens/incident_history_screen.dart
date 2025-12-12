import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../controllers/incident_controller.dart';
import '../widgets/incident_card.dart';
import '../models/incident.dart';
import '../../../core/network/connectivity_service.dart';
import '../services/sync_service.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  final IncidentController _incidentController = Get.find<IncidentController>();
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  
  // Filtres
  final RxString _statusFilter = 'all'.obs;
  final RxString _typeFilter = 'all'.obs;
  final RxString _sortOption = 'date_desc'.obs;
  
  // Define all possible statuses
  final List<Map<String, String>> _allStatuses = [
    {'value': 'all', 'label': 'All'},
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'in_progress', 'label': 'In progress'},
    {'value': 'resolved', 'label': 'Resolved'},
    {'value': 'closed', 'label': 'Closed'},
  ];
  
  // Define all possible incident types
  final List<Map<String, String>> _allTypes = [
    {'value': 'all', 'label': 'All'},
    {'value': 'accident', 'label': 'Accident'},
    {'value': 'crime', 'label': 'Crime'},
    {'value': 'fire', 'label': 'Fire'},
    {'value': 'general', 'label': 'General'},
    {'value': 'medical', 'label': 'Medical Emergency'},
    {'value': 'other', 'label': 'Other'},
  ];
  
  // Pagination
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    // Utiliser Future.microtask ou Future.delayed pour éviter
    // d'appeler loadIncidents pendant le build
    Future.microtask(() {
      _incidentController.loadIncidents();
    });
  }
  
  List<Incident> _getFilteredIncidents() {
    // Get all incidents
    List<Incident> allIncidents = List.from(_incidentController.incidents);
    
    // Separate pending sync incidents
    List<Incident> pendingSyncIncidents = allIncidents
        .where((i) => i.syncStatus == 'pending')
        .toList();
    
    // Apply filters to the rest of the incidents
    List<Incident> filteredList = allIncidents
        .where((i) => i.syncStatus != 'pending')
        .toList();
    
    // Filtrer par statut
    if (_statusFilter.value != 'all') {
      filteredList = filteredList.where((i) => i.status == _statusFilter.value).toList();
    }
    
    // Filtrer par type
    if (_typeFilter.value != 'all') {
      filteredList = filteredList.where((i) => i.incidentType == _typeFilter.value).toList();
    }
    
    // Combine filtered incidents with pending sync incidents
    // This ensures newly created incidents are always visible
    filteredList.addAll(pendingSyncIncidents);
    
    // Trier
    switch (_sortOption.value) {
      case 'date_asc':
        filteredList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
        filteredList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'status':
        filteredList.sort((a, b) => a.status.compareTo(b.status));
        break;
      case 'type':
        filteredList.sort((a, b) => a.incidentType.compareTo(b.incidentType));
        break;
    }
    
    return filteredList;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncPendingIncidents,
            tooltip: 'Sync all',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _incidentController.loadIncidents(),
        child: Obx(() {
          if (_incidentController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final incidents = _getFilteredIncidents();
          
          if (incidents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'No incidents found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No incidents match your search criteria',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Get.toNamed('/incident/create'),
                    child: const Text('Report an incident'),
                  ),
                ],
              ),
            );
          }
          
          // Add pagination
          final pageSize = 5; // Number of items per page
          final totalPages = (incidents.length / pageSize).ceil();
          final currentPage = _currentPage.clamp(0, totalPages - 1);
          final startIndex = currentPage * pageSize;
          final endIndex = min((currentPage + 1) * pageSize, incidents.length);
          
          // Get current page items
          final pageItems = incidents.sublist(startIndex, endIndex);
          
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/incident/create'),
        icon: const Icon(Icons.add),
        label: const Text('Report'),
      ),
    );
  }
  
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort by'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date (newest)'),
              value: 'date_desc',
              groupValue: _sortOption.value,
              onChanged: (value) {
                _sortOption.value = value!;
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Date (oldest)'),
              value: 'date_asc',
              groupValue: _sortOption.value,
              onChanged: (value) {
                _sortOption.value = value!;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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
  
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet à la feuille de défilement de prendre plus d'espace
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16, 
                right: 16,
                top: 16
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter incidents',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Statut
                  const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Obx(() => Wrap(
                    spacing: 8,
                    children: _allStatuses.map((status) => FilterChip(
                      label: Text(status['label']!),
                      selected: _statusFilter.value == status['value'],
                      onSelected: (selected) => _statusFilter.value = status['value']!,
                    )).toList(),
                  )),
                  
                  const SizedBox(height: 16),
                  
                  // Type
                  const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Obx(() => Wrap(
                    spacing: 8,
                    children: _allTypes.map((type) => FilterChip(
                      label: Text(type['label']!),
                      selected: _typeFilter.value == type['value'],
                      onSelected: (selected) => _typeFilter.value = type['value']!,
                    )).toList(),
                  )),
                  
                  const SizedBox(height: 16),
                  
                  // Boutons d'action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _statusFilter.value = 'all';
                          _typeFilter.value = 'all';
                          _sortOption.value = 'date_desc';
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 