import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Déclenche le téléchargement navigateur via une URL d'objet.
///
/// L'URL est révoquée immédiatement après le clic : la garder retiendrait
/// les octets en mémoire pour toute la durée de vie de l'onglet, ce qui,
/// sur un export de plusieurs dizaines de mégaoctets, se voit.
Future<String> saveFileImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return fileName;
}
