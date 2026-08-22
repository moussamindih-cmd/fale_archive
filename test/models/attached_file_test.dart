import 'package:flutter_test/flutter_test.dart';
import 'package:creposa/models/attached_file.dart';

void main() {
  group('AttachedFile.validationError', () {
    test('accepte un fichier de type et taille autorisés', () {
      final file = AttachedFile(
        name: 'facture.pdf',
        extension: 'pdf',
        sizeBytes: 1024,
      );
      expect(file.validationError, isNull);
      expect(file.isValid, isTrue);
    });

    test('refuse un type de fichier non autorisé', () {
      final file = AttachedFile(
        name: 'script.exe',
        extension: 'exe',
        sizeBytes: 1024,
      );
      expect(file.validationError, contains('non autorisé'));
      expect(file.isValid, isFalse);
    });

    test('refuse un fichier trop volumineux', () {
      final file = AttachedFile(
        name: 'gros.pdf',
        extension: 'pdf',
        sizeBytes: AttachedFile.maxSizeBytes + 1,
      );
      expect(file.validationError, contains('volumineux'));
      expect(file.isValid, isFalse);
    });

    test('accepte un fichier pile à la limite de taille', () {
      final file = AttachedFile(
        name: 'limite.pdf',
        extension: 'pdf',
        sizeBytes: AttachedFile.maxSizeBytes,
      );
      expect(file.isValid, isTrue);
    });

    test("l'extension est comparée sans tenir compte de la casse", () {
      final file = AttachedFile(
        name: 'photo.PNG',
        extension: 'PNG',
        sizeBytes: 1024,
      );
      expect(file.isValid, isTrue);
    });
  });

  group('AttachedFile JSON', () {
    test(
      'round-trip toJson/fromJson préserve les métadonnées (sans bytes)',
      () {
        final original = AttachedFile(
          name: 'contrat.pdf',
          extension: 'pdf',
          sizeBytes: 2048,
          isScanned: true,
          storagePath: 'org1/candidates/cand1/123-contrat.pdf',
        );

        final decoded = AttachedFile.fromJson(original.toJson());

        expect(decoded.name, original.name);
        expect(decoded.extension, original.extension);
        expect(decoded.sizeBytes, original.sizeBytes);
        expect(decoded.isScanned, original.isScanned);
        expect(decoded.storagePath, original.storagePath);
        expect(
          decoded.bytes,
          isNull,
        ); // les octets ne sont jamais persistés en JSON
      },
    );

    test('round-trip préserve removedAt (corbeille de documents)', () {
      final original = AttachedFile(
        name: 'cv.pdf',
        extension: 'pdf',
        sizeBytes: 2048,
        storagePath: 'org1/candidates/c1/cv.pdf',
        removedAt: DateTime(2026, 1, 5),
      );

      final decoded = AttachedFile.fromJson(original.toJson());

      expect(decoded.isRemoved, isTrue);
      expect(decoded.removedAt, original.removedAt);
    });
  });

  group('AttachedFile.copyWith', () {
    test('remplace bytes par les octets téléchargés', () {
      const original = AttachedFile(
        name: 'scan.jpg',
        extension: 'jpg',
        sizeBytes: 500,
        storagePath: 'org1/archives/arc1/scan.jpg',
      );
      final withBytes = original.copyWith(bytes: [1, 2, 3]);
      expect(withBytes.bytes, [1, 2, 3]);
      expect(withBytes.storagePath, original.storagePath);
    });

    test('un fichier neuf n\'est pas retiré (isRemoved == false)', () {
      const file = AttachedFile(name: 'a.pdf', extension: 'pdf', sizeBytes: 10);
      expect(file.isRemoved, isFalse);
    });

    test('removedAt marque le fichier comme retiré (corbeille)', () {
      const file = AttachedFile(name: 'a.pdf', extension: 'pdf', sizeBytes: 10);
      final removed = file.copyWith(removedAt: DateTime(2026, 1, 1));
      expect(removed.isRemoved, isTrue);
    });

    test('clearRemovedAt restaure le fichier (corbeille -> actif)', () {
      final removed = AttachedFile(
        name: 'a.pdf',
        extension: 'pdf',
        sizeBytes: 10,
        removedAt: DateTime(2026, 1, 1),
      );
      final restored = removed.copyWith(clearRemovedAt: true);
      expect(restored.isRemoved, isFalse);
      expect(restored.removedAt, isNull);
    });
  });
}
