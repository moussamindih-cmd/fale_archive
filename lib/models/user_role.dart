import 'package:flutter/material.dart';
import 'fale_permission.dart';

/// Rôle fonctionnel de l'utilisateur — distinct du poste métier (jobTitle)
enum UserRole {
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

  /// Ensemble de permissions accordées au rôle
  Set<FalePermission> get permissions {
    switch (this) {
      case UserRole.admin:
        return FalePermission.values.toSet();
      case UserRole.directeurAdministratif:
        return {
          FalePermission.viewArchives,
          FalePermission.viewAllArchives,
          FalePermission.viewCandidates,
          FalePermission.viewLogistics,
          FalePermission.validateLogistics,
          FalePermission.viewActivityLog,
        };
      case UserRole.rh:
        return {
          FalePermission.viewArchives,
          FalePermission.viewAllArchives,
          FalePermission.manageCandidates,
          FalePermission.viewCandidates,
        };
      case UserRole.employe:
        return {
          FalePermission.viewArchives,
          FalePermission.submitArchive,
          FalePermission.viewAllArchives,
        };
    }
  }

  /// Vérifie si le rôle possède une permission
  bool hasPermission(FalePermission permission) {
    return permissions.contains(permission);
  }
}
