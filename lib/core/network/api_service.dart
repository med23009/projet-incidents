import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'connectivity_service.dart';

class ApiService extends GetxService {
  // URL de base de l'API
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Pour l'émulateur Android
  // static const String baseUrl = 'http://10.141.223.205:8000/api'; // Adresse IP de l'ordinateur
  // static const String baseUrl = 'http://localhost:8000/api'; // Pour le développement local
  // static const String baseUrl = 'https://votre-api-de-production.com/api'; // Pour la production
  
  // URL du serveur déployé sur PythonAnywhere
  static const String baseUrl = 'https://medou.pythonanywhere.com/api';
  
  final _storage = const FlutterSecureStorage();
  final RxBool isConnected = false.obs;
  
  // Add dependency injection
  final ConnectivityService connectivityService;
  
  // Constructor with required dependency
  ApiService({required this.connectivityService});
  
  // Points d'entrée de l'API
  static const String loginEndpoint = '$baseUrl/users/token/';
  static const String registerEndpoint = '$baseUrl/users/register/';
  static const String userProfileEndpoint = '$baseUrl/users/profile/';
  static const String incidentsEndpoint = '$baseUrl/incidents/';
  static const String tokenRefreshEndpoint = '$baseUrl/users/token/refresh/';
  
  // Async initialization pattern
  Future<ApiService> init() async {
    developer.log('Initializing ApiService with base URL: $baseUrl');
    
    // Subscribe to connectivity changes
    ever(connectivityService.isConnected, (connected) {
      if (connected) {
        developer.log('ApiService: Connectivity restored, checking API status');
        _checkConnection();
        // We'll let SyncService handle the actual sync process
        // and not trigger it from here to avoid double syncing
      } else {
        developer.log('ApiService: Connectivity lost');
        isConnected.value = false;
      }
    });
    
    // Initial connection check
    await _checkConnection();
    
    developer.log('ApiService initialized with connection status: ${isConnected.value}');
    
    // Schedule endpoint checks after initialization
    Future.delayed(const Duration(seconds: 2), () => checkApiEndpoints());
    // Disabled automatic test registration to prevent creating test users
    // Future.delayed(Duration(seconds: 4), () => testRegistrationEndpoint());
    
    return this;
  }
  
  @override
  void onInit() {
    super.onInit();
    // Initialization moved to init() method
  }
  
  Future<void> _checkConnection() async {
    try {
      developer.log('Tentative de connexion à l\'API: $baseUrl/users/');
      
      // Use a more reliable endpoint to test connectivity
      final response = await http.get(Uri.parse('$baseUrl/users/'));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        isConnected.value = true;
        developer.log('API connection successful with status: ${response.statusCode}');
      } else if (response.statusCode == 404) {
        // 404 means the server is reachable but endpoint doesn't exist
        isConnected.value = true;
        developer.log('API connection successful, but endpoint not found (404). Verify your API endpoints.');
      } else {
        // Other error codes
        isConnected.value = true; // Still connected, just not successful response
        developer.log('API connection received error status: ${response.statusCode}');
      }
      
      // Log response body preview
      if (response.body.isNotEmpty) {
      final bodyPreview = response.body.length > 100 
          ? response.body.substring(0, 100) + '...' 
          : response.body;
      developer.log('API response: ${response.statusCode} - $bodyPreview');
      }
    } catch (e) {
      // Handle various error types differently
      if (e is http.ClientException) {
        isConnected.value = false;
        developer.log('API connection failed - Server unreachable: $e');
        developer.log('Vérifiez que: \n1. L\'adresse IP $baseUrl est correcte\n2. Le serveur est bien lancé avec 0.0.0.0:8000\n3. Le téléphone et l\'ordinateur sont sur le même réseau');
      } else {
        // For other errors, still mark as connected since we reached the server
        isConnected.value = true;
        developer.log('API connection error: $e');
      }
    }
    
