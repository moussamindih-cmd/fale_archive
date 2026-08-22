import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/local_storage_service.dart';

/// Configuration Supabase.
///
/// Fournie par `--dart-define` pour permettre des environnements distincts
/// (dev / recette / production) et la rotation des clés sans modifier le code.
/// Les valeurs par défaut ciblent l'instance de développement ; la clé
/// publiable est destinée à être visible du client — sa sécurité repose
/// entièrement sur les politiques RLS, jamais sur son secret.
const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://rljzphdwqfwssdwwdbnr.supabase.co',
);
const String _supabaseKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_jp3pjJ9zp0w-QY-068iVyQ_giMQHGs5',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  await LocalStorageService.init();
  await initializeDateFormatting('fr_FR', null);

  runApp(const FaleArchivesApp());
}

class FaleArchivesApp extends StatelessWidget {
  /// États injectables, pour les tests uniquement. En production, [AppScopeHost]
  /// les construit lui-même — une seule fois, pour toute l'application.
  final AppState? appState;
  final ThemeState? themeState;

  const FaleArchivesApp({super.key, this.appState, this.themeState});

  @override
  Widget build(BuildContext context) {
    return AppScopeHost(
      appState: appState,
      themeState: themeState,
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final themeState = AppScope.of(context).themeState;

    return AnimatedBuilder(
      animation: themeState,
      builder: (context, _) {
        return MaterialApp(
          title: 'FALE Archives',
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          darkTheme: darkAppTheme,
          themeMode: themeState.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
