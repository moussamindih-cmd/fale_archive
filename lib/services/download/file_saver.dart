import 'dart:typed_data';

import 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';

/// Remet un fichier à l'utilisateur.
///
/// Le mécanisme diffère radicalement selon la cible — téléchargement
/// navigateur d'un côté, écriture disque de l'autre — d'où l'import
/// conditionnel plutôt qu'un test à l'exécution : le code d'une plateforme
/// n'est pas compilé pour l'autre.
///
/// Retourne un libellé décrivant la destination, à afficher à l'utilisateur.
Future<String> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) =>
    saveFileImpl(bytes: bytes, fileName: fileName, mimeType: mimeType);
