import 'package:creposa/models/attached_file.dart';
import 'package:creposa/models/daily_archive.dart';
import 'package:flutter_test/flutter_test.dart';

DailyArchive build({
  List<AttachedFile> files = const [],
  String physicalLocation = '',
  DateTime? deletedAt,
  List<String> keywords = const [],
  String jobTitle = 'Secrétaire',
}) {
  return DailyArchive(
    id: 'arc_1750000000',
    employeeId: 'emp-1',
    employeeName: 'Awa Sow',
    jobTitle: jobTitle,
    archiveDate: DateTime(2026, 8, 21),
    title: 'Courriers du jour',
    summary: 'Traitement du courrier entrant',
    category: 'Courriers',
    documentCount: files.length,
    files: files,
    physicalLocation: physicalLocation,
    keywords: keywords,
    submittedAt: DateTime(2026, 8, 21, 17, 30),
    deletedAt: deletedAt,
  );
}

const _piece = AttachedFile(
  name: 'courrier.pdf',
  extension: 'pdf',
  sizeBytes: 2048,
  storagePath: 'org-a/archives/arc_1750000000/1-courrier.pdf',
);

void main() {
  group('copyWith — régressions', () {
    test('conserve les pièces jointes', () {
      // Régression : copyWith n'acceptait ni ne repropageait `files`,
      // donc toute copie perdait silencieusement les pièces.
      final origine = build(files: const [_piece]);
      final copie = origine.copyWith(title: 'Nouveau titre');

      expect(copie.files, hasLength(1));
      expect(copie.files.first.name, 'courrier.pdf');
      expect(copie.title, 'Nouveau titre');
    });

    test("conserve l'emplacement physique", () {
      final origine = build(physicalLocation: 'Armoire B > Rayon 2 > Boîte 14');
      final copie = origine.copyWith(summary: 'Résumé corrigé');

      expect(copie.physicalLocation, 'Armoire B > Rayon 2 > Boîte 14');
    });

    test('permet de vider deletedAt — restauration depuis la corbeille', () {
      // Régression : `deletedAt ?? this.deletedAt` ne pouvait jamais
      // remettre le champ à null, donc restaurer était impossible.
      final supprimee = build(deletedAt: DateTime(2026, 8, 20));
      expect(supprimee.isInTrash, isTrue);

      final restauree = supprimee.copyWith(deletedAt: null);
      expect(restauree.isInTrash, isFalse);
      expect(restauree.deletedAt, isNull);
    });

    test('ne touche pas deletedAt quand il n\'est pas passé', () {
      final supprimee = build(deletedAt: DateTime(2026, 8, 20));
      final copie = supprimee.copyWith(title: 'Autre');

      expect(copie.deletedAt, DateTime(2026, 8, 20));
    });

    test('conserve tous les champs non fournis', () {
      final origine = build(
        files: const [_piece],
        physicalLocation: 'Armoire A',
        keywords: const ['courrier', 'préfecture'],
      );
      final copie = origine.copyWith(title: 'X');

      expect(copie.employeeId, origine.employeeId);
      expect(copie.archiveDate, origine.archiveDate);
      expect(copie.summary, origine.summary);
      expect(copie.keywords, origine.keywords);
      expect(copie.submittedAt, origine.submittedAt);
      expect(copie.files, origine.files);
      expect(copie.physicalLocation, origine.physicalLocation);
    });
  });

  group('Sérialisation', () {
    test('aller-retour sans perte, pièces jointes comprises', () {
      final origine = build(
        files: const [_piece],
        physicalLocation: 'Armoire B',
        keywords: const ['courrier'],
      );
      final relu = DailyArchive.fromJson(origine.toJson());

      expect(relu.id, origine.id);
      expect(relu.title, origine.title);
      expect(relu.category, origine.category);
      expect(relu.keywords, origine.keywords);
      expect(relu.physicalLocation, origine.physicalLocation);
      // Régression : toJson n'émettait pas les pièces, la sérialisation
      // était incomplète et le service devait les gérer séparément.
      expect(relu.files, hasLength(1));
      expect(relu.files.first.storagePath, _piece.storagePath);
    });

    test('les clés sont en snake_case, alignées sur la base', () {
      final json = build().toJson();
      expect(json.containsKey('archive_date'), isTrue);
      expect(json.containsKey('document_count'), isTrue);
      expect(json.containsKey('physical_location'), isTrue);
      expect(json.containsKey('submitted_at'), isTrue);
      // L'ancienne sérialisation mélangeait snake_case et camelCase.
      expect(json.containsKey('archiveDate'), isFalse);
      expect(json.containsKey('documentCount'), isFalse);
    });

    test('relit une archive écrite avec l\'ancien format camelCase', () {
      final ancienne = DailyArchive.fromJson({
        'id': 'arc_1',
        'employee_id': 'emp-1',
        'employee_name': 'Awa Sow',
        'job_title': 'Comptable',
        'archiveDate': '2026-08-21T00:00:00.000',
        'title': 'Pièces de caisse',
        'summary': '',
        'category': 'Comptable',
        'documentCount': 3,
        'physicalLocation': 'Armoire C',
        'submittedAt': '2026-08-21T17:30:00.000',
      });

      expect(ancienne.documentCount, 3);
      expect(ancienne.physicalLocation, 'Armoire C');
      expect(ancienne.archiveDate, DateTime(2026, 8, 21));
    });
  });

  group('Références et état', () {
    test('le préfixe de référence suit le poste', () {
      expect(build(jobTitle: 'Secrétaire').reference, 'SEC-21082026');
      expect(build(jobTitle: 'Comptable').reference, 'COMPTA-21082026');
      expect(build(jobTitle: 'Conseiller Principal').reference, 'CONS-P-21082026');
      expect(build(jobTitle: 'Stagiaire').reference, 'ARC-21082026');
    });

    test('daysUntilDeletion vaut 0 hors corbeille et ne descend jamais sous 0', () {
      expect(build().daysUntilDeletion, 0);
      final vieille = build(deletedAt: DateTime(2020, 1, 1));
      expect(vieille.daysUntilDeletion, 0);
    });

    test('une archive purgée est signalée comme telle', () {
      final purgee = build().copyWith(purgedAt: DateTime(2026, 8, 22));
      expect(purgee.isPurged, isTrue);
      expect(build().isPurged, isFalse);
    });
  });
}
