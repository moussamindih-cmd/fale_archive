import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'state/app_state.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/local_storage_service.dart';
import 'services/error_reporting_service.dart';

AppState _defaultAppState = AppState();
final _defaultThemeState = ThemeState();

/// Projet Supabase ciblé — surchargeable par environnement (dev/staging/prod)
/// sans recompiler le code :
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Les valeurs par défaut ci-dessous pointent vers le projet historique du
/// dépôt ; voir README.md pour la marche à suivre complète.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://rljzphdwqfwssdwwdbnr.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_jp3pjJ9zp0w-QY-068iVyQ_giMQHGs5',
);

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Capture centralisée des erreurs non gérées — voir
      // ErrorReportingService pour brancher un vrai service de supervision
      // (Sentry, Crashlytics...) le moment venu, sans toucher au reste de
      // l'app.
      FlutterError.onError = (details) {
        FlutterError.presentError(details); // conserve l'affichage habituel
        ErrorReportingService.instance.report(
          details.exception,
          details.stack,
          context: 'FlutterError',
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        ErrorReportingService.instance.report(
          error,
          stack,
          context: 'PlatformDispatcher',
        );
        return true; // erreur prise en charge
      };

      // Initialisation Supabase
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
      );

      await LocalStorageService.init();
      await initializeDateFormatting('fr_FR', null);

      _defaultAppState = AppState();

      runApp(const FaleArchivesApp());
    },
    (error, stack) => ErrorReportingService.instance.report(
      error,
      stack,
      context: 'runZonedGuarded',
    ),
  );
}

class FaleArchivesApp extends StatelessWidget {
  final AppState? appState;
  final ThemeState? themeState;

  const FaleArchivesApp({super.key, this.appState, this.themeState});

  @override
  Widget build(BuildContext context) {
    final effectiveAppState = appState ?? _defaultAppState;
    final effectiveThemeState = themeState ?? _defaultThemeState;

    return AnimatedBuilder(
      animation: Listenable.merge([effectiveAppState, effectiveThemeState]),
      builder: (context, _) {
        return MaterialApp(
          title: 'FALE Archives',
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          darkTheme: darkAppTheme,
          themeMode: effectiveThemeState.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
