import 'package:flutter/material.dart';
import 'fale_permission.dart';

/// Rôle fonctionnel de l'utilisateur — distinct du poste métier (`jobTitle`).
///
/// Un *poste* (Secrétaire, Comptable, Gestionnaire, Conseiller…) décrit ce que
/// la personne fait ; un *rôle* décrit ce que l'application l'autorise à faire.
/// Les deux ne se confondent pas : deux comptables peuvent avoir des rôles
/// différents, et le poste sert uniquement à pré-classer les archives.
enum UserRole {
  /// Exploitant de la plateforme — traverse les organisations (§5.5.1).
  /// Seul rôle qui n'est pas rattaché à un client.
  superAdmin(
    label: 'Super Administrateur',
    shortLabel: 'Super Admin',
    color: Color(0xFF0F172A), // Obsidienne
    icon: Icons.shield_moon_rounded,
  ),
  admin(
    label: 'Administrateur',
    shortLabel: 'Admin',
    color: Color(0xFFDC2626), // Rouge rubis
    icon: Icons.admin_panel_settings_rounded,
  ),
  directeurAdministratif(
    label: 'Directeur Administratif',
    shortLabel: 'Dir. Admin',
    color: Color(0xFF7C3AED), // Violet profond
    icon: Icons.account_balance_rounded,
  ),
  rh(
    label: 'Ressources Humaines',
    shortLabel: 'RH',
    color: Color(0xFFEC4899), // Rose fuchsia
    icon: Icons.people_alt_rounded,
  ),
  employe(
    label: 'Employé',
    shortLabel: 'Employé',
    color: Color(0xFF2563EB), // Bleu royal
    icon: Icons.badge_rounded,
  );

  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;

  const UserRole({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.icon,
  });

  /// Ensemble de droits accordés au rôle.
  ///
  /// Cette matrice est la référence côté client — elle pilote l'affichage.
  /// Elle **ne remplace pas** les politiques RLS : le serveur reste seul juge,
  /// et toute règle ajoutée ici doit avoir son équivalent en base.
  Set<FalePermission> get permissions {
    switch (this) {
      case UserRole.superAdmin:
        return FalePermission.values.toSet();

      case UserRole.admin:
        // Tout sauf l'exploitation multi-entreprises, réservée à la plateforme.
        return FalePermission.values
            .where((p) => p != FalePermission.manageOrganizations)
            .toSet();

      case UserRole.directeurAdministratif:
        return {
          FalePermission.viewArchives,
          FalePermission.viewAllArchives,
          FalePermission.downloadDocument,
          FalePermission.exportArchives,
          FalePermission.viewJobOffers,
          FalePermission.publishJobOffer,
          FalePermission.viewCandidates,
          FalePermission.viewLogistics,
          FalePermission.validateLogistics,
          FalePermission.viewReports,
          FalePermission.exportReports,
          FalePermission.viewActivityLog,
          FalePermission.viewAuditTrail,
        };

      case UserRole.rh:
        return {
          FalePermission.viewArchives,
          FalePermission.viewAllArchives,
          FalePermission.downloadDocument,
          FalePermission.viewJobOffers,
          FalePermission.manageJobOffers,
          FalePermission.viewCandidates,
          FalePermission.manageCandidates,
          FalePermission.moveApplication,
          FalePermission.rateApplication,
          FalePermission.scheduleInterview,
          FalePermission.viewReports,
          FalePermission.exportReports,
        };

      case UserRole.employe:
        return {
          FalePermission.viewArchives,
          FalePermission.viewAllArchives,
          FalePermission.submitArchive,
          FalePermission.editArchive,
          FalePermission.downloadDocument,
          FalePermission.viewJobOffers,
        };
    }
  }

  bool hasPermission(FalePermission permission) =>
      permissions.contains(permission);

  /// Vrai si le rôle détient **au moins un** des droits demandés.
  bool hasAnyPermission(Iterable<FalePermission> required) =>
      required.any(permissions.contains);

  /// Rôle encadrant — utilisé pour les vues « toute l'équipe ».
  bool get isSupervisor => this != UserRole.employe;

  /// Rôle traversant les organisations. Seul le super administrateur
  /// échappe au cloisonnement par tenant.
  bool get isCrossTenant => this == UserRole.superAdmin;

  /// Lecture d'un rôle persisté. Retombe sur [UserRole.employe] — le rôle le
  /// moins privilégié — si la valeur est inconnue ou absente.
  static UserRole fromName(String? name) {
    if (name == null) return UserRole.employe;
    for (final role in UserRole.values) {
      if (role.name == name) return role;
    }
    return UserRole.employe;
  }
}
