import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer' as developer;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('accidents.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        name TEXT,
        password TEXT,
        phone TEXT,
        role TEXT NOT NULL,
        token TEXT,
        last_login TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        photo_path TEXT,
        photo_url TEXT,
        voice_note_path TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        incident_type TEXT NOT NULL DEFAULT 'general',
        sync_status TEXT NOT NULL,
        user_id INTEGER,
        additional_media TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_incidents_user_id ON incidents(user_id)');
    await db.execute('CREATE INDEX idx_incidents_sync_status ON incidents(sync_status)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Mise à jour de la structure de la base de données lors des mises à jour
    if (oldVersion < 2) {
      // Ajouter les colonnes manquantes à la table incidents
      try {
        await db.execute('ALTER TABLE incidents ADD COLUMN photo_url TEXT;');
        await db.execute('ALTER TABLE incidents ADD COLUMN status TEXT NOT NULL DEFAULT "pending";');
        await db.execute('ALTER TABLE incidents ADD COLUMN incident_type TEXT NOT NULL DEFAULT "general";');
      } catch (e) {
        print('Error upgrading database: $e');
        // Si erreur (ex: colonne existe déjà), on continue
      }
    }
    
    if (oldVersion < 3) {
      // Ajouter les colonnes manquantes à la table users
      try {
        await db.execute('ALTER TABLE users ADD COLUMN password TEXT;');
        await db.execute('ALTER TABLE users ADD COLUMN phone TEXT;');
      } catch (e) {
        print('Error upgrading users table: $e');
      }
    }
    
    if (oldVersion < 4) {
      // Add additional_media column to incidents table
      try {
        await db.execute('ALTER TABLE incidents ADD COLUMN additional_media TEXT;');
      } catch (e) {
        print('Error adding additional_media column: $e');
      }
    }
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    try {
      developer.log('DB: Inserting or updating user: ${user['email']}');
    final db = await database;
      
      // Check if user already exists
      final existingUser = await getUserByEmail(user['email']);
      
      if (existingUser != null) {
        // Update existing user
        developer.log('DB: User exists, updating: ${user['email']}');
        await db.update(
      'users',
      user,
          where: 'email = ?',
          whereArgs: [user['email']],
        );
        developer.log('DB: User updated: ${existingUser['id']}');
        return existingUser['id'];
      } else {
        // Insert new user
        developer.log('DB: Inserting new user: ${user['email']}');
        final id = await db.insert('users', user);
        developer.log('DB: New user inserted with ID: $id');
        return id;
      }
    } catch (e) {
      developer.log('DB: Error inserting user', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      developer.log('DB: Looking up user by email: $email');
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      );
      
      if (results.isNotEmpty) {
        developer.log('DB: User found: ${results.first}');
        return results.first;
      } else {
        developer.log('DB: No user found with email: $email');
        return null;
      }
    } catch (e) {
      developer.log('DB: Error getting user by email', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    try {
      developer.log('DB: Looking up user by ID: $id');
      final db = await database;
      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (results.isNotEmpty) {
        developer.log('DB: User found by ID: ${results.first['email']}');
        return results.first;
      } else {
        developer.log('DB: No user found with ID: $id');
        return null;
      }
    } catch (e) {
      developer.log('DB: Error looking up user by ID', error: e);
      return null;
    }
  }
  
  // Update an existing user by ID
  Future<int> updateUser(int userId, Map<String, dynamic> userData) async {
    try {
      developer.log('DB: Updating user with ID: $userId');
      final db = await database;
      
      // Make sure we don't try to update the ID
      final updatableData = Map<String, dynamic>.from(userData);
      if (updatableData.containsKey('id')) {
        updatableData.remove('id');
      }
      
      final result = await db.update(
        'users',
        updatableData,
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      developer.log('DB: User update result: $result');
      return result;
    } catch (e) {
      developer.log('DB: Error updating user', error: e);
      return 0;
    }
  }

  Future<int> insertIncident(Map<String, dynamic> incident) async {
    try {
      developer.log('DB: Inserting incident into local database: ${incident['title']}');
      final db = await database;
      final id = await db.insert('incidents', incident);
      developer.log('DB: Incident inserted with ID: $id');
      return id;
    } catch (e) {
      developer.log('DB: Error inserting incident', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getIncidentsByUserId(int userId) async {
    try {
      developer.log('DB: Fetching incidents for user ID: $userId');
    final db = await database;
      final incidents = await db.query(
      'incidents',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
      developer.log('DB: Found ${incidents.length} incidents for user $userId');
      return incidents;
    } catch (e) {
      developer.log('DB: Error getting incidents by user ID', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedIncidents() async {
    try {
      developer.log('DB: Fetching unsynced incidents from database');
      final db = await database;
      
      // First, let's debug all incidents to see their sync_status values
      final allIncidents = await db.query('incidents');
      developer.log('DB: Total incidents in database: ${allIncidents.length}');
      for (var incident in allIncidents) {
        developer.log('DB: Incident ID: ${incident['id']}, sync_status: ${incident['sync_status']}');
      }
      
      // Now query for pending incidents
      final incidents = await db.query(
        'incidents',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );
      
      developer.log('DB: Found ${incidents.length} unsynced incidents with status "pending"');
      if (incidents.isNotEmpty) {
        developer.log('DB: First unsynced incident: ${incidents.first}');
      }
      
      return incidents;
    } catch (e) {
      developer.log('DB: Error getting unsynced incidents', error: e);
      rethrow;
    }
  }

  Future<int> updateIncidentSyncStatus(int incidentId, String syncStatus) async {
    try {
      developer.log('DB: Updating sync status for incident $incidentId to $syncStatus');
      final db = await database;
      final count = await db.update(
        'incidents',
        {'sync_status': syncStatus},
        where: 'id = ?',
        whereArgs: [incidentId],
      );
      developer.log('DB: Updated sync status for $count incidents');
      return count;
    } catch (e) {
      developer.log('DB: Error updating incident sync status', error: e);
      rethrow;
    }
  }
  
  Future<int> updateIncident(int incidentId, Map<String, dynamic> incidentData) async {
    try {
      developer.log('DB: Updating incident $incidentId with data: ${incidentData.keys.join(', ')}');
      final db = await database;
      
      final result = await db.update(
        'incidents',
        incidentData,
        where: 'id = ?',
        whereArgs: [incidentId],
      );
      
      developer.log('DB: Updated $result incidents');
      return result;
    } catch (e) {
      developer.log('DB: Error updating incident', error: e);
      rethrow;
    }
  }

  // Delete an incident by ID
  Future<int> deleteIncident(int incidentId) async {
    try {
      developer.log('DB: Deleting incident with ID: $incidentId');
      final db = await database;
      
      final result = await db.delete(
        'incidents',
        where: 'id = ?',
        whereArgs: [incidentId],
      );
      
      developer.log('DB: Deleted $result incidents');
      return result;
    } catch (e) {
      developer.log('DB: Error deleting incident', error: e);
      rethrow;
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
