import 'package:flutter/foundation.dart';

/// Point d'entrée unique pour signaler une erreur non bloquante — un appel
/// réseau avalé, une exception capturée manuellement, un crash non intercepté
/// remonté par [FlutterError.onError]/[PlatformDispatcher.instance.onError]
/// (câblés dans `main.dart`).
///
/// Aujourd'hui : journalisation locale via [debugPrint], donc rien n'est
/// envoyé à l'extérieur de l'appareil. Pour brancher un vrai service de
/// supervision (Sentry, Crashlytics...) en production, il suffit de modifier
/// [report] ici — aucun des appelants à travers l'app n'a besoin d'être
/// touché.
class ErrorReportingService {
  ErrorReportingService._();
  static final ErrorReportingService instance = ErrorReportingService._();

  void report(Object error, StackTrace? stackTrace, {String? context}) {
    final prefix = context != null ? '[$context] ' : '';
    debugPrint('$prefix$error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
