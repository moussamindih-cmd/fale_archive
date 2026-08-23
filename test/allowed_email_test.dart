import 'package:creposa/models/allowed_email.dart';
import 'package:creposa/models/signup_rules.dart';
import 'package:creposa/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  String email = 'bob@acme.test',
  String role = 'employe',
  String jobTitle = 'Comptable',
  String status = 'pending',
  String? fullName,
  String? claimedAt,
}) {
  return {
    'id': 'ae-1',
    'organization_id': 'org-a',
    'email': email,
    'full_name': fullName,
    'role': role,
    'job_title': jobTitle,
    'status': status,
    'invited_by': 'admin-1',
    'claimed_by': claimedAt == null ? null : 'emp-9',
    'claimed_at': claimedAt,
    'created_at': '2026-08-23T10:00:00.000Z',
  };
}

void main() {
  group('AllowedEmailStatus', () {
    test('relit chaque statut par son code persisté', () {
      for (final status in AllowedEmailStatus.values) {
        expect(AllowedEmailStatus.fromCode(status.code), status);
      }
    });

    test('un statut inconnu retombe sur révoqué, jamais sur en attente', () {
      // Un statut illisible ne doit pas rouvrir une inscription : on retombe
      // sur le plus restrictif.
      expect(AllowedEmailStatus.fromCode('n_importe_quoi'),
          AllowedEmailStatus.revoked);
      expect(AllowedEmailStatus.fromCode(null), AllowedEmailStatus.revoked);
    });
  });

  group('AllowedEmail.fromJson', () {
    test('lit une ligne complète', () {
      final entry = AllowedEmail.fromJson(_row(fullName: 'Bob Diallo'));
      expect(entry.email, 'bob@acme.test');
      expect(entry.fullName, 'Bob Diallo');
      expect(entry.role, UserRole.employe);
      expect(entry.jobTitle, 'Comptable');
      expect(entry.status, AllowedEmailStatus.pending);
      expect(entry.organizationId, 'org-a');
    });

    test('un rôle superAdmin persisté est rabattu sur admin', () {
      // La contrainte `allowed_emails_role_check` l'interdit en base, mais une
      // ligne écrite hors application ne doit pas non plus le faire remonter :
      // le super administrateur traverse les organisations.
      final entry = AllowedEmail.fromJson(_row(role: 'superAdmin'));
      expect(entry.role, UserRole.admin);
    });

    test('un rôle inconnu retombe sur employé', () {
      expect(AllowedEmail.fromJson(_row(role: 'sorcier')).role,
          UserRole.employe);
    });

    test('une entrée sans poste ni nom reste lisible', () {
      final entry = AllowedEmail.fromJson(_row(role: 'rh', jobTitle: ''));
      expect(entry.fullName, isNull);
      expect(entry.jobTitle, '');
      expect(entry.displayRole, UserRole.rh.label);
    });
  });

  group('AllowedEmail — règles métier', () {
    test('seule une entrée en attente peut donner un compte', () {
      expect(AllowedEmail.fromJson(_row()).isClaimable, isTrue);
      expect(
        AllowedEmail.fromJson(
          _row(status: 'registered', claimedAt: '2026-08-23T12:00:00.000Z'),
        ).isClaimable,
        isFalse,
      );
      expect(AllowedEmail.fromJson(_row(status: 'revoked')).isClaimable,
          isFalse);
    });

    test('une entrée déjà consommée ne s\'efface pas, elle se révoque', () {
      final registered = AllowedEmail.fromJson(
        _row(status: 'registered', claimedAt: '2026-08-23T12:00:00.000Z'),
      );
      expect(registered.isDeletable, isFalse);
      expect(AllowedEmail.fromJson(_row()).isDeletable, isTrue);
      expect(AllowedEmail.fromJson(_row(status: 'revoked')).isDeletable, isTrue);
    });

    test('displayRole montre le poste pour un employé, le rôle sinon', () {
      expect(AllowedEmail.fromJson(_row()).displayRole, 'Comptable');
      expect(AllowedEmail.fromJson(_row(role: 'rh', jobTitle: '')).displayRole,
          UserRole.rh.label);
    });
  });

  group('Règles d\'inscription', () {
    test('un domaine grand public est refusé à une entreprise', () {
      for (final domain in ['gmail.com', 'yahoo.fr', 'orange.fr']) {
        expect(isFreeEmailDomain('contact@$domain'), isTrue,
            reason: domain);
      }
      expect(isFreeEmailDomain('contact@acme.test'), isFalse);
    });

    test('la comparaison de domaine ignore la casse et les espaces', () {
      expect(domainOf('  Admin@ACME.test '), 'acme.test');
      expect(domainOf('contact@acme.test'), domainOf('ADMIN@Acme.Test'));
    });

    test('une adresse sans @ n\'a pas de domaine', () {
      expect(domainOf('pas-une-adresse'), '');
    });

    test('le sous-domaine ne se confond pas avec le domaine', () {
      // `admin@mail.acme.test` ne doit pas passer pour `acme.test` : sinon
      // qui contrôle un sous-domaine revendiquerait le tenant parent.
      expect(domainOf('admin@mail.acme.test') == 'acme.test', isFalse);
    });

    test('isValidEmail accepte une adresse ordinaire et rejette le reste', () {
      expect(isValidEmail('bob@acme.test'), isTrue);
      expect(isValidEmail('bob@acme'), isFalse);
      expect(isValidEmail('bob acme.test'), isFalse);
      expect(isValidEmail(''), isFalse);
    });

    test('normalizeEmail met en minuscules et coupe les espaces', () {
      expect(normalizeEmail('  Bob@Acme.Test  '), 'bob@acme.test');
    });
  });
}
