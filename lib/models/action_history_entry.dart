/// Entrée dans l'historique des actions — utilisée pour la traçabilité
class ActionHistoryEntry {
  final String userName;
  final String action;
  final DateTime timestamp;
  final String details;

  const ActionHistoryEntry({
    required this.userName,
    required this.action,
    required this.timestamp,
    this.details = '',
  });

  /// true si cette entrée est un commentaire d'équipe plutôt qu'une action système
  bool get isComment => action == 'COMMENT';

  /// Format d'affichage de l'action
  String get displayAction {
    switch (action) {
      case 'CREATE':
        return 'Création';
      case 'UPDATE':
        return 'Modification';
      case 'STATUS_CHANGE':
        return 'Changement de statut';
      case 'DELETE':
        return 'Suppression';
      case 'RESTORE':
        return 'Restauration';
      case 'VALIDATE':
        return 'Validation';
      case 'REJECT':
        return 'Rejet';
      case 'LOGIN':
        return 'Connexion';
      case 'LOGOUT':
        return 'Déconnexion';
      case 'REGISTER':
        return 'Inscription';
      case 'ROLE_CHANGE':
        return 'Changement de rôle';
      case 'ARCHIVE_SUBMIT':
        return 'Soumission d\'archive';
      case 'SCAN':
        return 'Numérisation';
      case 'COMMENT':
        return 'Commentaire';
      default:
        return action;
    }
  }
}
