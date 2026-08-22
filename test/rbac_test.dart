import 'package:creposa/core/security/security_gate.dart';
import 'package:creposa/models/employee.dart';
import 'package:creposa/models/fale_permission.dart';
import 'package:creposa/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _employee({
  String id = 'emp-1',
  UserRole role = UserRole.employe,
  String organizationId = 'org-a',
}) {
  return Employee(
    id: id,
    fullName: 'Awa Sow',
    email: 'a.sow@faleholding.com',
    password: '',
    jobTitle: 'Secrétaire',
    role: role,
    organizationId: organizationId,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('UserRole.fromName', () {
    test('relit chaque rôle par son nom persisté', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromName(role.name), role);
      }
    });

    test('un rôle inconnu retombe sur le moins privilégié', () {
      expect(UserRole.fromName('sorcier'), UserRole.employe);
      expect(UserRole.fromName(null), UserRole.employe);
      expect(UserRole.fromName(''), UserRole.employe);
    });
  });

  group('Matrice des droits', () {
    test('le super administrateur détient tous les droits', () {
      expect(
        UserRole.superAdmin.permissions,
        containsAll(FalePermission.values),
      );
    });

    test("l'administrateur n'administre pas les autres entreprises", () {
      expect(
        UserRole.admin.hasPermission(FalePermission.manageOrganizations),
        isFalse,
        reason: 'la gestion multi-entreprises appartient à la plateforme',
      );
      expect(UserRole.admin.hasPermission(FalePermission.manageUsers), isTrue);
    });

    test("l'employé ne peut ni valider ni administrer", () {
      const interdits = [
        FalePermission.validateLogistics,
        FalePermission.manageUsers,
        FalePermission.manageRoles,
        FalePermission.publishJobOffer,
        FalePermission.manageCandidates,
        FalePermission.viewAuditTrail,
      ];
      for (final droit in interdits) {
        expect(UserRole.employe.hasPermission(droit), isFalse,
            reason: 'employe ne doit pas détenir ${droit.code}');
      }
    });

    test('les RH pilotent le recrutement sans toucher à la logistique', () {
      expect(UserRole.rh.hasPermission(FalePermission.manageCandidates), isTrue);
      expect(UserRole.rh.hasPermission(FalePermission.scheduleInterview), isTrue);
      expect(UserRole.rh.hasPermission(FalePermission.manageLogistics), isFalse);
    });

    test('le directeur administratif valide sans pouvoir créer', () {
      expect(
        UserRole.directeurAdministratif
            .hasPermission(FalePermission.validateLogistics),
        isTrue,
      );
      expect(
        UserRole.directeurAdministratif
            .hasPermission(FalePermission.manageLogistics),
        isFalse,
        reason: 'séparation des tâches : qui saisit ne valide pas',
      );
    });

    test('seul le super administrateur traverse les organisations', () {
      expect(UserRole.superAdmin.isCrossTenant, isTrue);
      for (final role in UserRole.values.where((r) => r != UserRole.superAdmin)) {
        expect(role.isCrossTenant, isFalse);
      }
    });

    test('hasAnyPermission accepte dès qu\'un droit est détenu', () {
      expect(
        UserRole.employe.hasAnyPermission(
          [FalePermission.manageUsers, FalePermission.submitArchive],
        ),
        isTrue,
      );
      expect(
        UserRole.employe.hasAnyPermission([FalePermission.manageUsers]),
        isFalse,
      );
    });
  });

  group('FalePermission.fromCode', () {
    test('les codes sont stables et uniques', () {
      final codes = FalePermission.values.map((p) => p.code).toList();
      expect(codes.toSet().length, codes.length,
          reason: 'un code dupliqué rendrait la relecture ambiguë');
    });

    test('relit chaque droit par son code', () {
      for (final permission in FalePermission.values) {
        expect(FalePermission.fromCode(permission.code), permission);
      }
    });

    test('un code retiré ne fait pas planter la relecture', () {
      expect(FalePermission.fromCode('droit_supprime_en_v1'), isNull);
    });
  });

  group('SecurityGate', () {
    late SecurityGate gate;
    late List<SecurityViolation> violations;

    setUp(() {
      gate = SecurityGate.instance;
      violations = [];
      gate.onViolation = (violation, _) => violations.add(violation);
    });

    tearDown(() => gate.onViolation = null);

    test('accorde l\'accès à une ressource de sa propre organisation', () {
      final allowed = gate.canExecute(
        user: _employee(role: UserRole.rh),
        targetOrganizationId: 'org-a',
        requiredPermission: FalePermission.manageCandidates,
        actionName: 'modifier',
        resourceName: 'candidat',
      );
      expect(allowed, isTrue);
      expect(violations, isEmpty);
    });

    test('refuse et journalise un accès à une autre organisation', () {
      final allowed = gate.canExecute(
        user: _employee(role: UserRole.admin, organizationId: 'org-a'),
        targetOrganizationId: 'org-b',
        requiredPermission: FalePermission.viewArchives,
        actionName: 'consulter',
        resourceName: 'archive',
      );
      expect(allowed, isFalse);
      expect(violations, [SecurityViolation.crossTenant]);
    });

    test('le cloisonnement est vérifié avant le droit', () {
      // L'employé n'a pas le droit demandé ET vise une autre organisation :
      // c'est la violation la plus grave qui doit être remontée.
      gate.canExecute(
        user: _employee(organizationId: 'org-a'),
        targetOrganizationId: 'org-b',
        requiredPermission: FalePermission.manageUsers,
        actionName: 'supprimer',
        resourceName: 'utilisateur',
      );
      expect(violations, [SecurityViolation.crossTenant]);
    });

    test('le super administrateur franchit le cloisonnement', () {
      final allowed = gate.canExecute(
        user: _employee(role: UserRole.superAdmin, organizationId: 'org-a'),
        targetOrganizationId: 'org-b',
        requiredPermission: FalePermission.manageOrganizations,
        actionName: 'administrer',
        resourceName: 'organisation',
      );
      expect(allowed, isTrue);
      expect(violations, isEmpty);
    });

    test('refuse un droit manquant dans sa propre organisation', () {
      final allowed = gate.canExecute(
        user: _employee(),
        targetOrganizationId: 'org-a',
        requiredPermission: FalePermission.manageUsers,
        actionName: 'créer',
        resourceName: 'utilisateur',
      );
      expect(allowed, isFalse);
      expect(violations, [SecurityViolation.missingPermission]);
    });

    test('refuse sans session active', () {
      final allowed = gate.canExecute(
        user: null,
        requiredPermission: FalePermission.viewArchives,
        actionName: 'consulter',
        resourceName: 'archive',
      );
      expect(allowed, isFalse);
      expect(violations, [SecurityViolation.notAuthenticated]);
    });

    test('enforce exécute l\'action quand l\'accès est accordé', () {
      var executed = false;
      gate.enforce<void>(
        user: _employee(role: UserRole.admin),
        targetOrganizationId: 'org-a',
        requiredPermission: FalePermission.manageUsers,
        actionName: 'créer',
        resourceName: 'utilisateur',
        action: () => executed = true,
      );
      expect(executed, isTrue);
    });

    test('enforce lève et n\'exécute rien quand l\'accès est refusé', () {
      var executed = false;
      expect(
        () => gate.enforce<void>(
          user: _employee(),
          targetOrganizationId: 'org-a',
          requiredPermission: FalePermission.manageUsers,
          actionName: 'créer',
          resourceName: 'utilisateur',
          action: () => executed = true,
        ),
        throwsA(isA<SecurityException>()),
      );
      expect(executed, isFalse);
    });
  });

  group('Employee', () {
    test('can() délègue à la matrice du rôle', () {
      final rh = _employee(role: UserRole.rh);
      expect(rh.can(FalePermission.manageCandidates), isTrue);
      expect(rh.can(FalePermission.validateLogistics), isFalse);
    });

    test('isSupervisor exclut le seul rôle employé', () {
      expect(_employee(role: UserRole.employe).isSupervisor, isFalse);
      expect(_employee(role: UserRole.rh).isSupervisor, isTrue);
      expect(_employee(role: UserRole.superAdmin).isSupervisor, isTrue);
    });
  });
}
