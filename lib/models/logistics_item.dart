import 'package:flutter/material.dart';
import 'attached_file.dart';
import 'action_history_entry.dart';

/// Type de document logistique
enum LogisticsDocType {
  facture(
    label: 'Facture',
    colorValue: 0xFF2563EB, // Bleu
    iconCodePoint: 0xf0633, // Icons.receipt_long_rounded
  ),
  justificatif(
    label: 'Justificatif',
    colorValue: 0xFFF59E0B, // Ambre
    iconCodePoint: 0xf0245, // Icons.description_rounded
  ),
  contrat(
    label: 'Contrat',
    colorValue: 0xFF7C3AED, // Violet
    iconCodePoint: 0xf031e, // Icons.handshake_rounded
  ),
  autre(
    label: 'Autre',
    colorValue: 0xFF64748B, // Gris
    iconCodePoint: 0xf02cb, // Icons.folder_rounded
  );

  final String label;
  final int colorValue;
  final int iconCodePoint;

  const LogisticsDocType({
    required this.label,
    required this.colorValue,
    required this.iconCodePoint,
  });

  IconData get icon {
    switch (this) {
      case LogisticsDocType.facture:
        return Icons.receipt_long_rounded;
      case LogisticsDocType.justificatif:
        return Icons.description_rounded;
      case LogisticsDocType.contrat:
        return Icons.handshake_rounded;
      case LogisticsDocType.autre:
        return Icons.folder_rounded;
    }
  }
}

/// Statut de validation d'un document logistique
enum LogisticsStatus {
  enAttente(
    label: 'En attente',
    colorValue: 0xFFF59E0B, // Ambre
  ),
  valide(
    label: 'Validé',
    colorValue: 0xFF10B981, // Vert
  ),
  rejete(
    label: 'Rejeté',
    colorValue: 0xFFEF4444, // Rouge
  );

  final String label;
  final int colorValue;

  const LogisticsStatus({required this.label, required this.colorValue});
}

/// Modèle de données d'un document logistique
class LogisticsItem {
  final String id;
  final LogisticsDocType documentType;
  final String reference; // Numéro de référence
  final double? amount; // Montant (si applicable)
  final String supplier; // Fournisseur / partie prenante
  final DateTime issueDate; // Date d'émission
  final LogisticsStatus status;
  final List<AttachedFile> files; // Fichiers attachés
  final String registeredById; // ID de l'employé enregistreur
  final String registeredByName; // Nom de l'employé enregistreur
  final String validatedByName; // Nom du validateur (si validé/rejeté)
  final String notes; // Notes complémentaires
  final List<ActionHistoryEntry> history;
  final bool isDeleted; // Suppression logique
  final DateTime? deletedAt; // Date de mise à la corbeille

  const LogisticsItem({
    required this.id,
    required this.documentType,
    required this.reference,
    this.amount,
    required this.supplier,
    required this.issueDate,
    this.status = LogisticsStatus.enAttente,
    this.files = const [],
    required this.registeredById,
    required this.registeredByName,
    this.validatedByName = '',
    this.notes = '',
    this.history = const [],
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Montant formaté pour l'affichage
  String get formattedAmount {
    if (amount == null) return '—';
    return '${amount!.toStringAsFixed(0)} FCFA';
  }

  /// Nombre de jours restants avant suppression définitive (7 jours max)
  int get daysUntilDeletion {
    if (deletedAt == null) return 0;
    final deletionDate = deletedAt!.add(const Duration(days: 7));
    final remaining = deletionDate.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inHours / 24).ceil();
  }

  /// Copie avec modifications
  LogisticsItem copyWith({
    String? id,
    LogisticsDocType? documentType,
    String? reference,
    double? amount,
    String? supplier,
    DateTime? issueDate,
    LogisticsStatus? status,
    List<AttachedFile>? files,
    String? registeredById,
    String? registeredByName,
    String? validatedByName,
    String? notes,
    List<ActionHistoryEntry>? history,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return LogisticsItem(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
      supplier: supplier ?? this.supplier,
      issueDate: issueDate ?? this.issueDate,
      status: status ?? this.status,
      files: files ?? this.files,
      registeredById: registeredById ?? this.registeredById,
      registeredByName: registeredByName ?? this.registeredByName,
      validatedByName: validatedByName ?? this.validatedByName,
      notes: notes ?? this.notes,
      history: history ?? this.history,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentType': documentType.name,
    'reference': reference,
    'amount': amount,
    'supplier': supplier,
    'issueDate': issueDate.toIso8601String(),
    'status': status.name,
    'registeredById': registeredById,
    'registeredByName': registeredByName,
    'validatedByName': validatedByName,
    'notes': notes,
    'isDeleted': isDeleted,
  };

  factory LogisticsItem.fromJson(Map<String, dynamic> json) {
    return LogisticsItem(
      id: json['id'] as String,
      documentType: LogisticsDocType.values.firstWhere(
        (d) => d.name == json['documentType'],
        orElse: () => LogisticsDocType.facture,
      ),
      reference: json['reference'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      supplier: json['supplier'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      status: LogisticsStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => LogisticsStatus.enAttente,
      ),
      registeredById: json['registeredById'] as String? ?? '',
      registeredByName: json['registeredByName'] as String? ?? '',
      validatedByName: json['validatedByName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}
