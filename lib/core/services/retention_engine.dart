import '../../data/models/document.dart';
import '../../data/models/document_type.dart';
import '../../data/models/notification_item.dart';

class RetentionEngine {
  /// Évalue le statut de rétention d'un document selon la date de création et la règle du DocumentType
  static RetentionStatus evaluateStatus({
    required DocumentItem document,
    required DocumentType? documentType,
  }) {
    final now = DateTime.now();
    final retentionYears = documentType?.retentionYears ?? 5;
    final warningDays = documentType?.warningDaysBeforeExpiration ?? 30;

    final expirationDate = document.createdAt.add(Duration(days: retentionYears * 365));
    final daysUntilExpiration = expirationDate.difference(now).inDays;

    if (daysUntilExpiration <= 0) {
      return documentType?.retentionAction == 'destroy'
          ? RetentionStatus.toDestroy
          : RetentionStatus.expired;
    } else if (daysUntilExpiration <= warningDays) {
      return RetentionStatus.expiringSoon;
    } else {
      return RetentionStatus.active;
    }
  }

  /// Génère une notification d'alerte pré-destruction ou d'expiration
  static NotificationItem? createRetentionNotification({
    required DocumentItem document,
    required RetentionStatus newStatus,
  }) {
    if (newStatus == RetentionStatus.expiringSoon) {
      return NotificationItem(
        id: 'notif_ret_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Alerte Rétention : Document bientôt expiré',
        message: 'Le document "${document.title}" (Réf: ${document.reference}) arrive au terme de sa durée de conservation légale.',
        type: 'retention_warning',
        timestamp: DateTime.now(),
        isRead: false,
      );
    } else if (newStatus == RetentionStatus.expired || newStatus == RetentionStatus.toDestroy) {
      return NotificationItem(
        id: 'notif_ret_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Document Expiré — À Détruire ou Archiver',
        message: 'Le document "${document.title}" (Réf: ${document.reference}) a atteint son échéance finale.',
        type: 'retention_expired',
        timestamp: DateTime.now(),
        isRead: false,
      );
    }
    return null;
  }
}
