import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../models/attached_file.dart';
import '../models/daily_archive.dart';
import 'download/file_saver.dart';
import 'supabase_service.dart';

/// Résultat d'un export, pour rendre compte à l'utilisateur de ce qui a
/// réellement été inclus — un export silencieusement incomplet est pire
/// qu'un export refusé.
class ArchiveExportResult {
  final String destination;
  final int archiveCount;
  final int fileCount;

  /// Pièces qui n'ont pas pu être récupérées, avec leur motif.
  final Map<String, String> failures;

  const ArchiveExportResult({
    required this.destination,
    required this.archiveCount,
    required this.fileCount,
    this.failures = const {},
  });

  bool get isComplete => failures.isEmpty;
}

/// Export des archives au format ZIP (§5.1.5).
///
/// Le ZIP contient un dossier par archive, ses pièces jointes, et un
/// manifeste CSV décrivant le lot. Le manifeste est ce qui rend l'export
/// exploitable : sans lui, on obtient un tas de fichiers sans contexte.
class ArchiveExportService {
  const ArchiveExportService._();

  static final DateFormat _day = DateFormat('dd/MM/yyyy');
  static final DateFormat _stamp = DateFormat('yyyyMMdd-HHmm');

  /// Assemble le ZIP en mémoire et le remet à l'utilisateur.
  ///
  /// [onProgress] est appelé après chaque archive traitée, pour permettre à
  /// l'appelant d'afficher une progression : un export de plusieurs dizaines
  /// de pièces prend plusieurs secondes.
  static Future<ArchiveExportResult> exportToZip({
    required List<DailyArchive> archives,
    required String generatedBy,
    void Function(int done, int total)? onProgress,
  }) async {
    final zip = Archive();
    final failures = <String, String>{};
    var fileCount = 0;

    for (var i = 0; i < archives.length; i++) {
      final archive = archives[i];
      final folder = _folderNameFor(archive);

      for (final file in archive.files) {
        final bytes = await _bytesOf(file);
        if (bytes == null) {
          failures['$folder/${file.name}'] =
              file.storagePath == null
                  ? 'pièce jamais envoyée au stockage'
                  : 'téléchargement impossible';
          continue;
        }
        zip.addFile(
          ArchiveFile('$folder/${file.name}', bytes.length, bytes),
        );
        fileCount++;
      }

      // Une archive purgée n'a plus de pièce : la fiche seule documente
      // qu'un contenu a existé puis été détruit dans les règles.
      if (archive.files.isEmpty) {
        final notice = utf8.encode(_noticeFor(archive));
        zip.addFile(
          ArchiveFile('$folder/_fiche.txt', notice.length, notice),
        );
      }

      onProgress?.call(i + 1, archives.length);
    }

    final manifest = utf8.encode(buildManifestCsv(archives, generatedBy));
    zip.addFile(ArchiveFile('manifeste.csv', manifest.length, manifest));

    final encoded = ZipEncoder().encode(zip);
    if (encoded == null) {
      throw StateError('Échec de la compression de l\'export.');
    }
    final bytes = Uint8List.fromList(encoded);

    final destination = await saveFile(
      bytes: bytes,
      fileName: 'archives-${_stamp.format(DateTime.now())}.zip',
      mimeType: 'application/zip',
    );

    return ArchiveExportResult(
      destination: destination,
      archiveCount: archives.length,
      fileCount: fileCount,
      failures: failures,
    );
  }

  /// Manifeste CSV décrivant le lot.
  ///
  /// Séparateur point-virgule et BOM UTF-8 : c'est ce qu'attend Excel en
  /// configuration francophone. Sans le BOM, les accents sont illisibles ;
  /// avec une virgule, tout atterrit dans une seule colonne.
  static String buildManifestCsv(
    List<DailyArchive> archives,
    String generatedBy,
  ) {
    final buffer = StringBuffer('﻿');
    buffer.writeln('Référence;Date;Titre;Catégorie;Déposant;Pièces;'
        'Emplacement;Mots-clés;Conservation jusqu\'au;Gel conservatoire');

    for (final a in archives) {
      buffer.writeln([
        _csv(a.reference),
        _day.format(a.archiveDate),
        _csv(a.title),
        _csv(a.category),
        _csv(a.employeeName),
        a.files.length.toString(),
        _csv(a.physicalLocation),
        _csv(a.keywords.join(', ')),
        a.retentionUntil == null ? '' : _day.format(a.retentionUntil!),
        a.legalHold ? 'Oui' : 'Non',
      ].join(';'));
    }

    buffer.writeln();
    buffer.writeln('Export généré le;${_day.format(DateTime.now())}');
    buffer.writeln('Par;${_csv(generatedBy)}');
    buffer.writeln('Nombre d\'archives;${archives.length}');
    return buffer.toString();
  }

  static Future<Uint8List?> _bytesOf(AttachedFile file) async {
    if (file.bytes != null) return Uint8List.fromList(file.bytes!);
    final path = file.storagePath;
    if (path == null) return null;
    return SupabaseService.instance.downloadDocument(path);
  }

  /// Nom de dossier sûr : le ZIP est ouvert sur des systèmes de fichiers aux
  /// règles différentes, on écarte tout ce qui pourrait poser problème.
  static String _folderNameFor(DailyArchive archive) {
    final raw = '${archive.reference}-${archive.title}';
    final cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }

  static String _noticeFor(DailyArchive archive) {
    final buffer = StringBuffer()
      ..writeln('Référence : ${archive.reference}')
      ..writeln('Date : ${_day.format(archive.archiveDate)}')
      ..writeln('Titre : ${archive.title}')
      ..writeln('Déposant : ${archive.employeeName}')
      ..writeln('Catégorie : ${archive.category}');
    if (archive.summary.isNotEmpty) {
      buffer.writeln('Résumé : ${archive.summary}');
    }
    if (archive.isPurged) {
      buffer.writeln();
      buffer.writeln('Les pièces de cette archive ont été détruites au terme '
          'de leur durée légale de conservation.');
    } else {
      buffer.writeln();
      buffer.writeln('Aucune pièce jointe à cette archive.');
    }
    return buffer.toString();
  }

  /// Échappement CSV : guillemets doublés et champ encadré dès qu'il
  /// contient un séparateur, un guillemet ou un saut de ligne.
  static String _csv(String value) {
    if (value.isEmpty) return '';
    final needsQuoting = value.contains(RegExp(r'[;"\n\r]'));
    final escaped = value.replaceAll('"', '""');
    return needsQuoting ? '"$escaped"' : escaped;
  }
}
