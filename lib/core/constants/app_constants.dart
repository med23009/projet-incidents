/// Application-wide constants
class AppConstants {
  // API URLs
  static const String baseUrl = 'http://localhost:8000/api';
  static const String incidentsEndpoint = '$baseUrl/incidents/';
  static const String authEndpoint = '$baseUrl/auth/';
  static const String userEndpoint = '$baseUrl/users/';
  
  // Local Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String settingsKey = 'app_settings';
  
  // Default values
  static const int defaultPageSize = 10;
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // Feature flags
  static const bool enableOfflineMode = true;
  static const bool enableMediaUpload = true;
  static const bool enableLocationTracking = true;
}
