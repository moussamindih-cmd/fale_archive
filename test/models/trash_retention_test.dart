import 'package:flutter_test/flutter_test.dart';
import 'package:creposa/models/candidate.dart';
import 'package:creposa/models/logistics_item.dart';

// Vérifie la logique de compte à rebours de la corbeille (7 jours), commune
// à Candidate et LogisticsItem — le même bug ici casserait la restauration
// silencieusement, comme cela a été le cas pour la persistance des fichiers.
void main() {
  group('Candidate.daysUntilDeletion', () {
    test('vaut 0 quand le candidat n\'est pas supprimé', () {
      final c = Candidate(
        id: 'c1',
        fullName: 'Awa Traoré',
        targetPosition: 'Comptable',
        applicationDate: DateTime.now(),
      );
      expect(c.daysUntilDeletion, 0);
    });

    test('vaut 7 juste après suppression', () {
      final c = Candidate(
        id: 'c1',
        fullName: 'Awa Traoré',
        targetPosition: 'Comptable',
        applicationDate: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      expect(c.daysUntilDeletion, 7);
    });

    test('décroît avec le temps écoulé depuis la suppression', () {
      final c = Candidate(
        id: 'c1',
        fullName: 'Awa Traoré',
        targetPosition: 'Comptable',
        applicationDate: DateTime.now(),
        deletedAt: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(c.daysUntilDeletion, 2);
    });

    test('ne devient jamais négatif après le délai de 7 jours', () {
      final c = Candidate(
        id: 'c1',
        fullName: 'Awa Traoré',
        targetPosition: 'Comptable',
        applicationDate: DateTime.now(),
        deletedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(c.daysUntilDeletion, 0);
    });
  });

  group('Candidate.copyWith clearDeletedAt', () {
    test('efface deletedAt uniquement quand clearDeletedAt est vrai', () {
      final deleted = Candidate(
        id: 'c1',
        fullName: 'Awa Traoré',
        targetPosition: 'Comptable',
        applicationDate: DateTime.now(),
        isDeleted: true,
        deletedAt: DateTime.now(),
      );

      final restored = deleted.copyWith(isDeleted: false, clearDeletedAt: true);

      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('sans clearDeletedAt, deletedAt est conservé', () {
      final deletedAt = DateTime(2026, 1, 1);
      final deleted = Candidate(
        id: 'c1',
        fullName: 'Awa Traoré',
        targetPosition: 'Comptable',
        applicationDate: DateTime.now(),
        deletedAt: deletedAt,
      );

      final unchanged = deleted.copyWith(fullName: 'Awa T.');

      expect(unchanged.deletedAt, deletedAt);
    });
  });

  group('LogisticsItem.daysUntilDeletion', () {
    test('vaut 0 quand le document n\'est pas supprimé', () {
      final item = LogisticsItem(
        id: 'l1',
        documentType: LogisticsDocType.facture,
        reference: 'FAC-1',
        supplier: 'Fournisseur A',
        issueDate: DateTime.now(),
        registeredById: 'u1',
        registeredByName: 'Bob',
      );
      expect(item.daysUntilDeletion, 0);
    });

    test('décroît avec le temps écoulé depuis la suppression', () {
      final item = LogisticsItem(
        id: 'l1',
        documentType: LogisticsDocType.facture,
        reference: 'FAC-1',
        supplier: 'Fournisseur A',
        issueDate: DateTime.now(),
        registeredById: 'u1',
        registeredByName: 'Bob',
        deletedAt: DateTime.now().subtract(const Duration(days: 6)),
      );
      expect(item.daysUntilDeletion, 1);
    });
  });

  group('LogisticsItem.copyWith clearDeletedAt', () {
    test('efface deletedAt uniquement quand clearDeletedAt est vrai', () {
      final deleted = LogisticsItem(
        id: 'l1',
        documentType: LogisticsDocType.facture,
        reference: 'FAC-1',
        supplier: 'Fournisseur A',
        issueDate: DateTime.now(),
        registeredById: 'u1',
        registeredByName: 'Bob',
        isDeleted: true,
        deletedAt: DateTime.now(),
      );

      final restored = deleted.copyWith(isDeleted: false, clearDeletedAt: true);

      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });
  });
}
