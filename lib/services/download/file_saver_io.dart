import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Écrit le fichier dans le répertoire de documents de l'application.
Future<String> saveFileImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
