import 'package:creposa/services/retention_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetentionService.dueDateFor', () {
    test('ajoute des années calendaires, pas des tranches de 365 jours', () {
      // 10 ans à partir de 2020 traversent 2020 et 2024, deux années
      // bissextiles. Un calcul en 10 * 365 jours tomberait le 28/06/2030.
      final due = RetentionService.dueDateFor(DateTime(2020, 6, 30), 10);
      expect(due, DateTime(2030, 6, 30));
    });

    test('ramène le 29 février au 28 quand l\'échéance n\'est pas bissextile', () {
      final due = RetentionService.dueDateFor(DateTime(2024, 2, 29), 1);
      expect(due, DateTime(2025, 2, 28));
    });

    test('conserve le 29 février quand l\'échéance est bissextile', () {
      final due = RetentionService.dueDateFor(DateTime(2024, 2, 29), 4);
      expect(due, DateTime(2028, 2, 29));
    });

    test('une durée nulle échoit le jour même', () {
      final due = RetentionService.dueDateFor(DateTime(2026, 8, 21), 0);
      expect(due, DateTime(2026, 8, 21));
    });
  });

  group('RetentionService.evaluate', () {
    const destroyRule = RetentionRule(
      id: 'r1',
      label: 'Pièces comptables',
      retentionYears: 10,
      warningDays: 90,
      action: RetentionAction.destroy,
    );

    test('archive récente : conservation en cours', () {
      final result = RetentionService.evaluate(
        archivedAt: DateTime(2026, 1, 1),
        rule: destroyRule,
        now: DateTime(2026, 8, 21),
      );
      expect(result.status, RetentionStatus.active);
      expect(result.isPurgeable, isFalse);
    });

    test('dans le préavis : échéance proche', () {
      // Échéance au 01/01/2036, préavis de 90 jours → alerte dès le 03/10/2035.
      final result = RetentionService.evaluate(
        archivedAt: DateTime(2026, 1, 1),
        rule: destroyRule,
        now: DateTime(2035, 11, 1),
      );
      expect(result.status, RetentionStatus.expiringSoon);
      expect(result.isPurgeable, isFalse);
    });

    test('échue avec action destroy : purgeable', () {
      final result = RetentionService.evaluate(
        archivedAt: DateTime(2026, 1, 1),
        rule: destroyRule,
        now: DateTime(2036, 1, 2),
      );
      expect(result.status, RetentionStatus.toDestroy);
      expect(result.isPurgeable, isTrue);
    });

    test('échue avec action review : échue mais jamais purgée', () {
      final result = RetentionService.evaluate(
        archivedAt: DateTime(2026, 1, 1),
        rule: const RetentionRule(
          id: 'r2',
          label: 'Dossiers RH',
          retentionYears: 5,
          action: RetentionAction.review,
        ),
        now: DateTime(2036, 1, 2),
      );
      expect(result.status, RetentionStatus.expired);
      expect(result.isPurgeable, isFalse);
    });

    test('le gel conservatoire prime sur une échéance dépassée', () {
      final result = RetentionService.evaluate(
        archivedAt: DateTime(2000, 1, 1),
        rule: destroyRule,
        legalHold: true,
        now: DateTime(2026, 8, 21),
      );
      expect(result.status, RetentionStatus.legalHold);
      expect(result.isPurgeable, isFalse,
          reason: 'une archive sous gel ne doit jamais être détruite');
    });

    test('sans règle, la valeur par défaut est en revue manuelle', () {
      final result = RetentionService.evaluate(
        archivedAt: DateTime(2000, 1, 1),
        now: DateTime(2026, 8, 21),
      );
      expect(result.status, RetentionStatus.expired);
      expect(result.isPurgeable, isFalse,
          reason: 'sans base légale explicite, rien ne se détruit tout seul');
    });

    test('l\'heure de la journée n\'influe pas sur le décompte', () {
      final matin = RetentionService.evaluate(
        archivedAt: DateTime(2026, 1, 1, 8, 30),
        rule: destroyRule,
        now: DateTime(2026, 8, 21, 6),
      );
      final soir = RetentionService.evaluate(
        archivedAt: DateTime(2026, 1, 1, 23, 45),
        rule: destroyRule,
        now: DateTime(2026, 8, 21, 22),
      );
      expect(matin.daysRemaining, soir.daysRemaining);
    });
  });

  group('RetentionService.complianceRate', () {
    RetentionAssessment of(RetentionStatus status) => RetentionAssessment(
          status: status,
          dueDate: DateTime(2030),
          daysRemaining: 0,
          action: RetentionAction.review,
        );

    test('un parc vide est réputé conforme', () {
      expect(RetentionService.complianceRate([]), 1);
    });

    test('les archives échues laissées en l\'état sont non conformes', () {
      final rate = RetentionService.complianceRate([
        of(RetentionStatus.active),
        of(RetentionStatus.expiringSoon),
        of(RetentionStatus.expired),
        of(RetentionStatus.toDestroy),
      ]);
      expect(rate, 0.5);
    });

    test('le gel conservatoire compte comme conforme', () {
      final rate = RetentionService.complianceRate([
        of(RetentionStatus.legalHold),
        of(RetentionStatus.active),
      ]);
      expect(rate, 1);
    });
  });

  group('RetentionRule', () {
    test('lit une ligne document_types et retombe sur des valeurs sûres', () {
      final rule = RetentionRule.fromJson({
        'id': 'dt-1',
        'label': 'Contrats',
        'retention_years': 30,
        'warning_days': 180,
        'retention_action': 'archive',
        'legal_basis': 'Code du travail, art. L.1234',
      });
      expect(rule.retentionYears, 30);
      expect(rule.action, RetentionAction.archive);
      expect(rule.legalBasis, isNotNull);
    });

    test('une action inconnue retombe en revue manuelle', () {
      final rule = RetentionRule.fromJson({'id': 'x', 'label': 'X'});
      expect(rule.action, RetentionAction.review);
      expect(rule.retentionYears, 10);
    });
  });
}
