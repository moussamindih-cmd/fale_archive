import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/local_storage_service.dart';
import 'services/error_reporting_service.dart';

/// Projet Supabase ciblé — surchargeable par environnement (dev/staging/prod)
/// sans recompiler le code :
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Les valeurs par défaut ci-dessous pointent vers le projet historique du
/// dépôt ; voir README.md pour la marche à suivre complète. La clé publiable
/// est destinée à être visible du client — sa sécurité repose entièrement
/// sur les politiques RLS, jamais sur son secret.
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
