class DailyArchiveItem {
  final String id;
  final String organizationId;
  final String userId;
  final String userName;
  final String userJobTitle; // Secrétaire, Comptable, Gestionnaire, Conseiller Principal, Conseiller Adjoint
  final DateTime archiveDate;
  final String category; // Courriers du jour, Pièces comptables, Synthèse de gestion, Avis technique, Note d étude
  final String title;
  final String reference;
  final String summary;
  final int documentCount;
  final String status; // 'Enregistré', 'Transmis', 'Validé'
  final DateTime createdAt;

  const DailyArchiveItem({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.userName,
    required this.userJobTitle,
    required this.archiveDate,
    required this.category,
    required this.title,
    required this.reference,
    required this.summary,
    required this.documentCount,
    this.status = 'Enregistré',
    required this.createdAt,
  });
}
