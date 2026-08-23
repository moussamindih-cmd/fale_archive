import 'package:creposa/models/attached_file.dart';
import 'package:creposa/models/document_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttachedFile', () {
    test('aller-retour JSON sans perte des champs persistés', () {
      final origine = AttachedFile(
        name: 'bordereau.pdf',
        extension: 'pdf',
        sizeBytes: 204800,
        isScanned: true,
        storagePath: 'org-a/archives/arc-1/1750000000-bordereau.pdf',
        mimeType: 'application/pdf',
        checksumSha256: 'a' * 64,
        uploadedBy: 'emp-1',
        uploadedAt: DateTime.utc(2026, 8, 21, 10, 30),
      );

      final relu = AttachedFile.fromJson(origine.toJson());

      expect(relu.name, origine.name);
      expect(relu.sizeBytes, origine.sizeBytes);
      expect(relu.isScanned, origine.isScanned);
      expect(relu.storagePath, origine.storagePath);
      expect(relu.mimeType, origine.mimeType);
      expect(relu.checksumSha256, origine.checksumSha256);
      expect(relu.uploadedBy, origine.uploadedBy);
      expect(relu.uploadedAt, origine.uploadedAt);
    });

    test('les octets ne sont jamais sérialisés', () {
      final fichier = AttachedFile(
        name: 'scan.png',
        extension: 'png',
        sizeBytes: 3,
        bytes: const [1, 2, 3],
      );
      expect(fichier.toJson().containsKey('bytes'), isFalse);
      expect(AttachedFile.fromJson(fichier.toJson()).bytes, isNull);
    });

    test('relit une pièce déposée avant les champs de traçabilité', () {
      // Lignes déjà présentes dans la colonne JSONB `documents`.
      final ancienne = AttachedFile.fromJson({
        'name': 'facture.pdf',
        'extension': 'pdf',
        'sizeBytes': 1024,
        'isScanned': false,
        'storagePath': 'org-a/logistics/l-1/1-facture.pdf',
      });

      expect(ancienne.name, 'facture.pdf');
      expect(ancienne.mimeType, isNull);
      expect(ancienne.checksumSha256, isNull);
      expect(ancienne.uploadedAt, isNull);
    });

    test('une date illisible ne fait pas planter la relecture', () {
      final fichier = AttachedFile.fromJson({
        'name': 'x.pdf',
        'extension': 'pdf',
        'sizeBytes': 1,
        'uploadedAt': 'pas-une-date',
      });
      expect(fichier.uploadedAt, isNull);
    });

    test('copyWith conserve les champs non fournis', () {
      final origine = AttachedFile(
        name: 'a.pdf',
        extension: 'pdf',
        sizeBytes: 10,
        checksumSha256: 'b' * 64,
        uploadedBy: 'emp-9',
      );
      final copie = origine.copyWith(storagePath: 'org-a/x/y/z.pdf');

      expect(copie.storagePath, 'org-a/x/y/z.pdf');
      expect(copie.checksumSha256, origine.checksumSha256);
      expect(copie.uploadedBy, origine.uploadedBy);
      expect(copie.name, origine.name);
    });

    test('taille lisible aux bornes des unités', () {
      AttachedFile of(int octets) =>
          AttachedFile(name: 'f', extension: 'bin', sizeBytes: octets);
      expect(of(512).readableSize, '512 o');
      expect(of(1024).readableSize, '1.0 Ko');
      expect(of(1024 * 1024).readableSize, '1.0 Mo');
    });
  });

  group('DocumentVersion', () {
    DocumentVersion build(Map<String, dynamic> overrides) =>
        DocumentVersion.fromJson({
          'id': 'v-1',
          'organization_id': 'org-a',
          'archive_id': 'arc-1',
          'version_number': 2,
          'file_name': 'rapport.pdf',
          'storage_path': 'org-a/archives/arc-1/2-rapport.pdf',
          'created_at': '2026-08-21T10:30:00.000Z',
          ...overrides,
        });

    test('lit une ligne document_versions', () {
      final version = build({'size_bytes': 4096, 'comment': 'Correction'});
      expect(version.versionNumber, 2);
      expect(version.label, 'v2');
      expect(version.sizeBytes, 4096);
      expect(version.comment, 'Correction');
    });

    test('déduit l\'extension du nom de fichier', () {
      expect(build({'file_name': 'a.PDF'}).extension, 'pdf');
      expect(build({'file_name': 'archive.tar.gz'}).extension, 'gz');
      expect(build({'file_name': 'sans_extension'}).extension, '');
      expect(build({'file_name': 'point.'}).extension, '');
    });

    test('se reconvertit en pièce jointe affichable', () {
      final piece = build({
        'size_bytes': 2048,
        'mime_type': 'application/pdf',
        'checksum_sha256': 'c' * 64,
      }).toAttachedFile();

      expect(piece.name, 'rapport.pdf');
      expect(piece.extension, 'pdf');
      expect(piece.isPdf, isTrue);
      expect(piece.sizeBytes, 2048);
      expect(piece.storagePath, 'org-a/archives/arc-1/2-rapport.pdf');
      expect(piece.checksumSha256, 'c' * 64);
    });

    test('une date absente ne bloque pas la relecture', () {
      final version = build({'created_at': null});
      expect(version.createdAt, isA<DateTime>());
    });
  });
}
