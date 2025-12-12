import 'package:get/get.dart';
import 'dart:developer' as developer;

import 'local_storage_service.dart';
import '../network/api_service.dart';
import '../network/connectivity_service.dart';
import '../../features/incidents/services/stats_service.dart';

class DependencyInjection {
  static Future<void> init() async {
    developer.log('Initializing dependencies');
    
    // Initialize LocalStorageService
    await Get.putAsync<LocalStorageService>(() async {
      final service = LocalStorageService();
      return await service.init();
    });
    
    // Initialize ConnectivityService first
    await Get.putAsync<ConnectivityService>(() async {
      final service = ConnectivityService();
      return await service.init();
    });
    
    // Initialize ApiService with ConnectivityService dependency
    await Get.putAsync<ApiService>(() async {
      final connectivityService = Get.find<ConnectivityService>();
      final service = ApiService(connectivityService: connectivityService);
      return await service.init();
    });
    
    // Initialize StatsService
    await Get.putAsync<StatsService>(() async {
      final service = StatsService();
      return service.init();
    });
    
    developer.log('All dependencies initialized');
  }
} 