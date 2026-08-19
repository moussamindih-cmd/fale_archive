import 'package:flutter/material.dart';

enum NotificationType {
  archiveReminder(
    label: 'Rappel d\'archive',
    color: Color(0xFFF59E0B),
    icon: Icons.edit_calendar_rounded,
  ),
  logisticsPending(
    label: 'Validation Logistique',
    color: Color(0xFF7C3AED),
    icon: Icons.receipt_long_rounded,
  ),
  logisticsStatus(
    label: 'Statut Document',
    color: Color(0xFF10B981),
    icon: Icons.check_circle_outline_rounded,
  ),
  candidateUpdate(
    label: 'Mise à jour Candidat',
    color: Color(0xFFEC4899),
    icon: Icons.person_search_rounded,
  ),
  system(
    label: 'Système',
    color: Color(0xFF2563EB),
    icon: Icons.info_outline_rounded,
  );

  final String label;
  final Color color;
  final IconData icon;

  const NotificationType({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedEntityId; // ID d'archive, candidat ou document logistique
  final String? targetRole; // Rôle visé (null si pour tous ou ciblé par userId)
  final String? targetUserId;

  const InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.relatedEntityId,
    this.targetRole,
    this.targetUserId,
  });

  InAppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? relatedEntityId,
    String? targetRole,
    String? targetUserId,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      targetRole: targetRole ?? this.targetRole,
      targetUserId: targetUserId ?? this.targetUserId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'relatedEntityId': relatedEntityId,
    'targetRole': targetRole,
    'targetUserId': targetUserId,
  };

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      relatedEntityId: json['relatedEntityId'] as String?,
      targetRole: json['targetRole'] as String?,
      targetUserId: json['targetUserId'] as String?,
    );
  }
}
