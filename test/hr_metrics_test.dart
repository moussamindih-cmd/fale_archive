import 'package:creposa/models/hr_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FunnelStep', () {
    test('lit un palier de l\'entonnoir', () {
      final step = FunnelStep.fromJson({
        'stage_id': 'st-2',
        'stage_code': 'preselectionnee',
        'stage_label': 'Présélectionnée',
        'position': 2,
        'is_terminal': false,
        'is_won': false,
        'reached_count': 5,
        'previous_count': 6,
        'conversion_rate_pct': 83.3,
      });
      expect(step.reachedCount, 5);
      expect(step.conversionRatePct, 83.3);
    });

    test('une étape terminale n\'a pas de conversion', () {
      // « Rejetée » ne succède pas à « Recrutée » : elle sort du parcours.
      // Les enchaîner produisait des taux supérieurs à 100 %.
      final step = FunnelStep.fromJson({
        'stage_id': 'st-7',
        'stage_code': 'rejetee',
        'stage_label': 'Rejetée',
        'position': 7,
        'is_terminal': true,
        'reached_count': 3,
      });
      expect(step.isTerminal, isTrue);
      expect(step.conversionRatePct, isNull);
    });
  });

  group('SourceMetric', () {
    test('lit une source avec son taux de réussite', () {
      final s = SourceMetric.fromJson({
        'source': 'cooptation',
        'total': 4,
        'hired': 1,
        'in_progress': 1,
        'success_rate_pct': 33.3,
      });
      expect(s.total, 4);
      expect(s.successRatePct, 33.3);
    });

    test('une source sans candidature close n\'a pas de taux', () {
      // Toutes ses candidatures sont en cours : lui attribuer 0 % la
      // condamnerait alors qu'elle n'a simplement pas encore abouti.
      final s = SourceMetric.fromJson({
        'source': 'spontanee',
        'total': 1,
        'hired': 0,
        'in_progress': 1,
      });
      expect(s.successRatePct, isNull);
    });
  });

  group('TimeToHireMetric', () {
    test('calcule l\'écart entre le plus rapide et le plus lent', () {
      final m = TimeToHireMetric.fromJson({
        'hires': 2,
        'avg_days': 45.0,
        'min_days': 40,
        'max_days': 50,
      });
      expect(m.avgDays, 45.0);
      expect(m.spread, 10,
          reason: 'une moyenne seule masque des parcours inégaux');
    });

    test('sans offre, il s\'agit de candidatures spontanées', () {
      final m = TimeToHireMetric.fromJson({
        'hires': 1, 'avg_days': 12.0, 'min_days': 12, 'max_days': 12,
      });
      expect(m.label, 'Candidatures spontanées');
    });
  });

  group('RetentionCompliance', () {
    test('un parc vide n\'est pas un parc non conforme', () {
      const c = RetentionCompliance.empty();
      expect(c.total, 0);
      expect(c.complianceRatePct, isNull);
      expect(c.needsAttention, 0);
    });

    test('les échues et les non classées demandent une décision', () {
      final c = RetentionCompliance.fromJson({
        'total': 4,
        'compliant': 1,
        'expiring_soon': 0,
        'expired': 1,
        'unclassified': 1,
        'legal_hold': 1,
        'purged': 0,
        'compliance_rate_pct': 50.0,
      });
      expect(c.complianceRatePct, 50.0);
      expect(c.needsAttention, 2);
    });

    test('le gel conservatoire compte comme conforme', () {
      // Une archive sous litige est échue mais légitimement conservée.
      final c = RetentionCompliance.fromJson({
        'total': 2, 'compliant': 1, 'expiring_soon': 0, 'expired': 0,
        'unclassified': 0, 'legal_hold': 1, 'purged': 0,
        'compliance_rate_pct': 100.0,
      });
      expect(c.complianceRatePct, 100.0);
      expect(c.needsAttention, 0);
    });
  });

  group('ArchiveVolumeMetric', () {
    ArchiveVolumeMetric of(int bytes) => ArchiveVolumeMetric(
          month: DateTime(2026, 8),
          archiveCount: 1,
          documentCount: 1,
          totalBytes: bytes,
        );

    test('formate la taille aux bornes des unités', () {
      expect(of(512).readableSize, '512 o');
      expect(of(1024).readableSize, '1.0 Ko');
      expect(of(1024 * 1024).readableSize, '1.0 Mo');
      expect(of(3 * 1024 * 1024).readableSize, '3.0 Mo');
      expect(of(1024 * 1024 * 1024).readableSize, '1.00 Go');
    });
  });

  group('DashboardSummary', () {
    test('lit la synthèse serveur', () {
      final s = DashboardSummary.fromJson({
        'open_applications': 1,
        'hires_this_year': 2,
        'avg_time_to_hire': 45.0,
        'published_offers': 3,
        'upcoming_interviews': 0,
        'archives_this_month': 7,
        'retention_compliance_pct': 91.5,
      });
      expect(s.openApplications, 1);
      expect(s.avgTimeToHire, 45.0);
      expect(s.retentionCompliancePct, 91.5);
    });

    test('sans recrutement, le délai moyen est nul et non zéro', () {
      // Afficher « 0 jour » laisserait croire à un recrutement instantané.
      final s = DashboardSummary.fromJson({
        'open_applications': 3,
        'hires_this_year': 0,
        'avg_time_to_hire': null,
      });
      expect(s.avgTimeToHire, isNull);
      expect(s.hiresThisYear, 0);
    });
  });
}