    developer.log('API connection status: ${isConnected.value}');
  }
  
  // Méthode pour obtenir les en-têtes d'authentification
  Future<Map<String, String>> _getAuthHeaders() async {
    // Always try to get a valid token first
    final token = await ensureValidToken();
    developer.log('Using JWT token: ${token != null ? "Valid token present" : "Token is null"}');
    
    final headers = {
      'Content-Type': 'application/json',
    };
    
    // Only add Authorization header if token exists
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Méthode pour obtenir un token valide
  Future<String?> _getValidToken() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;
      
      // For simplicity, just return the token
      // The ensureValidToken method handles actual token refresh
      return token;
    } catch (e) {
      developer.log('Error getting valid token: $e');
      return null;
    }
  }
  
  // Method to refresh the token if needed
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        developer.log('No refresh token available');
        return false;
      }
      
      developer.log('Attempting to refresh token');
      final response = await http.post(
        Uri.parse(tokenRefreshEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newToken = responseData['access'];
        
        await _storage.write(key: 'jwt_token', value: newToken);
        developer.log('Token refreshed successfully');
        return true;
      } else {
        developer.log('Failed to refresh token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      developer.log('Error refreshing token: $e');
      return false;
    }
  }
  
  // Méthode pour se connecter
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      await _checkConnection();
      if (!isConnected.value) {
        throw Exception('No internet connection');
      }
      
      developer.log('Attempting login with email: $email to endpoint: $loginEndpoint');
      
      final response = await http.post(
        Uri.parse(loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email,
          'password': password,
        }),
      );
      
      developer.log('Login response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        developer.log('Login successful. Token received. User data: ${responseData['user'] ?? 'No user data'}');
        
        // Store the tokens
        await _storage.write(key: 'jwt_token', value: responseData['access']);
        await _storage.write(key: 'refresh_token', value: responseData['refresh']);
        
        return responseData;
      } else {
        developer.log('Login failed with status: ${response.statusCode}, body: ${response.body}');
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      developer.log('API login error: $e');
      throw Exception('Login failed: $e');
    }
  }
  
  // Méthode pour s'inscrire
  Future<Map<String, dynamic>> register(String email, String password, String phone) async {
    try {
      await _checkConnection();
      if (!isConnected.value) {
        throw Exception('No internet connection');
      }
      
      developer.log('Attempting to register user with email: $email to endpoint: $registerEndpoint');
      
      // Include password2 field as Django requires it for confirmation
      final response = await http.post(
        Uri.parse(registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email, // Le backend utilise 'username' comme identifiant principal
          'email': email,
          'password': password,
          'password2': password, // Add password confirmation field
          'phone': phone,
          'role': 'user', // Rôle par défaut
        }),
      );
      
      developer.log('Registration response status code: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        developer.log('Registration successful. Response data: $responseData');
        return responseData;
      } else {
        developer.log('Registration failed with status: ${response.statusCode}, body: ${response.body}');
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      developer.log('API register error: $e');
      throw Exception('Registration failed: $e');
    }
  }
  
  // Méthode pour obtenir le profil utilisateur
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      
      await _checkConnection();
      if (!isConnected.value) {
        throw Exception('No internet connection');
      }
      
      developer.log('Fetching user profile from endpoint: $userProfileEndpoint');
      
      final response = await http.get(
        Uri.parse(userProfileEndpoint),
        headers: await _getAuthHeaders(),
      );
      
      developer.log('Get user profile response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final dynamic userData = jsonDecode(response.body);
        developer.log('User profile fetched successfully: $userData');
        
        // Handle both list and map response formats
        if (userData is List && userData.isNotEmpty) {
          return userData[0] as Map<String, dynamic>;
        } else if (userData is Map<String, dynamic>) {
          return userData;
        } else {
          throw Exception('Unexpected user profile format');
        }
      } else {
        developer.log('Failed to get user profile with status: ${response.statusCode}, body: ${response.body}');
        throw Exception('Failed to get user profile: ${response.body}');
      }
    } catch (e) {
      developer.log('API get user profile error: $e');
      throw Exception('Failed to get user profile: $e');
    }
  }
  
  // Méthode pour envoyer un incident
  Future<Map<String, dynamic>> createIncident(Map<String, dynamic> incidentData) async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      
      await _checkConnection();
      if (!isConnected.value) {
        throw Exception('No internet connection');
      }
      
      // Pour l'envoi de fichiers, il faudrait utiliser multipart/form-data
      // Mais pour simplifier, nous utiliserons juste application/json
      final response = await http.post(
        Uri.parse(incidentsEndpoint),
        headers: await _getAuthHeaders(),
        body: jsonEncode(incidentData),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create incident: ${response.body}');
      }
    } catch (e) {
      developer.log('API create incident error: $e');
      throw Exception('Failed to create incident: $e');
    }
  }
  
  // Méthode pour obtenir les incidents d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserIncidents() async {
    try {
      // Try to refresh token first to ensure it's valid
      final token = await ensureValidToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }
      
      await _checkConnection();
      if (!isConnected.value) {
        throw Exception('No internet connection');
      }
      
      final response = await http.get(
        Uri.parse(incidentsEndpoint),
        headers: await _getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get user incidents: ${response.body}');
      }
    } catch (e) {
      developer.log('API get user incidents error: $e');
      throw Exception('Failed to get user incidents: $e');
    }
  }
  
  // Méthode pour synchroniser un incident
  Future<Map<String, dynamic>> syncIncident(Map<String, dynamic> incidentData) async {
    try {
      // Always ensure we have a valid token before making the request
      final token = await ensureValidToken();
      if (token == null) {
        developer.log('Sync failed: Not authenticated (token is null)');
        throw Exception('Not authenticated');
      }
      
      await _checkConnection();
      if (!isConnected.value) {
        developer.log('Sync failed: No internet connection');
        throw Exception('No internet connection');
      }
      
      // Get the authentication headers with the valid token
      final headers = await _getAuthHeaders();
      
      developer.log('Attempting to sync incident to: ${incidentsEndpoint}');
      developer.log('Sync with headers: $headers');
      
      // Vérifier si nous avons des fichiers à envoyer
      final hasPhotoFile = incidentData['photo_path'] != null;
      final hasAudioFile = incidentData['voice_note_path'] != null;
      
      if (hasPhotoFile || hasAudioFile) {
        // Utiliser multipart/form-data pour envoyer des fichiers
        developer.log('Sending incident with files using multipart/form-data');
        
        // Créer un objet Uri pour l'endpoint
        final uri = Uri.parse(incidentsEndpoint);
        
        // Créer une requête multipart
        final request = http.MultipartRequest('POST', uri);
        
        // Ajouter les headers d'authentification
        request.headers.addAll(headers);
        
        // Ajouter tous les champs de texte
        incidentData.forEach((key, value) {
          if (value != null && key != 'photo_path' && key != 'voice_note_path') {
            if (value is String || value is num || value is bool) {
              request.fields[key] = value.toString();
            } else {
              // Pour les objets complexes, les convertir en JSON
              request.fields[key] = jsonEncode(value);
            }
          }
        });
        
        // Ajouter le fichier photo s'il existe
        if (hasPhotoFile) {
          final photoPath = incidentData['photo_path'];
          developer.log('Adding photo file: $photoPath');
          try {
            final photoFile = await http.MultipartFile.fromPath(
              'photo',
              photoPath,
              filename: photoPath.split('/').last
            );
            request.files.add(photoFile);
          } catch (e) {
            developer.log('Error adding photo file: $e');
          }
        }
        
        // Ajouter le fichier audio s'il existe
        if (hasAudioFile) {
          final audioPath = incidentData['voice_note_path'];
          developer.log('Adding audio file: $audioPath');
          try {
            final audioFile = await http.MultipartFile.fromPath(
              'voice_note',
              audioPath,
              filename: audioPath.split('/').last
            );
            request.files.add(audioFile);
          } catch (e) {
            developer.log('Error adding audio file: $e');
          }
        }
        
        // Envoyer la requête
        developer.log('Sending multipart request...');
        final streamedResponse = await request.send();
        
        // Convertir la réponse en http.Response
        final response = await http.Response.fromStream(streamedResponse);
        
        developer.log('Sync response status: ${response.statusCode}');
        developer.log('Sync response body: ${response.body}');
        
        if (response.statusCode == 201) {
          developer.log('Incident successfully synced to server');
          return jsonDecode(response.body);
        } else {
          developer.log('Sync failed with status: ${response.statusCode}, body: ${response.body}');
          throw Exception('Failed to sync incident: ${response.body}');
        }
      } else {
        // Pas de fichiers à envoyer, utiliser application/json
        developer.log('Sending incident without files using application/json');
        developer.log('With data: ${jsonEncode(incidentData)}');
        
        final response = await http.post(
          Uri.parse(incidentsEndpoint),
          headers: headers,
          body: jsonEncode(incidentData),
        );
        
        developer.log('Sync response status: ${response.statusCode}');
        developer.log('Sync response body: ${response.body}');
        
        if (response.statusCode == 201) {
          developer.log('Incident successfully synced to server');
          return jsonDecode(response.body);
        } else {
          developer.log('Sync failed with status: ${response.statusCode}, body: ${response.body}');
          throw Exception('Failed to sync incident: ${response.body}');
        }
      }
    } catch (e) {
      developer.log('API sync incident error: $e');
      throw Exception('Failed to sync incident: $e');
    }
  }
  
  // Retrieve the stored JWT token
  Future<String?> getStoredToken() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        developer.log('Retrieved stored token (first 10 chars): ${token.substring(0, min(10, token.length))}...');
      } else {
        developer.log('No token found in secure storage');
      }
      return token;
    } catch (e) {
      developer.log('Error retrieving stored token', error: e);
      return null;
    }
  }
  
  // Add this method to check what API endpoints are available
  Future<void> checkApiEndpoints() async {
    developer.log('-------- CHECKING API ENDPOINTS --------');
    
    // List of endpoints to check
    final endpoints = [
      '$baseUrl/',
      '$baseUrl/users/',
      '$baseUrl/users/register/',
      '$baseUrl/users/token/', 
      '$baseUrl/users/profile/',
      '$baseUrl/incidents/',
    ];
    
    for (final endpoint in endpoints) {
      try {
        developer.log('Testing endpoint: $endpoint');
        final response = await http.get(Uri.parse(endpoint));
        
        developer.log('Endpoint $endpoint - Status: ${response.statusCode}');
        
        // Check if response contains useful error information
        if (response.statusCode >= 400 && response.body.isNotEmpty) {
          final preview = response.body.length > 100 
              ? response.body.substring(0, 100) + '...' 
              : response.body;
          developer.log('Response preview: $preview');
        }
      } catch (e) {
        developer.log('Error testing endpoint $endpoint: $e');
      }
    }
    
    developer.log('-------- API ENDPOINT CHECK COMPLETE --------');
  }
  
  // Test registration endpoint with proper fields - DISABLED BY DEFAULT
  // Only call this method manually for testing purposes
  Future<void> testRegistrationEndpoint() async {
    developer.log('-------- TESTING REGISTRATION ENDPOINT --------');
    developer.log('WARNING: This test creates a new user in the database!');
    
    try {
      developer.log('Testing registration endpoint: $registerEndpoint');
      
      // Create a test payload with all required fields
      final testPayload = {
        'username': 'testuser_${DateTime.now().millisecondsSinceEpoch}',
        'email': 'test_${DateTime.now().millisecondsSinceEpoch}@example.com',
        'password': 'Test@12345',
        'password2': 'Test@12345', // Include confirmation password
        'phone': '1234567890',
        'role': 'user'
      };
      
      developer.log('Test registration payload: $testPayload');
      
      // Make the request
      final response = await http.post(
        Uri.parse(registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testPayload)
      );
      
      developer.log('Registration test response status: ${response.statusCode}');
      
      // Log detailed response information
      if (response.body.isNotEmpty) {
        final preview = response.body.length > 500 
            ? response.body.substring(0, 500) + '...' 
            : response.body;
        developer.log('Response body: $preview');
        
        // Try to parse the response as JSON
        try {
          final jsonResponse = jsonDecode(response.body);
          developer.log('JSON response fields: ${jsonResponse.keys.join(', ')}');
        } catch (e) {
          developer.log('Response is not valid JSON: $e');
        }
      }
      
      if (response.statusCode == 201) {
        developer.log('Registration endpoint test succeeded!');
      } else if (response.statusCode == 404) {
        developer.log('CRITICAL ERROR: Registration endpoint not found (404)');
        developer.log('Verify that the endpoint URL is correct: $registerEndpoint');
      } else if (response.statusCode == 400) {
        developer.log('Registration request validation failed (400)');
        developer.log('Check that all required fields are included and valid');
      } else {
        developer.log('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error testing registration endpoint', error: e);
    }
    
    developer.log('-------- REGISTRATION ENDPOINT TEST COMPLETE --------');
  }
  
  // Method to check and ensure valid token
  Future<String?> ensureValidToken() async {
    try {
      developer.log('-------- CHECKING TOKEN VALIDITY --------');
      final token = await _storage.read(key: 'jwt_token');
      developer.log('Retrieved token from storage');
      if (token == null) {
        developer.log('No token found in secure storage');
        return null;
      }
      
      developer.log('Token found in secure storage: ${token.substring(0, min(10, token.length))}...');
      
      // Check if token is "local_auth" (offline mode)
      if (token.startsWith('local_auth')) {
        developer.log('Using local auth token, cannot refresh');
        return token;
      }
      
      // Make a request to test the token
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/users/profile/'),
          headers: {'Authorization': 'Bearer $token'},
        );
        
        if (response.statusCode == 200) {
          developer.log('Token is valid!');
          developer.log('-------- TOKEN CHECK COMPLETE --------');
          return token;
        } else if (response.statusCode == 401) {
          developer.log('Token is expired or invalid, attempting to refresh');
          
          // Try to refresh the token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Get the new token
            final newToken = await _storage.read(key: 'jwt_token');
            developer.log('Token refreshed successfully');
            developer.log('-------- TOKEN CHECK COMPLETE --------');
            return newToken;
          } else {
            developer.log('Failed to refresh token');
            developer.log('-------- TOKEN CHECK FAILED --------');
            return null;
          }
        } else {
          developer.log('Unexpected status code when checking token: ${response.statusCode}');
          developer.log('-------- TOKEN CHECK COMPLETE WITH WARNING --------');
          return token; // Return the token anyway, might work for other endpoints
        }
      } catch (e) {
        developer.log('Error checking token validity', error: e);
        developer.log('-------- TOKEN CHECK ERROR --------');
        return token; // Return the token anyway in case of network error
      }
    } catch (e) {
      developer.log('Error in ensureValidToken', error: e);
      developer.log('-------- TOKEN CHECK FAILED --------');
      return null;
    }
  }
}