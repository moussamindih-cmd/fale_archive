import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'state/app_state.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/local_storage_service.dart';

AppState _defaultAppState = AppState();
final _defaultThemeState = ThemeState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Supabase
  await Supabase.initialize(
    url: 'https://rljzphdwqfwssdwwdbnr.supabase.co',
    publishableKey: 'sb_publishable_jp3pjJ9zp0w-QY-068iVyQ_giMQHGs5',
  );

  await LocalStorageService.init();
  await initializeDateFormatting('fr_FR', null);

  _defaultAppState = AppState();

  runApp(const FaleArchivesApp());
}

class FaleArchivesApp extends StatelessWidget {
  final AppState? appState;
  final ThemeState? themeState;

  const FaleArchivesApp({
    super.key,
    this.appState,
    this.themeState,
  });

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
