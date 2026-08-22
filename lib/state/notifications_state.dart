import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/in_app_notification.dart';
import '../models/user_role.dart';
import '../services/local_storage_service.dart';

class NotificationsState extends ChangeNotifier {
  final List<InAppNotification> _notifications = [];
  static const _uuid = Uuid();

  NotificationsState() {
    _loadFromStorage();
  }

  List<InAppNotification> get allNotifications =>
      List.unmodifiable(_notifications);

  /// Filtre les notifications pertinentes pour l'utilisateur connecté
  List<InAppNotification> forUser({
    required String userId,
    required UserRole role,
  }) {
    return _notifications.where((n) {
      if (n.targetUserId != null && n.targetUserId == userId) return true;
      if (n.targetRole != null && n.targetRole == role.name) return true;
      if (n.targetUserId == null && n.targetRole == null) return true;
      return false;
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int unreadCount({required String userId, required UserRole role}) {
    return forUser(userId: userId, role: role).where((n) => !n.isRead).length;
  }

  void addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? relatedEntityId,
    String? targetRole,
    String? targetUserId,
  }) {
    final notif = InAppNotification(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      relatedEntityId: relatedEntityId,
      targetRole: targetRole,
      targetUserId: targetUserId,
    );
    _notifications.insert(0, notif);
    _saveToStorage();
    notifyListeners();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _saveToStorage();
      notifyListeners();
    }
  }

  void markAllAsRead({required String userId, required UserRole role}) {
    final userNotifs = forUser(userId: userId, role: role);
    for (final un in userNotifs) {
      final idx = _notifications.indexWhere((n) => n.id == un.id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
    }
    _saveToStorage();
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveToStorage();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _saveToStorage();
    notifyListeners();
  }

  void _saveToStorage() {
    LocalStorageService.saveNotifications(
      _notifications.map((n) => n.toJson()).toList(),
    );
  }

  void _loadFromStorage() {
    final list = LocalStorageService.loadNotifications();
    if (list != null && list.isNotEmpty) {
      _notifications.clear();
      _notifications.addAll(list.map((m) => InAppNotification.fromJson(m)));
    } else {
      // Données de démonstration initiales
      _notifications.addAll([
        InAppNotification(
          id: 'n-1',
          title: 'Validation requise',
          message:
              'Une facture Sonatel (FAC-2026-001) attend votre validation.',
          type: NotificationType.logisticsPending,
          timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
          targetRole: UserRole.directeurAdministratif.name,
        ),
        InAppNotification(
          id: 'n-2',
          title: 'Rappel d\'archivage',
          message: 'Pensez à déposer votre registre quotidien avant 18h.',
          type: NotificationType.archiveReminder,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          targetRole: UserRole.employe.name,
        ),
        InAppNotification(
          id: 'n-3',
          title: 'Nouveau candidat',
          message:
              'Dossier de candidature reçu pour le poste de Secrétaire de Direction.',
          type: NotificationType.candidateUpdate,
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          targetRole: UserRole.rh.name,
        ),
        InAppNotification(
          id: 'n-4',
          title: 'Bienvenue sur FALE Archives v2',
          message:
              'Toutes vos archives, logistique et recrutements sont désormais synchronisés.',
          type: NotificationType.system,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
      _saveToStorage();
    }
  }
}
