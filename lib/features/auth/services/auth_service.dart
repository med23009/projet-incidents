import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;
import '../../../core/database/database_helper.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../controllers/auth_controller.dart';
import '../../../core/network/api_service.dart';

class AuthService extends GetxController {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  final _db = DatabaseHelper.instance;
  
  final RxBool isAuthenticated = false.obs;
  final RxString userRole = ''.obs;
  final RxBool isBiometricAvailable = false.obs;
  final RxBool isBiometricEnabled = false.obs;
  final RxString userEmail = ''.obs;
  final RxBool isLoggedIn = false.obs;
  final Rx<int?> currentUserId = Rx<int?>(null);

  // API Service
  final ApiService apiService;

  // Constructor with required dependency
  AuthService({required this.apiService});

  // Add async initialization pattern
  Future<AuthService> init() async {
    developer.log('Initializing AuthService');
    await _initializeAuth();
    await checkLoginStatus();
    developer.log('AuthService initialized successfully');
    return this;
  }

  // Liste d'utilisateurs valides pour démonstration
  final List<Map<String, dynamic>> _validUsers = [
    {
      'id': 1,
      'email': 'user@example.com',
      'password': 'password123',
      'role': 'user',
    },
    {
      'id': 2,
      'email': 'admin@example.com',
      'password': 'admin123',
      'role': 'admin',
    },
  ];

  @override
  void onInit() {
    super.onInit();
    _initializeAuth();
    checkLoginStatus();
  }

