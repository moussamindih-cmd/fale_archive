import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_storage_service.dart';

class ThemeState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  // Champs pour la Marque Blanche (White Label)
  Color? _tenantPrimaryColor;
  String? _tenantLogoUrl;

  ThemeState() {
    _loadFromStorage();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Color? get tenantPrimaryColor => _tenantPrimaryColor;
  String? get tenantLogoUrl => _tenantLogoUrl;

  void _loadFromStorage() {
    final saved = LocalStorageService.loadThemeMode();
    if (saved != null) {
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    }
  }

  /// Charge les paramètres de marque blanche depuis la BDD pour une organisation
  Future<void> loadTenantTheme(String organizationId) async {
    try {
      final response = await Supabase.instance.client
          .from('organizations')
          .select('primary_color, logo_url')
          .eq('id', organizationId)
          .maybeSingle();

      if (response != null) {
        final hex = response['primary_color'] as String?;
        if (hex != null && hex.length >= 7) {
          final hexColor = hex.replaceAll('#', '0xFF');
          _tenantPrimaryColor = Color(int.parse(hexColor));
        }
        _tenantLogoUrl = response['logo_url'] as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur chargement thème tenant: $e');
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    LocalStorageService.saveThemeMode(mode.name);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
