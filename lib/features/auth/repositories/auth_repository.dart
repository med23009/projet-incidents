import 'package:get/get.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:accidentsapp/features/auth/services/auth_service.dart';
import '../../../core/database/database_helper.dart';
import 'dart:developer' as developer;

class AuthRepository {
  final _authService = Get.find<AuthService>();
  final _storage = const FlutterSecureStorage();
  final _db = DatabaseHelper.instance;

  Future<bool> login(String email, String password) async {
    try {
      developer.log('Attempting login with credentials for email: $email');
      await _authService.loginWithCredentials(email, password);
      developer.log('Login successful');
      return true;
    } catch (e, stackTrace) {
      developer.log('Login failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> register(String email, String password, String phone) async {
    try {
      developer.log('Attempting registration for email: $email');
      
      // 1. Tenter de se connecter avec l'email fourni pour vérifier s'il existe déjà
      try {
        // Cette méthode va lever une exception si l'utilisateur n'existe pas
        await _authService.loginWithCredentials(email, 'test_password');
        
        // Si on arrive ici, c'est que l'utilisateur existe déjà (la connexion a réussi)
        developer.log('User with email $email already exists (login successful)');
        throw Exception('Identifiants invalides');
      } catch (e) {
        // Si l'erreur est due à des identifiants invalides, c'est normal, l'utilisateur n'existe pas
        if (!e.toString().contains('Identifiants invalides')) {
          // Si c'est une autre erreur, on la propage
          rethrow;
        }
        // Sinon, on continue avec l'inscription
      }
      
      // 2. Vérifier si l'email existe déjà dans la base de données locale
      final existingUser = await _db.getUserByEmail(email);
      if (existingUser != null) {
        developer.log('User with email $email already exists in database');
        throw Exception('Identifiants invalides');
      }
      
      // 3. Créer un nouvel utilisateur dans la base de données locale
      final newUser = {
        'id': DateTime.now().millisecondsSinceEpoch, // Générer un ID unique
        'email': email,
        'role': 'user', // Rôle par défaut
        'token': 'auth_token_${DateTime.now().millisecondsSinceEpoch}',
        'last_login': DateTime.now().toIso8601String(),
        // Dans une vraie application, nous stockerions un hash du mot de passe
        // 'password_hash': await _hashPassword(password),
      };
      
      // Simuler un délai d'API
      await Future.delayed(const Duration(seconds: 1));
      
      // Insérer l'utilisateur dans la base de données
      await _db.insertUser(newUser);
      developer.log('Registration successful for email: $email');
      
      return true;
    } catch (e, stackTrace) {
      developer.log('Registration failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        developer.log('No token found');
        return false;
      }
      
      try {
        if (JwtDecoder.isExpired(token)) {
          developer.log('Token expired');
          await logout();
          return false;
        }
      } catch (e) {
        developer.log('Invalid token format', error: e);
        await logout();
        return false;
      }
      
      developer.log('User is authenticated');
      return true;
    } catch (e, stackTrace) {
      developer.log('Authentication check failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      developer.log('User logged out successfully');
    } catch (e, stackTrace) {
      developer.log('Logout failed', error: e, stackTrace: stackTrace);
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      developer.log('Token retrieved: ${token != null ? 'exists' : 'null'}');
      return token;
    } catch (e, stackTrace) {
      developer.log('Failed to get token', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      // 1. Essayer d'obtenir l'ID utilisateur depuis le stockage sécurisé
      final userId = await _storage.read(key: 'user_id');
      if (userId != null) {
        developer.log('User ID found in secure storage: $userId');
        
        // 2. Récupérer les données utilisateur complètes depuis la base de données
        final userData = await _db.getUserById(int.parse(userId));
        if (userData != null) {
          developer.log('User data retrieved from database using stored ID: ${userData.toString()}');
          return userData;
        }
      }
      
      // 3. Si pas d'ID ou données introuvables, essayer de récupérer les données du token
      final token = await getToken();
      if (token != null) {
        try {
          final tokenData = JwtDecoder.decode(token);
          developer.log('User data retrieved from token: ${tokenData.toString()}');
          
          // 4. Si le token contient un ID, le stocker pour utilisation future
          if (tokenData.containsKey('id') || tokenData.containsKey('user_id')) {
            final id = tokenData['id'] ?? tokenData['user_id'];
            await _storage.write(key: 'user_id', value: id.toString());
            developer.log('Saved user ID to secure storage: $id');
            return tokenData;
          }
        } catch (e) {
          developer.log('Failed to decode token, will try database', error: e);
        }
      }
      
      // 5. Si pas de token ou décodage échoué, essayer de récupérer depuis la base de données par email
      final email = _authService.userEmail.value;
      if (email.isNotEmpty) {
        final user = await _db.getUserByEmail(email);
        if (user != null) {
          developer.log('User data retrieved from database by email: ${user.toString()}');
          
          // Stocker l'ID pour utilisation future
          if (user.containsKey('id')) {
            await _storage.write(key: 'user_id', value: user['id'].toString());
            developer.log('Saved user ID to secure storage from email lookup: ${user['id']}');
          }
          
          return user;
        }
      }
      
      // 6. En dernier recours, créer des données utilisateur de base
      if (_authService.isAuthenticated.value) {
        final fallbackData = {
          'id': 1,
          'email': email,
          'role': _authService.userRole.value
        };
        developer.log('Created fallback user data: ${fallbackData.toString()}');
        
        // Stocker l'ID par défaut
        await _storage.write(key: 'user_id', value: '1');
        developer.log('Saved fallback user ID to secure storage: 1');
        
        return fallbackData;
      }
      
      developer.log('No user data found');
      return null;
    } catch (e, stackTrace) {
      developer.log('Failed to get user data', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