  Future<void> _initializeAuth() async {
    try {
      developer.log('Initializing authentication service');
      
      // Check biometric availability with more detailed logging
      try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        
        isBiometricAvailable.value = canCheckBiometrics && isDeviceSupported && availableBiometrics.isNotEmpty;
        
        // Vérifier si la biométrie est activée pour un compte
        final biometricEnabled = await _storage.read(key: 'biometric_enabled');
        isBiometricEnabled.value = biometricEnabled == 'true';
        
        developer.log('Biometric availability details:');
        developer.log('- Can check biometrics: $canCheckBiometrics');
        developer.log('- Device supported: $isDeviceSupported');
        developer.log('- Available biometrics: $availableBiometrics');
        developer.log('- Biometric enabled for account: ${isBiometricEnabled.value}');
        developer.log('- Final availability status: ${isBiometricAvailable.value}');
      } catch (e) {
        developer.log('Error checking biometrics during initialization', error: e);
        isBiometricAvailable.value = false;
      }

      // Check if biometric login is enabled
      final email = await _storage.read(key: 'user_email');
      if (email != null) {
        userEmail.value = email;
        developer.log('Email found for biometric login: $email');
      }

      // Check existing authentication
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        try {
          if (!JwtDecoder.isExpired(token)) {
            isAuthenticated.value = true;
            final decodedToken = JwtDecoder.decode(token);
            userRole.value = decodedToken['role'] ?? '';
            developer.log('User authenticated with role: ${userRole.value}');
          } else {
            // Token est expiré, on le supprime
            await _storage.delete(key: 'jwt_token');
            developer.log('Expired token removed');
          }
        } catch (e) {
          // Token est invalide, on le supprime
          await _storage.delete(key: 'jwt_token');
          developer.log('Invalid token removed', error: e);
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error initializing auth', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> checkLoginStatus() async {
    try {
      final userIdStr = await _storage.read(key: 'user_id');
      if (userIdStr != null) {
        final userId = int.parse(userIdStr);
        currentUserId.value = userId;
        isLoggedIn.value = true;
      }
    } catch (e) {
      developer.log('Error checking login status', error: e);
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      developer.log('-------- STARTING LOGIN PROCESS --------');
      developer.log('Attempting login for user: $email');
      
      // Track if we authenticated locally
      bool localAuthSuccess = false;
      
      // Try local login first for offline support
      developer.log('Checking local database first');
      final user = await _db.getUserByEmail(email);
      if (user != null && user['password'] == password) {
        developer.log('Local password verification successful for: ${user['email']}');
        
        // Store basic user info for offline use
        await _storage.write(key: 'user_id', value: user['id'].toString());
        await _storage.write(key: 'user_email', value: email);
        userEmail.value = email;
        currentUserId.value = user['id'];
        isLoggedIn.value = true;
        
        // Mark that we succeeded locally
        localAuthSuccess = true;
        developer.log('Local login successful for user ID: ${user['id']}');
      } else if (user != null) {
        developer.log('Local password verification failed');
      } else {
        developer.log('User not found in local database');
      }
      
      // Always attempt API login when possible to ensure we have a valid token
      try {
        developer.log('Getting API service for login');
        final apiService = Get.find<ApiService>();
        
        developer.log('Attempting API login to backend');
        // Call the API service's login method
        final loginResult = await apiService.login(email, password);
        
        developer.log('API login successful with data: $loginResult');
        
        // Save authentication tokens
        if (loginResult['access'] != null) {
          final token = loginResult['access'];
          await _storage.write(key: 'jwt_token', value: token);
          developer.log('Access token saved to secure storage: ${token.substring(0, math.min<int>(10, token.length))}...');
          
          // Verify token was stored
          final storedToken = await _storage.read(key: 'jwt_token');
          if (storedToken != null) {
            developer.log('Token successfully stored in secure storage');
          } else {
            developer.log('ERROR: Token was not properly stored!');
          }
        } else {
          developer.log('WARNING: No access token found in login response!');
        }
        
        if (loginResult['refresh'] != null) {
          await _storage.write(key: 'refresh_token', value: loginResult['refresh']);
          developer.log('Refresh token saved to secure storage');
        }
        
        // Get the user profile to ensure we have current data
        developer.log('Fetching user profile from backend');
        final userData = await apiService.getUserProfile();
        
        developer.log('User profile fetched: $userData');
        
        // Store user ID from API
        final userId = userData['id'].toString();
        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'user_email', value: email);
        userEmail.value = email;
        currentUserId.value = int.parse(userId);
        isLoggedIn.value = true;
        
        developer.log('User data saved to secure storage, userId: $userId');
        
        // Update local database if needed
        final existingUser = await _db.getUserByEmail(email);
        if (existingUser == null) {
          // User doesn't exist locally, create entry
          developer.log('Creating local database entry for user');
          await _db.insertUser({
            'id': int.parse(userId),
            'email': email,
            'password': password, // Note: storing password plaintext is not secure
            'role': userData['role'] ?? 'user',
            'token': await _storage.read(key: 'jwt_token') ?? '',
            'last_login': DateTime.now().toIso8601String(),
          });
          developer.log('User saved to local database');
        } else {
          developer.log('User already exists in local database');
        }
        
        developer.log('Login successful');
        developer.log('-------- LOGIN PROCESS COMPLETED --------');
        return true;
                  } catch (apiError) {
        developer.log('API login failed: $apiError');
        // If we already authenticated locally, we can still return success
        if (localAuthSuccess) {
          developer.log('Using local authentication as fallback');
          developer.log('-------- LOGIN PROCESS COMPLETED WITH LOCAL AUTH ONLY --------');
          // Generate a temporary local token for offline use
          final tempToken = 'local_auth_token_${DateTime.now().millisecondsSinceEpoch}';
          await _storage.write(key: 'jwt_token', value: tempToken);
          developer.log('Temporary local token stored for offline use');
          return true;
        }
      }
      
      // Return based on local auth if API failed but local succeeded
      if (localAuthSuccess) {
        return true;
      }
      
      developer.log('Login failed: invalid credentials or user not found');
      developer.log('-------- LOGIN PROCESS COMPLETED --------');
      return false;
    } catch (e) {
      developer.log('Error during login', error: e);
      developer.log('-------- LOGIN PROCESS COMPLETED WITH ERROR --------');
      return false;
    }
  }

