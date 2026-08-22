/// Permissions spécifiques au système FALE Archives
enum FalePermission {
  // Archives
  viewArchives('view_archives', 'Consulter les archives'),
  submitArchive('submit_archive', 'Soumettre une archive journalière'),
  viewAllArchives(
    'view_all_archives',
    'Voir toutes les archives (tous postes)',
  ),

  // Candidats
  manageCandidates('manage_candidates', 'Gérer les dossiers candidats (CRUD)'),
  viewCandidates('view_candidates', 'Consulter les dossiers candidats'),

  // Logistique
  manageLogistics('manage_logistics', 'Gérer les documents logistiques (CRUD)'),
  viewLogistics('view_logistics', 'Consulter les documents logistiques'),
  validateLogistics(
    'validate_logistics',
    'Valider / rejeter les documents logistiques',
  ),

  // Administration
  manageUsers('manage_users', 'Gérer les comptes utilisateurs'),
  viewDashboardAdmin(
    'view_dashboard_admin',
    'Accéder au dashboard administrateur',
  ),
  viewActivityLog('view_activity_log', 'Consulter le journal d\'activité');

  final String code;
  final String label;

  const FalePermission(this.code, this.label);
}
