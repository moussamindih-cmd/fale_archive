import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:creposa/services/data_export_service.dart';
import 'package:creposa/models/candidate.dart';
import 'package:creposa/models/logistics_item.dart';
import 'package:creposa/models/daily_archive.dart';
import 'package:creposa/models/attached_file.dart';
import 'package:creposa/models/action_history_entry.dart';

void main() {
  group('DataExportService.buildFullExportJson', () {
    test('produit un JSON valide contenant toutes les catégories', () async {
      final json = await DataExportService.buildFullExportJson(
        candidates: [],
        logisticsItems: [],
        archives: [],
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['exportVersion'], DataExportService.exportVersion);
      expect(decoded['exportedAt'], isNotNull);
      expect(decoded['candidates'], isEmpty);
      expect(decoded['logisticsItems'], isEmpty);
      expect(decoded['dailyArchives'], isEmpty);
    });

    test(
      "inclut l'historique complet et les métadonnées des fichiers d'un candidat "
      '(pas seulement les champs superficiels de Candidate.toJson)',
      () async {
        final candidate = Candidate(
          id: 'c1',
          fullName: 'Awa Traoré',
          targetPosition: 'Comptable',
          applicationDate: DateTime(2026, 1, 1),
          documents: const [
            AttachedFile(
              name: 'cv.pdf',
              extension: 'pdf',
              sizeBytes: 1234,
              storagePath: 'org1/candidates/c1/cv.pdf',
            ),
          ],
          history: [
            ActionHistoryEntry(
              userName: 'RH',
              action: 'CREATE',
              timestamp: DateTime(2026, 1, 1),
              details: 'Dossier créé.',
            ),
          ],
        );

        final json = await DataExportService.buildFullExportJson(
          candidates: [candidate],
          logisticsItems: [],
          archives: [],
        );
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final exported =
            (decoded['candidates'] as List).single as Map<String, dynamic>;

        expect(exported['fullName'], 'Awa Traoré');
        final document =
            (exported['documents'] as List).single as Map<String, dynamic>;
        expect(document['storagePath'], 'org1/candidates/c1/cv.pdf');
        expect(document['sizeBytes'], 1234);
        final history =
            (exported['history'] as List).single as Map<String, dynamic>;
        expect(history['action'], 'CREATE');
        expect(history['userName'], 'RH');
      },
    );

    test(
      'les enregistrements supprimés (corbeille) sont inclus, avec deletedAt',
      () async {
        final item = LogisticsItem(
          id: 'l1',
          documentType: LogisticsDocType.facture,
          reference: 'FAC-1',
          supplier: 'Fournisseur A',
          issueDate: DateTime(2026, 1, 1),
          registeredById: 'u1',
          registeredByName: 'Bob',
          isDeleted: true,
          deletedAt: DateTime(2026, 1, 5),
        );

        final json = await DataExportService.buildFullExportJson(
          candidates: [],
          logisticsItems: [item],
          archives: [],
        );
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final exported =
            (decoded['logisticsItems'] as List).single as Map<String, dynamic>;

        expect(exported['isDeleted'], isTrue);
        expect(exported['deletedAt'], isNotNull);
      },
    );

    test('les archives exportées portent bien leurs fichiers joints', () async {
      final archive = DailyArchive(
        id: 'a1',
        employeeId: 'e1',
        employeeName: 'Fatou',
        jobTitle: 'Secrétaire',
        archiveDate: DateTime(2026, 1, 1),
        title: 'Courriers du jour',
        summary: '',
        category: 'Courrier',
        documentCount: 1,
        files: const [
          AttachedFile(name: 'scan.jpg', extension: 'jpg', sizeBytes: 500),
        ],
        submittedAt: DateTime(2026, 1, 1),
      );

      final json = await DataExportService.buildFullExportJson(
        candidates: [],
        logisticsItems: [],
        archives: [archive],
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final exported =
          (decoded['dailyArchives'] as List).single as Map<String, dynamic>;

      expect((exported['files'] as List), hasLength(1));
    });
  });
}