  Future<bool> register(String email, String password, String phone) async {
    try {
      developer.log('-------- STARTING REGISTRATION PROCESS --------');
      developer.log('Attempting to register user: $email');
      
      // First, check if we can register with the API
      developer.log('Getting API service for registration');
      final apiService = Get.find<ApiService>();
      
      try {
        // Call the API registration endpoint
        developer.log('Attempting to register user via backend API');
        final response = await apiService.register(email, password, phone);
        
        developer.log('User registered successfully via API with response: $response');
        
        // Save the tokens
        if (response['access'] != null) {
          await _storage.write(key: 'jwt_token', value: response['access']);
          developer.log('Access token saved to secure storage');
        } else {
          developer.log('Warning: No access token in registration response');
        }
        
        if (response['refresh'] != null) {
          await _storage.write(key: 'refresh_token', value: response['refresh']);
          developer.log('Refresh token saved to secure storage');
        }
        
        // Save user info
        if (response['user'] != null) {
          developer.log('Saving user data from registration response: ${response['user']}');
          final userId = response['user']['id'].toString();
          await _storage.write(key: 'user_id', value: userId);
          await _storage.write(key: 'user_email', value: email);
          currentUserId.value = int.parse(userId);
          isLoggedIn.value = true;
          
          // Also save to local database as backup
          developer.log('Saving user to local database');
          try {
            // First check if user already exists in local DB
            final existingUser = await _db.getUserByEmail(email);
            
            if (existingUser != null) {
              // Update existing user
              developer.log('User already exists in local DB, updating');
              await _db.updateUser(int.parse(userId), {
                'email': email,
                'password': password,
                'phone': phone,
                'role': 'user',
                'token': response['access'],
                'last_login': DateTime.now().toIso8601String(),
              });
            } else {
              // Insert new user
              await _db.insertUser({
                'id': int.parse(userId),
                'email': email,
                'password': password,
                'phone': phone,
                'role': 'user',
                'token': response['access'],
                'last_login': DateTime.now().toIso8601String(),
              });
            }
          } catch (dbError) {
            developer.log('Error saving user to local database', error: dbError);
            // Continue anyway since we have the user in the backend
          }
          
          developer.log('Registration completed successfully');
          developer.log('-------- REGISTRATION PROCESS COMPLETED --------');
          return true;
        } else {
          developer.log('Warning: No user data in registration response');
        }
            } catch (apiError) {
        developer.log('API registration failed, falling back to local', error: apiError);
      }
      
      // API failed or unavailable, fall back to local registration
      developer.log('Checking if user exists in local database');
      final existingUser = await _db.getUserByEmail(email);
      if (existingUser != null) {
        developer.log('User already exists locally with email: $email');
        developer.log('-------- REGISTRATION PROCESS FAILED --------');
        return false; // User already exists
      }

      developer.log('Creating new user in local database');
      final userId = await _db.insertUser({
        'email': email,
        'password': password,
        'phone': phone,
        'role': 'user',
        'token': 'auth_token_${DateTime.now().millisecondsSinceEpoch}',
        'last_login': DateTime.now().toIso8601String(),
      });

      if (userId > 0) {
        developer.log('User created in local database with ID: $userId');
        await _storage.write(key: 'user_id', value: userId.toString());
        currentUserId.value = userId;
        isLoggedIn.value = true;
        developer.log('User registered locally with ID: $userId');
        developer.log('-------- REGISTRATION PROCESS COMPLETED --------');
        return true;
      }
      
      developer.log('Failed to create user in local database');
      developer.log('-------- REGISTRATION PROCESS FAILED --------');
      return false;
    } catch (e) {
      developer.log('Error during registration', error: e);
      developer.log('-------- REGISTRATION PROCESS COMPLETED WITH ERROR --------');
      return false;
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      // 1. Vérifier si le matériel est disponible
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      developer.log('Biometric hardware check - Can check: $canCheckBiometrics, Device supported: $isDeviceSupported');
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        developer.log('Hardware does not support biometrics');
        return false;
      }
      
      // 2. Vérifier les types de biométrie disponibles
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      developer.log('Available biometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        developer.log('No biometrics enrolled on device');
        return false;
      }
      
      // Si nous arrivons ici, le matériel et au moins un type de biométrie sont disponibles
      // 3. Vérifier si l'utilisateur a déjà activé l'authentification biométrique
      final bioEnabled = isBiometricEnabled.value;
      final hasEmail = userEmail.value.isNotEmpty;
      
      developer.log('Biometric status - Enabled in app: $bioEnabled, Has email: $hasEmail');
      
      // Pour faciliter les tests en développement, considérons que la biométrie est utilisable 
      // si le matériel le supporte, même si l'utilisateur n'a pas encore activé la fonctionnalité
      final canUse = availableBiometrics.isNotEmpty;
      
      developer.log('Can use biometrics: $canUse');
      return canUse;
    } catch (e, stackTrace) {
      developer.log('Error checking biometric availability', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> enableBiometricLogin(String email) async {
    try {
      developer.log('Enabling biometric login for email: $email');
      await _storage.write(key: 'user_email', value: email);
      userEmail.value = email;
      isBiometricEnabled.value = true;
      developer.log('Biometric login enabled successfully');
    } catch (e, stackTrace) {
      developer.log('Error enabling biometric login', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canCheckBiometrics || await _localAuth.isDeviceSupported();
      
      if (!canAuthenticate) {
        developer.log('Device does not support biometric authentication');
        return false;
      }

      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        developer.log('No biometrics enrolled on this device');
        return false;
      }
      
      // Vérifier si la biométrie a été activée pour un compte
      final biometricEnabled = await _storage.read(key: 'biometric_enabled');
      if (biometricEnabled != 'true') {
        developer.log('Biometric login not enabled for any account');
        return false;
      }

      developer.log('Available biometrics: $availableBiometrics');
      
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
          options: const AuthenticationOptions(
          stickyAuth: true,
            biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        // Récupérer l'ID et l'email associés à la biométrie
        final userIdStr = await _storage.read(key: 'biometric_user_id');
        final email = await _storage.read(key: 'biometric_user_email');
        
        if (userIdStr != null && email != null) {
          final userId = int.parse(userIdStr);
          
          // Restaurer l'ID utilisateur et l'email dans le storage
          await _storage.write(key: 'user_id', value: userIdStr);
          await _storage.write(key: 'user_email', value: email);
          
          // Charger les données de l'utilisateur depuis la base de données
          final userData = await _db.getUserByEmail(email);
          if (userData != null) {
            // Mettre à jour les informations de connexion
            currentUserId.value = userId;
            userEmail.value = email;
            isLoggedIn.value = true;
            isAuthenticated.value = true;
            userRole.value = userData['role'] as String? ?? 'user';
            
            // Créer un nouveau token si nécessaire
            final token = 'auth_token_${DateTime.now().millisecondsSinceEpoch}';
            await _storage.write(key: 'jwt_token', value: token);
            
            developer.log('Biometric authentication successful for user $email (ID: $userId)');
            return true;
          } else {
            developer.log('Biometric authentication successful but user not found in database');
            return false;
          }
        } else {
          developer.log('Biometric authentication successful but user data not found');
          return false;
        }
      }
      
      return false;
    } on PlatformException catch (e) {
      developer.log('Error during biometric authentication', error: e);
      return false;
    }
  }

  Future<void> loginWithCredentials(String email, String password) async {
    try {
      developer.log('Attempting login with credentials for email: $email');
      
      // 1. D'abord, vérifier dans la liste des utilisateurs prédéfinis
      final validUser = _validUsers.firstWhereOrNull(
        (user) => user['email'] == email && user['password'] == password
      );
      
      // 2. Si l'utilisateur est trouvé dans la liste prédéfinie
      if (validUser != null) {
        developer.log('User found in predefined list');
      
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));
      
        // Store user data in local database (or update if already exists)
      final user = {
        'id': validUser['id'], 
        'email': validUser['email'],
        'role': validUser['role'],
        'token': 'auth_token_${DateTime.now().millisecondsSinceEpoch}',
        'last_login': DateTime.now().toIso8601String(),
      };
      await _db.insertUser(user);
        developer.log('User data stored/updated in database: ${user.toString()}');
      
      // Store token securely
      await _storage.write(key: 'jwt_token', value: user['token'].toString());
      developer.log('Token stored securely: ${user['token']}');
      
      isAuthenticated.value = true;
      userRole.value = user['role']?.toString() ?? 'user';
      developer.log('Login successful with role: ${user['role']}');
      
      // Enable biometric login if available
      if (isBiometricAvailable.value) {
        await enableBiometricLogin(email);
      }
        
        return;
      }
      
      // 3. Si pas dans la liste prédéfinie, vérifier dans la base de données locale
      final dbUser = await _db.getUserByEmail(email);
      if (dbUser != null) {
        developer.log('User found in database, but passwords cannot be verified (stored hashed)');
        
        // Note: Dans une application réelle, les mots de passe seraient stockés
        // sous forme de hash et vérifiés de manière sécurisée.
        // Comme cette application est une démo, on lève une exception pour simplifier.
        
        // Si on voulait vérifier le mot de passe hashé (dans une vraie app):
        // final storedHash = dbUser['password_hash'];
        // final isValid = await _passwordHasher.verify(password, storedHash);
        // if (isValid) { ... }
      }
      
      // Si l'utilisateur n'est pas trouvé ou le mot de passe est incorrect
      throw Exception('Identifiants invalides');
      
    } catch (e, stackTrace) {
      developer.log('Error during login', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      developer.log('Attempting logout');
      // Supprimer le token JWT de session mais garder les données biométriques
      await _storage.delete(key: 'jwt_token');
      
      // Ne supprimez pas l'identifiant utilisateur biométrique
      // await _storage.delete(key: 'user_id');
      
      isAuthenticated.value = false;
      userRole.value = '';
      currentUserId.value = null;
      developer.log('Logout successful');
    } catch (e, stackTrace) {
      developer.log('Error during logout', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  bool get isCitizen => userRole.value == 'user';
  bool get isAdmin => userRole.value == 'admin';

  // Méthode publique pour obtenir des informations détaillées sur la biométrie
  Future<Map<String, dynamic>> getBiometricDetails() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      return {
        'canCheckBiometrics': canCheckBiometrics,
        'isDeviceSupported': isDeviceSupported,
        'availableBiometrics': availableBiometrics,
        'isBiometricEnabled': isBiometricEnabled.value,
        'userEmail': userEmail.value,
      };
    } catch (e) {
      developer.log('Error getting biometric details', error: e);
      return {
        'error': e.toString(),
      };
    }
  }
  
  // Méthode pour tester l'authentification biométrique sans effectuer de connexion
  Future<bool> testBiometricAuthentication() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }
      
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to test biometric functionality',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      developer.log('Error testing biometric authentication', error: e);
      return false;
    }
  }

  // Associer l'authentification biométrique au compte connecté
  Future<bool> associateBiometricWithAccount() async {
    try {
      // Vérifier si la biométrie est disponible sur l'appareil
      final canAuthenticate = await canUseBiometrics();
      if (!canAuthenticate) {
        developer.log('Biometric authentication not available on device');
        return false;
      }
      
      // Récupérer l'ID utilisateur depuis le storage sécurisé
      final userId = await _storage.read(key: 'user_id');
      final userEmail = await _storage.read(key: 'user_email');
      
      if (userId == null) {
        // Essayer de récupérer l'ID utilisateur via l'AuthController si disponible
        try {
          final authController = Get.find<AuthController>();
          final userData = authController.userData.value;
          if (userData != null && userData['id'] != null) {
            final id = userData['id'].toString();
            final email = userData['email']?.toString() ?? '';
            
            // Stocker l'ID pour une utilisation future
            await _storage.write(key: 'user_id', value: id);
            if (email.isNotEmpty) {
              await _storage.write(key: 'user_email', value: email);
            }
            
            developer.log('Retrieved user ID from AuthController: $id');
            
            // Continuer avec ces valeurs
            return await _continueBiometricAssociation(id, email);
          }
        } catch (e) {
          developer.log('Failed to retrieve userData from AuthController', error: e);
        }
        
        developer.log('No user logged in to associate with biometrics');
        return false;
      }
      
      return await _continueBiometricAssociation(userId, userEmail ?? '');
    } catch (e) {
      developer.log('Error associating biometric with account', error: e);
      return false;
    }
  }
  
  Future<bool> _continueBiometricAssociation(String userId, String userEmail) async {
    try {
      // Demander à l'utilisateur de s'authentifier avec la biométrie
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to enable biometric login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        // Stocker les informations dans le stockage sécurisé
        await _storage.write(key: 'biometric_enabled', value: 'true');
        await _storage.write(key: 'biometric_user_id', value: userId);
        
        if (userEmail.isNotEmpty) {
          await _storage.write(key: 'biometric_user_email', value: userEmail);
        }
        
        // Obtenir le token actuel et le stocker pour la biométrie
        final currentToken = await _storage.read(key: 'jwt_token');
        if (currentToken != null) {
          await _storage.write(key: 'biometric_token', value: currentToken);
        }
        
        // Récupérer les données utilisateur pour s'assurer qu'elles sont disponibles lors de l'authentification biométrique
        final userData = await _db.getUserById(int.parse(userId));
        if (userData != null) {
          developer.log('Saved user data for biometric authentication: ${userData['email']}');
        }
        
        isBiometricEnabled.value = true;
        developer.log('Biometric authentication enabled for user $userId');
        return true;
      } else {
        developer.log('User cancelled biometric authentication');
        return false;
      }
    } catch (e) {
      developer.log('Error in biometric authentication process', error: e);
      return false;
    }
  }

  // Méthode pour vérifier si la biométrie est activée
  Future<bool> checkBiometricEnabled() async {
    try {
      final biometricEnabled = await _storage.read(key: 'biometric_enabled');
      return biometricEnabled == 'true';
    } catch (e) {
      developer.log('Error checking if biometric is enabled', error: e);
      return false;
    }
  }
}

