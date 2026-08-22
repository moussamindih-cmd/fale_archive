import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de persistance locale ultra-rapide et fiable
class LocalStorageService {
  static const _keyArchives = 'fale_archives_v2';
  static const _keyEmployees = 'fale_employees_v2';
  static const _keyCandidates = 'fale_candidates_v2';
  static const _keyLogistics = 'fale_logistics_v2';
  static const _keyNotifications = 'fale_notifications_v2';
  static const _keyThemeMode = 'fale_theme_mode_v2';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static bool get isInitialized => _prefs != null;

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'LocalStorageService must be initialized with init() first.',
      );
    }
    return _prefs!;
  }

  // --- Theme Mode ---
  static Future<void> saveThemeMode(String mode) async {
    if (_prefs == null) return;
    await prefs.setString(_keyThemeMode, mode);
  }

  static String? loadThemeMode() {
    if (_prefs == null) return null;
    return prefs.getString(_keyThemeMode);
  }

  // --- Archives ---
  static Future<void> saveArchives(List<Map<String, dynamic>> data) async {
    if (_prefs == null) return;
    await prefs.setString(_keyArchives, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadArchives() {
    if (_prefs == null) return null;
    final str = prefs.getString(_keyArchives);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // --- Employees ---
  static Future<void> saveEmployees(List<Map<String, dynamic>> data) async {
    if (_prefs == null) return;
    await prefs.setString(_keyEmployees, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadEmployees() {
    if (_prefs == null) return null;
    final str = prefs.getString(_keyEmployees);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // --- Candidates ---
  static Future<void> saveCandidates(List<Map<String, dynamic>> data) async {
    if (_prefs == null) return;
    await prefs.setString(_keyCandidates, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadCandidates() {
    if (_prefs == null) return null;
    final str = prefs.getString(_keyCandidates);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // --- Logistics ---
  static Future<void> saveLogistics(List<Map<String, dynamic>> data) async {
    if (_prefs == null) return;
    await prefs.setString(_keyLogistics, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadLogistics() {
    if (_prefs == null) return null;
    final str = prefs.getString(_keyLogistics);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // --- Notifications ---
  static Future<void> saveNotifications(List<Map<String, dynamic>> data) async {
    if (_prefs == null) return;
    await prefs.setString(_keyNotifications, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? loadNotifications() {
    if (_prefs == null) return null;
    final str = prefs.getString(_keyNotifications);
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }
}
