enum AppPermission {
  viewDocument('view_document', 'Consulter les documents'),
  createDocument('create_document', 'Ajouter des documents'),
  updateDocument('update_document', 'Modifier les documents'),
  deleteDocument('delete_document', 'Supprimer des documents'),
  downloadDocument('download_document', 'Télécharger les documents'),
  shareDocument('share_document', 'Partager les documents'),
  manageUsers('manage_users', 'Gérer les utilisateurs'),
  manageRoles('manage_roles', 'Gérer les rôles'),
  viewAudit('view_audit', 'Consulter le journal d audit'),
  manageSettings('manage_settings', 'Gérer les paramètres'),
  manageDepartments('manage_departments', 'Gérer les départements'),
  manageCategories('manage_categories', 'Gérer les catégories'),
  manageSubscriptions('manage_subscriptions', 'Gérer les abonnements');

  final String code;
  final String label;

  const AppPermission(this.code, this.label);
}
