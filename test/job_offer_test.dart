import 'package:creposa/models/job_offer.dart';
import 'package:creposa/models/user_role.dart';
import 'package:creposa/models/fale_permission.dart';
import 'package:flutter_test/flutter_test.dart';

JobOffer build({
  OfferWorkflowStatus workflow = OfferWorkflowStatus.brouillon,
  OfferLifecycleStatus lifecycle = OfferLifecycleStatus.active,
  bool isTemplate = false,
  DateTime? deadline,
  double? salaryMin,
  double? salaryMax,
  bool salaryVisible = false,
}) {
  return JobOffer(
    id: 'off-1',
    organizationId: 'org-a',
    reference: 'OFF-2026-001',
    title: 'Comptable senior',
    description: 'Tenue de la comptabilité générale',
    workflowStatus: workflow,
    lifecycleStatus: lifecycle,
    isTemplate: isTemplate,
    deadline: deadline,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    salaryVisible: salaryVisible,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

void main() {
  group('Workflow de validation (§5.2.2)', () {
    test('un brouillon ne peut aller qu\'en validation', () {
      expect(OfferWorkflowStatus.brouillon.allowedNext,
          {OfferWorkflowStatus.enValidation});
    });

    test('une offre en validation peut être publiée, rejetée ou renvoyée', () {
      expect(OfferWorkflowStatus.enValidation.allowedNext, {
        OfferWorkflowStatus.publiee,
        OfferWorkflowStatus.rejetee,
        OfferWorkflowStatus.brouillon,
      });
    });

    test('une offre rejetée repart en correction', () {
      expect(OfferWorkflowStatus.rejetee.allowedNext,
          {OfferWorkflowStatus.brouillon});
    });

    test('une offre publiée est un état terminal du workflow', () {
      // On la retire par le cycle de vie, ce qui préserve l'historique :
      // la faire redevenir brouillon effacerait la trace de sa publication.
      expect(OfferWorkflowStatus.publiee.allowedNext, isEmpty);
    });

    test('on ne peut jamais publier directement depuis un brouillon', () {
      expect(
        OfferWorkflowStatus.brouillon.allowedNext
            .contains(OfferWorkflowStatus.publiee),
        isFalse,
        reason: 'la validation interne ne doit pas être contournable',
      );
    });

    test('seuls brouillon et rejetée sont modifiables', () {
      expect(OfferWorkflowStatus.brouillon.isEditable, isTrue);
      expect(OfferWorkflowStatus.rejetee.isEditable, isTrue);
      expect(OfferWorkflowStatus.enValidation.isEditable, isFalse);
      expect(OfferWorkflowStatus.publiee.isEditable, isFalse);
    });
  });

  group('Visibilité publique (§5.2.4)', () {
    test('publiée et active : visible', () {
      expect(build(workflow: OfferWorkflowStatus.publiee).isPubliclyVisible,
          isTrue);
    });

    test('un brouillon n\'est jamais visible', () {
      expect(build().isPubliclyVisible, isFalse);
    });

    test('une offre suspendue disparaît', () {
      expect(
        build(
          workflow: OfferWorkflowStatus.publiee,
          lifecycle: OfferLifecycleStatus.suspendue,
        ).isPubliclyVisible,
        isFalse,
      );
    });

    test('une offre pourvue disparaît', () {
      expect(
        build(
          workflow: OfferWorkflowStatus.publiee,
          lifecycle: OfferLifecycleStatus.pourvue,
        ).isPubliclyVisible,
        isFalse,
      );
    });

    test('un modèle n\'est jamais visible, même marqué publié', () {
      expect(
        build(workflow: OfferWorkflowStatus.publiee, isTemplate: true)
            .isPubliclyVisible,
        isFalse,
      );
    });

    test('une échéance dépassée retire l\'offre', () {
      final expiree = build(
        workflow: OfferWorkflowStatus.publiee,
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiree.isExpired, isTrue);
      expect(expiree.isPubliclyVisible, isFalse);
    });

    test('une échéance du jour reste ouverte', () {
      final aujourdhui = build(
        workflow: OfferWorkflowStatus.publiee,
        deadline: DateTime.now(),
      );
      expect(aujourdhui.isExpired, isFalse);
      expect(aujourdhui.isPubliclyVisible, isTrue);
    });

    test('seule une offre visible et active accepte des candidatures', () {
      expect(build(workflow: OfferWorkflowStatus.publiee).acceptsApplications,
          isTrue);
      expect(build().acceptsApplications, isFalse);
    });
  });

  group('Salaire', () {
    test('non publié : rien ne sort', () {
      final o = build(salaryMin: 450000, salaryMax: 650000);
      expect(o.formattedSalary, isNull,
          reason: 'une fourchette interne ne doit pas fuir');
    });

    test('publié : fourchette formatée', () {
      final o =
          build(salaryMin: 450000, salaryMax: 650000, salaryVisible: true);
      expect(o.formattedSalary, '450 000 – 650 000 XAF');
    });

    test('borne unique', () {
      expect(build(salaryMin: 300000, salaryVisible: true).formattedSalary,
          '300 000 XAF');
      expect(build(salaryMax: 900000, salaryVisible: true).formattedSalary,
          '900 000 XAF');
    });

    test('aucun montant : null même si publié', () {
      expect(build(salaryVisible: true).formattedSalary, isNull);
    });
  });

  group('Échéance', () {
    test('daysUntilDeadline est null sans date limite', () {
      expect(build().daysUntilDeadline, isNull);
    });

    test('compte les jours restants', () {
      final o = build(deadline: DateTime.now().add(const Duration(days: 5)));
      expect(o.daysUntilDeadline, inInclusiveRange(4, 5));
    });

    test('négatif une fois dépassée', () {
      final o = build(deadline: DateTime.now().subtract(const Duration(days: 3)));
      expect(o.daysUntilDeadline, lessThan(0));
    });
  });

  group('Sérialisation', () {
    test('relit une ligne job_offers', () {
      final o = JobOffer.fromJson({
        'id': 'off-9',
        'organization_id': 'org-a',
        'reference': 'OFF-2026-009',
        'title': 'Assistant RH',
        'description': 'Appui au recrutement',
        'skills': ['Excel', 'Paie'],
        'contract_type': 'cdd',
        'positions_count': 2,
        'salary_min': 250000,
        'salary_visible': true,
        'workflow_status': 'en_validation',
        'lifecycle_status': 'suspendue',
        'deadline': '2026-12-31',
        'created_at': '2026-08-01T10:00:00.000Z',
        'updated_at': '2026-08-02T10:00:00.000Z',
      });

      expect(o.contractType, ContractType.cdd);
      expect(o.workflowStatus, OfferWorkflowStatus.enValidation);
      expect(o.lifecycleStatus, OfferLifecycleStatus.suspendue);
      expect(o.skills, ['Excel', 'Paie']);
      expect(o.positionsCount, 2);
      expect(o.deadline, DateTime(2026, 12, 31));
    });

    test('un code inconnu retombe sur une valeur sûre', () {
      expect(OfferWorkflowStatus.fromCode('inventé'),
          OfferWorkflowStatus.brouillon);
      expect(OfferLifecycleStatus.fromCode(null), OfferLifecycleStatus.active);
      expect(ContractType.fromCode('freelance'), ContractType.cdi);
    });

    test('toWritableJson n\'émet ni référence ni statut', () {
      // Ces champs sont attribués par la base : les envoyer permettrait de
      // court-circuiter le trigger de workflow.
      final json = build().toWritableJson();
      expect(json.containsKey('reference'), isFalse);
      expect(json.containsKey('workflow_status'), isFalse);
      expect(json.containsKey('lifecycle_status'), isFalse);
      expect(json.containsKey('published_at'), isFalse);
      expect(json['title'], 'Comptable senior');
    });
  });

  group('Droits sur les offres', () {
    test('les RH créent mais ne publient pas', () {
      expect(UserRole.rh.hasPermission(FalePermission.manageJobOffers), isTrue);
      expect(UserRole.rh.hasPermission(FalePermission.publishJobOffer), isFalse,
          reason: 'séparation des tâches : qui rédige ne valide pas');
    });

    test('le directeur administratif publie mais ne rédige pas', () {
      expect(
        UserRole.directeurAdministratif
            .hasPermission(FalePermission.publishJobOffer),
        isTrue,
      );
      expect(
        UserRole.directeurAdministratif
            .hasPermission(FalePermission.manageJobOffers),
        isFalse,
      );
    });

    test('un employé consulte seulement', () {
      expect(UserRole.employe.hasPermission(FalePermission.viewJobOffers),
          isTrue);
      expect(UserRole.employe.hasPermission(FalePermission.manageJobOffers),
          isFalse);
    });
  });
}
