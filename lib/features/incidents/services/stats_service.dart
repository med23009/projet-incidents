import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/network/api_service.dart';
import '../controllers/incident_controller.dart';
import '../../../features/auth/controllers/auth_controller.dart';

class StatsService extends GetxService {
  final _db = DatabaseHelper.instance;
  final ApiService _apiService = Get.find<ApiService>();
  late final AuthController _authController;
  Worker? _incidentsWorker;
  Timer? _autoRefreshTimer;
  
  // Observable statistics
  final RxInt totalIncidents = 0.obs;
  final RxInt syncedIncidents = 0.obs;
  final RxInt pendingIncidents = 0.obs;
  final RxMap<String, int> incidentsByType = <String, int>{}.obs;
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> recentIncidents = <Map<String, dynamic>>[].obs;
  
  // Status-related statistics (from admin actions)
  final RxInt resolvedIncidents = 0.obs;
  final RxInt pendingStatusIncidents = 0.obs;
  final RxInt inProgressIncidents = 0.obs;
  final RxDouble resolutionRate = 0.0.obs;
  
  // Remote statistics
  final RxBool isRemoteLoading = false.obs;
  final RxBool isRemoteStatsAvailable = false.obs;
  final Rx<Map<String, dynamic>> remoteStats = Rx<Map<String, dynamic>>({});
  
  // User dashboard statistics
  final RxBool isUserStatsLoading = false.obs;
  final RxBool isUserStatsAvailable = false.obs;
  final Rx<Map<String, dynamic>> userDashboardStats = Rx<Map<String, dynamic>>({});
  final RxMap<String, int> incidentsByDay = <String, int>{}.obs;
  final RxList<Map<String, dynamic>> monthlyTrend = <Map<String, dynamic>>[].obs;
  
  // Timestamp of last refresh
  DateTime? _lastRemoteRefresh;
  DateTime? _lastUserStatsRefresh;

  // Implement async initialization
  Future<StatsService> init() async {
    developer.log('Initializing StatsService');
    
    // Get auth controller
    try {
      _authController = Get.find<AuthController>();
    } catch (e) {
      developer.log('AuthController not found, will be initialized later: $e');
    }
    
    // Set up worker to listen for changes in incidents
    _setupIncidentsWorker();
    
    // Set up auto-refresh timer
    _setupAutoRefresh();
    
    // Initial refresh
    await refreshStats();
    
    if (_apiService.isConnected.value) {
      fetchRemoteStats();
      fetchUserDashboardStats();
    }
    
    developer.log('StatsService initialized');
    return this;
  }
  
  void _setupIncidentsWorker() {
    try {
      if (Get.isRegistered<IncidentController>()) {
        _incidentsWorker = ever(Get.find<IncidentController>().incidents, (_) {
          refreshStats();
        });
      }
    } catch (e) {
      developer.log('Error setting up incidents worker: $e');
    }
  }
  
