/// Droits élémentaires du système FALE Archives.
///
/// Un droit décrit **une action sur un type de ressource**, jamais un rôle ni un
/// poste. La matrice rôle → droits vit dans [UserRole.permissions].
///
/// Le `code` est la valeur de référence : c'est lui qui sera stocké côté base
/// (table `role_permissions`) et lu par les politiques RLS. Il ne doit pas
/// changer une fois en production.
enum FalePermission {
  // --- Archives (§5.1) ------------------------------------------------
  viewArchives('view_archives', 'Consulter les archives'),
  viewAllArchives('view_all_archives', 'Voir toutes les archives (tous postes)'),
  submitArchive('submit_archive', 'Soumettre une archive journalière'),
  editArchive('edit_archive', 'Modifier une archive déposée'),
  deleteArchive('delete_archive', 'Supprimer / mettre à la corbeille une archive'),
  downloadDocument('download_document', 'Télécharger une pièce jointe'),
  exportArchives('export_archives', 'Exporter les archives (PDF, ZIP)'),
  manageCategories('manage_categories', 'Gérer les catégories et types de documents'),
  manageRetention('manage_retention', 'Gérer les durées légales de conservation'),

  // --- Offres d'emploi (§5.2) -----------------------------------------
  viewJobOffers('view_job_offers', 'Consulter les offres d\'emploi'),
  manageJobOffers('manage_job_offers', 'Créer et modifier les offres d\'emploi'),
  publishJobOffer('publish_job_offer', 'Valider et publier une offre d\'emploi'),

  // --- Candidatures (§5.3) --------------------------------------------
  viewCandidates('view_candidates', 'Consulter les dossiers candidats'),
  manageCandidates('manage_candidates', 'Gérer les dossiers candidats (CRUD)'),
  moveApplication('move_application', 'Faire évoluer une candidature dans le pipeline'),
  rateApplication('rate_application', 'Noter et commenter une candidature'),
  scheduleInterview('schedule_interview', 'Planifier un entretien'),
  managePipeline('manage_pipeline', 'Paramétrer les étapes du pipeline'),

  // --- Logistique (module existant) -----------------------------------
  viewLogistics('view_logistics', 'Consulter les documents logistiques'),
  manageLogistics('manage_logistics', 'Gérer les documents logistiques (CRUD)'),
  validateLogistics('validate_logistics', 'Valider / rejeter les documents logistiques'),

  // --- Reporting (§5.4) -----------------------------------------------
  viewReports('view_reports', 'Consulter les rapports et tableaux de bord'),
  exportReports('export_reports', 'Exporter les rapports (PDF, CSV)'),

  // --- Administration et sécurité (§5.5) ------------------------------
  viewDashboardAdmin('view_dashboard_admin', 'Accéder au dashboard administrateur'),
  manageUsers('manage_users', 'Gérer les comptes utilisateurs'),
  manageRoles('manage_roles', 'Attribuer les rôles et les droits'),
  manageSettings('manage_settings', 'Gérer les paramètres de l\'organisation'),
  manageSubscriptions('manage_subscriptions', 'Gérer l\'abonnement et la facturation'),
  viewActivityLog('view_activity_log', 'Consulter le journal d\'activité'),
  viewAuditTrail('view_audit_trail', 'Consulter la piste d\'audit complète'),

  // --- Exploitation multi-entreprises (§5.5.1) ------------------------
  manageOrganizations('manage_organizations', 'Administrer toutes les entreprises');

  final String code;
  final String label;

  const FalePermission(this.code, this.label);

  /// Retrouve un droit à partir de son `code` persisté. `null` si inconnu —
  /// un code retiré d'une version antérieure ne doit pas faire planter l'app.
  static FalePermission? fromCode(String code) {
    for (final permission in FalePermission.values) {
      if (permission.code == code) return permission;
    }
    return null;
  }
}
