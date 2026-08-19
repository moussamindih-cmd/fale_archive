import 'permission.dart';

class Role {
  final String id;
  final String name;
  final String description;
  final Set<AppPermission> permissions;

  const Role({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
  });

  bool hasPermission(AppPermission permission) {
    return permissions.contains(permission);
  }

  static const Role superAdmin = Role(
    id: 'role_super_admin',
    name: 'Super Administrateur',
    description: 'Accès total à toutes les fonctionnalités et organisations',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.deleteDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
      AppPermission.manageUsers,
      AppPermission.manageRoles,
      AppPermission.viewAudit,
      AppPermission.manageSettings,
      AppPermission.manageDepartments,
      AppPermission.manageCategories,
      AppPermission.manageSubscriptions,
    },
  );

  static const Role administrator = Role(
    id: 'role_admin',
    name: 'Administrateur',
    description: 'Gestion des utilisateurs, paramètres, archives et rapports',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.deleteDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
      AppPermission.manageUsers,
      AppPermission.manageRoles,
      AppPermission.viewAudit,
      AppPermission.manageSettings,
      AppPermission.manageDepartments,
      AppPermission.manageCategories,
    },
  );

  static const Role archivist = Role(
    id: 'role_archivist',
    name: 'Archiviste',
    description: 'Ajouter, classer, modifier, rechercher et archiver des documents',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
    },
  );

  static const Role consultant = Role(
    id: 'role_consultant',
    name: 'Consultant',
    description: 'Consulter et télécharger les archives autorisées',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.downloadDocument,
    },
  );

  static const Role auditor = Role(
    id: 'role_auditor',
    name: 'Auditeur',
    description: 'Consulter les logs et les rapports en lecture seule',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.viewAudit,
    },
  );

  static const Role secretaire = Role(
    id: 'role_secretaire',
    name: 'Secrétaire',
    description: 'Enregistrement des courriers et numérisation des archives journalières',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
    },
  );

  static const Role comptable = Role(
    id: 'role_comptable',
    name: 'Comptable',
    description: 'Versement quotidien des pièces comptables, factures et journaux de caisse',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
    },
  );

  static const Role gestionnaire = Role(
    id: 'role_gestionnaire',
    name: 'Gestionnaire',
    description: 'Archivage quotidien des dossiers opérationnels et de gestion',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
    },
  );

  static const Role conseillerPrincipal = Role(
    id: 'role_conseiller_principal',
    name: 'Conseiller Principal',
    description: 'Versement quotidien des avis stratégiques, expertises et rapports du jour',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
    },
  );

  static const Role conseillerAdjoint = Role(
    id: 'role_conseiller_adjoint',
    name: 'Conseiller Adjoint',
    description: 'Versement quotidien des notes de synthèse, comptes-rendus et projets du jour',
    permissions: {
      AppPermission.viewDocument,
      AppPermission.createDocument,
      AppPermission.updateDocument,
      AppPermission.downloadDocument,
      AppPermission.shareDocument,
    },
  );
}
