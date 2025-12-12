import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/incident_controller.dart';
import '../widgets/incident_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/network/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/stats_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IncidentController _incidentController = Get.find<IncidentController>();
  final AuthController _authController = Get.find<AuthController>();
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  
  // Use nullable variables instead of late to avoid initialization errors
  SyncService? _syncService;
  StatsService? _statsService;
  
  // Flag to track if services are initialized
  final RxBool _servicesInitialized = false.obs;
  final RxBool _isLoading = true.obs;
  
  // Method to handle manual synchronization
  void _syncManually() {
    if (_connectivityService.isConnected.value && _servicesInitialized.value) {
      _syncService?.manualSync();
    } else {
      Get.snackbar(
        'Synchronization unavailable',
        'Please check your internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _incidentController.loadIncidents();
    
    // Initialize services safely
    _initializeServices();
  }
  
  // Method to safely initialize services
  Future<void> _initializeServices() async {
    try {
      _isLoading.value = true;
      
      // Initialize StatsService
      try {
        if (!Get.isRegistered<StatsService>()) {
          final statsService = await StatsService().init();
          Get.put(statsService, permanent: true);
        }
        _statsService = Get.find<StatsService>();
      } catch (e) {
        print('Error initializing StatsService: $e');
      }
      
      // Initialize SyncService
      try {
        if (!Get.isRegistered<SyncService>()) {
          final syncService = await SyncService().init();
          Get.put(syncService, permanent: true);
        }
        _syncService = Get.find<SyncService>();
      } catch (e) {
        print('Error initializing SyncService: $e');
      }
      
      // Mark services as initialized if both are available
      if (_statsService != null && _syncService != null) {
        _servicesInitialized.value = true;
        
        // Refresh statistics when services are loaded
        _statsService?.refreshStats();
        
        // Sync if connected
        if (_connectivityService.isConnected.value) {
          _syncService?.syncPendingIncidents();
        }
      }
    } catch (e) {
      print('Error initializing services: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Incidents'),
        actions: [
          IconButton(
            icon: Obx(() => _connectivityService.isConnected.value
              ? const Icon(Icons.wifi, color: Colors.green)
              : const Icon(Icons.wifi_off, color: Colors.red)),
            onPressed: null,
            tooltip: 'Connection status',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
                tooltip: 'Sync',
            onPressed: _syncManually,
          ),
          // Add pending incidents history button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Pending incidents',
                onPressed: () => Get.toNamed('/incident/pending'),
              ),
              // Show badge if there are pending incidents
              Obx(() {
                final pendingCount = _statsService?.pendingIncidents.value ?? 0;
                if (pendingCount > 0) {
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _authController.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Overview
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Obx(() {
                  // Show loading indicator if services are initializing or stats are loading
                  if (_isLoading.value || !_servicesInitialized.value || 
                      (_statsService != null && _statsService!.isLoading.value)) {
                    return const Center(
                      heightFactor: 1,
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  // If services failed to initialize
                  if (_statsService == null) {
                    return const Center(
                      child: Text('Statistics unavailable'),
                    );
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _statsService?.refreshStats(),
                            tooltip: 'Refresh Stats',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Stats cards
                      Row(
                        children: [
                          _buildStatCard(
                            'Total',
                            _statsService?.totalIncidents.value.toString() ?? '0',
                            Icons.assessment,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Synced',
                            _statsService?.syncedIncidents.value.toString() ?? '0',
                            Icons.cloud_done,
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Pending',
                            _statsService?.pendingIncidents.value.toString() ?? '0',
                            Icons.cloud_upload,
                            Colors.orange,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Progress indicator for sync status
                      if (_statsService != null && _statsService!.totalIncidents.value > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Sync Progress'),
                                  Text(
                                    '${((_statsService?.getSyncCompletionRate() ?? 0) * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _statsService?.getSyncCompletionRate() ?? 0,
                                  backgroundColor: Colors.grey.shade200,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
          
          // Titre de la section incidents récents
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent incidents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Get.toNamed('/incident/history'),
                  child: Row(
                    children: [
                      const Text('See all'),
                      const SizedBox(width: 4),
                      Obx(() {
                        final pendingCount = _statsService?.pendingIncidents.value ?? 0;
                        if (pendingCount > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Liste des incidents
          Expanded(
            child: Obx(() {
              if (_incidentController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final incidents = _incidentController.incidents;
              if (incidents.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'No incidents reported yet',
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use the + button to report an incident',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              
              // Limiter à 5 incidents les plus récents
              final recentIncidents = incidents.length > 5 
                  ? incidents.sublist(0, 5) 
                  : incidents;
              
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: recentIncidents.length,
                itemBuilder: (context, index) {
                  final incident = recentIncidents[index];
                  return IncidentCard(
                    incident: incident,
                    onTap: () => Get.toNamed(
                      '/incident/details',
                      arguments: incident,
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/incident/create'),
        icon: const Icon(Icons.add),
        label: const Text('Report Incident'),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
