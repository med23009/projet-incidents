import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class LocalStorageService extends GetxService {
  late SharedPreferences _prefs;

  Future<LocalStorageService> init() async {
    developer.log('Initializing LocalStorageService');
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  @override
  void onInit() {
    super.onInit();
    developer.log('LocalStorageService onInit called. Note: Initialization is now handled in the init method.');
  }

  // Save string data
  Future<bool> saveString(String key, String value) async {
    try {
      return await _prefs.setString(key, value);
    } catch (e) {
      developer.log('Error saving string: $e', error: e);
      return false;
    }
  }

  // Get string data
  String? getString(String key) {
    try {
      return _prefs.getString(key);
    } catch (e) {
      developer.log('Error getting string: $e', error: e);
      return null;
    }
  }

  // Save boolean data
  Future<bool> saveBool(String key, bool value) async {
    try {
      return await _prefs.setBool(key, value);
    } catch (e) {
      developer.log('Error saving boolean: $e', error: e);
      return false;
    }
  }

  // Get boolean data
  bool? getBool(String key) {
    try {
      return _prefs.getBool(key);
    } catch (e) {
      developer.log('Error getting boolean: $e', error: e);
      return null;
    }
  }

  // Clear all data
  Future<bool> clearAll() async {
    try {
      return await _prefs.clear();
    } catch (e) {
      developer.log('Error clearing data: $e', error: e);
      return false;
    }
  }

  // Remove specific data
  Future<bool> remove(String key) async {
    try {
      return await _prefs.remove(key);
    } catch (e) {
      developer.log('Error removing key: $e', error: e);
      return false;
    }
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  Future<bool> setInt(String key, int value) async {
    developer.log('Storing int: $key');
    return await _prefs.setInt(key, value);
  }

  Future<bool> setDouble(String key, double value) async {
    developer.log('Storing double: $key');
    return await _prefs.setDouble(key, value);
  }

  Future<bool> setStringList(String key, List<String> value) async {
    developer.log('Storing string list: $key');
    return await _prefs.setStringList(key, value);
  }

  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
} 