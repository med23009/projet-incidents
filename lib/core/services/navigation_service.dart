import 'package:get/get.dart';
import 'dart:developer' as developer;

/// A centralized service for handling app navigation
class NavigationService extends GetxService {
  // Track current route for analytics or state management
  final RxString currentRoute = ''.obs;
  final RxList<String> navigationHistory = <String>[].obs;

  // Add async initialization pattern
  Future<NavigationService> init() async {
    developer.log('Initializing NavigationService');
    
    // Initialize with the current route
    currentRoute.value = Get.currentRoute;
    navigationHistory.add(currentRoute.value);
    
    // Listen for route changes
    ever(currentRoute, (route) {
      developer.log('Route changed to: $route');
      if (navigationHistory.isEmpty || navigationHistory.last != route) {
        navigationHistory.add(route);
        if (navigationHistory.length > 10) {
          navigationHistory.removeAt(0);
        }
      }
    });
    
    developer.log('NavigationService initialized with current route: ${currentRoute.value}');
    return this;
  }

  @override
  void onInit() {
    super.onInit();
    // Initialization moved to init() method
  }

  /// Navigate to a named route
  void navigateTo(String routeName, {dynamic arguments}) {
    developer.log('Navigating to: $routeName');
    Get.toNamed(routeName, arguments: arguments);
    currentRoute.value = routeName;
  }

  /// Navigate to a named route and remove all previous routes
  void navigateToAndRemoveUntil(String routeName, {dynamic arguments}) {
    developer.log('Navigating to $routeName and removing all previous routes');
    Get.offAllNamed(routeName, arguments: arguments);
    currentRoute.value = routeName;
    navigationHistory.clear();
    navigationHistory.add(routeName);
  }

  /// Navigate back to the previous screen
  void goBack() {
    if (Get.previousRoute.isNotEmpty) {
      developer.log('Going back to previous route: ${Get.previousRoute}');
      Get.back();
      currentRoute.value = Get.currentRoute;
    } else {
      developer.log('Cannot go back - no previous route');
    }
  }

  /// Navigate to the Home screen clearing all routes
  void goToHome() {
    developer.log('Going to home');
    Get.offAllNamed('/home');
    currentRoute.value = '/home';
    navigationHistory.clear();
    navigationHistory.add('/home');
  }

  /// Navigate to the Login screen clearing all routes
  void goToLogin() {
    navigateToAndRemoveUntil('/login');
  }
} 