  void _setupAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_apiService.isConnected.value) {
        fetchRemoteStats();
        fetchUserDashboardStats();
      }
    });
  }
  
  @override
  void onClose() {
    _incidentsWorker?.dispose();
    _autoRefreshTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshStats() async {
    try {
      isLoading.value = true;
      developer.log('Refreshing incident statistics');
      
      // Get user ID from auth controller
      int userId;
      try {
        // Try to get the user ID from the auth controller
        if (Get.isRegistered<AuthController>()) {
          _authController = Get.find<AuthController>();
          final userData = _authController.userData.value;
          userId = userData?['id'] ?? 0;
          developer.log('Got user ID from auth controller: $userId');
        } else {
          userId = 0;
          developer.log('AuthController not registered yet');
        }
      } catch (e) {
        userId = 0;
        developer.log('Error getting user ID: $e');
      }
      
      // If we couldn't get a valid user ID, try to get it from secure storage
      if (userId == 0) {
        try {
          // Try to get user ID from secure storage
          final storage = const FlutterSecureStorage();
          final userIdStr = await storage.read(key: 'user_id');
          if (userIdStr != null && userIdStr.isNotEmpty) {
            userId = int.tryParse(userIdStr) ?? 0;
            developer.log('Got user ID from secure storage: $userId');
          }
        } catch (e) {
          developer.log('Error getting user ID from secure storage: $e');
        }
      }
      
      // Get all incidents for user
      final incidents = await _db.getIncidentsByUserId(userId);
      
      // Create a map to track unique incident IDs to prevent duplicates in statistics
      final Map<int, Map<String, dynamic>> uniqueIncidentsMap = {};
      
      // First pass: collect all incidents by ID
      for (var incident in incidents) {
        final int incidentId = incident['id'] as int;
        final String syncStatus = incident['sync_status'] as String;
        
        // If this ID is already in our map, only replace it if this one is newer or has sync_status = 'synced'
        if (uniqueIncidentsMap.containsKey(incidentId)) {
          final existingIncident = uniqueIncidentsMap[incidentId]!;
          final existingSyncStatus = existingIncident['sync_status'];
          
          // Prefer synced incidents over pending ones
          if (existingSyncStatus == 'pending' && syncStatus == 'synced') {
            uniqueIncidentsMap[incidentId] = incident;
          }
        } else {
          // This is the first time we're seeing this ID
          uniqueIncidentsMap[incidentId] = incident;
        }
      }
      
      // Use the unique incidents for statistics
      final uniqueIncidents = uniqueIncidentsMap.values.toList();
      totalIncidents.value = uniqueIncidents.length;
      
      // Count synced vs pending incidents
      syncedIncidents.value = uniqueIncidents.where((inc) => inc['sync_status'] == 'synced').length;
      pendingIncidents.value = uniqueIncidents.where((inc) => inc['sync_status'] == 'pending').length;
      
      developer.log('Statistics refreshed: Total: ${totalIncidents.value}, Synced: ${syncedIncidents.value}, Pending: ${pendingIncidents.value}');
      
      // Count incidents by status (admin-set status)
      resolvedIncidents.value = incidents.where((inc) => inc['status'] == 'resolved').length;
      pendingStatusIncidents.value = incidents.where((inc) => inc['status'] == 'pending').length;
      inProgressIncidents.value = incidents.where((inc) => inc['status'] == 'in_progress').length;
      
      // Calculate resolution rate
      resolutionRate.value = totalIncidents.value > 0 ? resolvedIncidents.value / totalIncidents.value : 0.0;
      
      // Count incidents by type
      final typeMap = <String, int>{};
      for (var incident in incidents) {
        final type = incident['incident_type'] as String;
        typeMap[type] = (typeMap[type] ?? 0) + 1;
      }
      incidentsByType.value = typeMap;
      
      // Get recent incidents
      final cutoffDate = DateTime.now().subtract(Duration(days: 7));
      final recentList = incidents.where((inc) {
        final createdAt = DateTime.parse(inc['created_at'] as String);
        return createdAt.isAfter(cutoffDate);
      }).toList();
      
      // Update recent incidents list
      recentIncidents.value = recentList.map((inc) => Map<String, dynamic>.from(inc)).toList();
      
      developer.log('Statistics refreshed: Total: ${totalIncidents.value}, '
          'Synced: ${syncedIncidents.value}, Pending: ${pendingIncidents.value}');
    } catch (e, stackTrace) {
      developer.log('Error refreshing statistics', error: e, stackTrace: stackTrace);
    } finally {
      isLoading.value = false;
    }
  }
  
  // Get incidents created in the last N days
  Future<int> getRecentIncidentsCount(int days) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final incidents = await _db.getIncidentsByUserId(1); // Use proper user ID
      
      return incidents.where((inc) {
        final createdAt = DateTime.parse(inc['created_at'] as String);
        return createdAt.isAfter(cutoffDate);
      }).length;
    } catch (e) {
      developer.log('Error getting recent incidents count', error: e);
      return 0;
    }
  }
  
  // Get completion rate (percentage of incidents that are synced)
  double getSyncCompletionRate() {
    if (totalIncidents.value == 0) return 0.0;
    return syncedIncidents.value / totalIncidents.value;
  }
  
  // Fetch statistics from the remote API endpoint
  Future<void> fetchRemoteStats() async {
    // Skip if we're already loading or if there's no network connection
    if (isRemoteLoading.value || !_apiService.isConnected.value) {
      if (!_apiService.isConnected.value) {
        developer.log('Skipping remote stats fetch: No network connection');
        isRemoteStatsAvailable.value = false;
      }
      return;
    }
    
    // Skip if we've refreshed recently (within last 5 minutes) unless forced
    if (!shouldRefreshRemoteStats()) {
      developer.log('Skipping remote stats fetch: Refreshed recently');
      return;
    }
    
    try {
      isRemoteLoading.value = true;
      developer.log('Fetching remote incident statistics from API');
      
      // Check if we're connected to the network
      if (!_apiService.isConnected.value) {
        developer.log('Cannot fetch remote stats: No network connection');
        isRemoteStatsAvailable.value = false;
        return;
      }
      
      // Make API request to the incidents statistics endpoint
      try {
        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/incidents/stats'),
          headers: {'Content-Type': 'application/json'},
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
        remoteStats.value = data;
        isRemoteStatsAvailable.value = true;
        
        // Update refresh timestamp
        _lastRemoteRefresh = DateTime.now();
        
        developer.log('Remote statistics fetched successfully');
        } else {
          developer.log('Failed to fetch remote statistics: ${response.statusCode}');
          isRemoteStatsAvailable.value = false;
        }
      } catch (e) {
        developer.log('Error making API request: $e');
        isRemoteStatsAvailable.value = false;
      }
    } catch (e) {
      developer.log('Error fetching remote statistics', error: e);
      isRemoteStatsAvailable.value = false;
    } finally {
      isRemoteLoading.value = false;
    }
  }
  
  // Fetch user-focused dashboard statistics from the API endpoint
  Future<void> fetchUserDashboardStats() async {
    // Skip if we're already loading or if there's no network connection
    if (isUserStatsLoading.value || !_apiService.isConnected.value) {
      if (!_apiService.isConnected.value) {
        developer.log('Skipping user dashboard stats fetch: No network connection');
        isUserStatsAvailable.value = false;
      }
      return;
    }
    
    // Skip if we've refreshed recently (within last 5 minutes)
    if (!shouldRefreshUserStats()) {
      developer.log('Skipping user dashboard stats fetch: Refreshed recently');
      return;
    }
    
    try {
      isUserStatsLoading.value = true;
      developer.log('Fetching user dashboard statistics from API');
      
      // Check if we're connected to the network
      if (!_apiService.isConnected.value) {
        developer.log('Cannot fetch user stats: No network connection');
        isUserStatsAvailable.value = false;
        return;
      }
      
      // Make API request to the user dashboard statistics endpoint
      try {
        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/incidents/user-dashboard'),
          headers: {'Content-Type': 'application/json'},
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
        userDashboardStats.value = data;
        isUserStatsAvailable.value = true;
        
        // Extract key metrics
        final statusSummary = data['status_summary'] ?? {};
        resolvedIncidents.value = statusSummary['resolved'] ?? 0;
        pendingStatusIncidents.value = statusSummary['pending'] ?? 0;
        inProgressIncidents.value = statusSummary['in_progress'] ?? 0;
        resolutionRate.value = statusSummary['resolution_rate'] ?? 0.0;
        
        // Extract daily activity
        final recentActivity = data['recent_activity'] ?? {};
        final byDayOfWeek = recentActivity['by_day_of_week'] ?? {};
        incidentsByDay.value = Map<String, int>.from(byDayOfWeek);
        
        // Extract monthly trend
        final trend = data['monthly_trend'] ?? [];
        monthlyTrend.value = List<Map<String, dynamic>>.from(trend);
        
        // Update refresh timestamp
        _lastUserStatsRefresh = DateTime.now();
        
        developer.log('User dashboard statistics fetched successfully');
        } else {
          developer.log('Failed to fetch user dashboard statistics: ${response.statusCode}');
          isUserStatsAvailable.value = false;
        }
      } catch (e) {
        developer.log('Error making API request: $e');
        isUserStatsAvailable.value = false;
      }
    } catch (e) {
      developer.log('Error fetching user dashboard statistics', error: e);
      isUserStatsAvailable.value = false;
    } finally {
      isUserStatsLoading.value = false;
    }
  }
  
  // Refresh all statistics (local, remote, and user dashboard)
  Future<void> refreshAllStats() async {
    await refreshStats();
    await fetchRemoteStats();
    await fetchUserDashboardStats();
  }
  
  // Force refresh of user dashboard statistics
  Future<void> refreshUserDashboardStats() async {
    _lastUserStatsRefresh = null; // Force refresh
    await fetchUserDashboardStats();
  }
  
  // Check if we need to refresh remote stats based on time elapsed
  bool shouldRefreshRemoteStats() {
    // If never refreshed, we should refresh
    if (_lastRemoteRefresh == null) return true;
    
    // If more than 5 minutes have passed since last refresh, we should refresh
    final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
    return _lastRemoteRefresh!.isBefore(fiveMinutesAgo);
  }
  
  // Check if user stats need refreshing
  bool shouldRefreshUserStats() {
    if (_lastUserStatsRefresh == null) return true;
    
    final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
    return _lastUserStatsRefresh!.isBefore(fiveMinutesAgo);
  }
  
  // Get a specific value from user dashboard stats
  dynamic getUserStatValue(String key) {
    if (!isUserStatsAvailable.value) return null;
    
    final parts = key.split('.');
    dynamic current = userDashboardStats.value;
    
    for (final part in parts) {
      if (current is! Map) return null;
      if (!current.containsKey(part)) return null;
      current = current[part];
    }
    
    return current;
  }
  
  // Get time of last user dashboard refresh
  String getLastUserStatsRefreshTime() {
    if (_lastUserStatsRefresh == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(_lastUserStatsRefresh!);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
  
  // Get user activity by day of week
  Map<String, int> getUserActivityByDayOfWeek() {
    if (!isUserStatsAvailable.value) return {};
    return Map<String, int>.from(userDashboardStats.value['recent_activity']?['by_day_of_week'] ?? {});
  }
  
  // Get user activity by hour of day
  Map<String, int> getUserActivityByHourOfDay() {
    if (!isUserStatsAvailable.value) return {};
    return Map<String, int>.from(userDashboardStats.value['recent_activity']?['by_hour_of_day'] ?? {});
  }
}