import 'attached_file.dart';
import 'action_history_entry.dart';

/// Statut d'un dossier de candidature
enum CandidateStatus {
  enAttente(
    label: 'En attente',
    colorValue: 0xFFF59E0B, // Ambre
    iconCodePoint: 0xe425,
  ),
  enEntretien(
    label: 'En entretien',
    colorValue: 0xFF2563EB, // Bleu
    iconCodePoint: 0xf04df,
  ),
  retenu(
    label: 'Retenu',
    colorValue: 0xFF10B981, // Vert
    iconCodePoint: 0xf04c1,
  ),
  rejete(
    label: 'Rejeté',
    colorValue: 0xFFEF4444, // Rouge
    iconCodePoint: 0xf0371,
  ),
  archive(
    label: 'Archivé',
    colorValue: 0xFF64748B, // Gris
    iconCodePoint: 0xf0553,
  );

  final String label;
  final int colorValue;
  final int iconCodePoint;

  const CandidateStatus({
    required this.label,
    required this.colorValue,
    required this.iconCodePoint,
  });
}

/// Modèle de données d'un dossier candidat
class Candidate {
  final String id;
  final String fullName;
  final String targetPosition; // Poste visé
  final String email;
  final String phone;
  final DateTime applicationDate;
  final CandidateStatus status;
  final List<AttachedFile> documents; // CV, documents joints
  final String rhNotes; // Notes RH (texte libre)
  final List<ActionHistoryEntry> history; // Historique des actions
  final bool isDeleted; // Suppression logique

  const Candidate({
    required this.id,
    required this.fullName,
    required this.targetPosition,
    this.email = '',
    this.phone = '',
    required this.applicationDate,
    this.status = CandidateStatus.enAttente,
    this.documents = const [],
    this.rhNotes = '',
    this.history = const [],
    this.isDeleted = false,
  });

  /// Initiales pour l'avatar
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, 1).toUpperCase();
  }

  DateTime get createdAt => applicationDate;

  /// Copie avec modifications
  Candidate copyWith({
    String? id,
    String? fullName,
    String? targetPosition,
    String? email,
    String? phone,
    DateTime? applicationDate,
    CandidateStatus? status,
    List<AttachedFile>? documents,
    String? rhNotes,
    List<ActionHistoryEntry>? history,
    bool? isDeleted,
  }) {
    return Candidate(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      targetPosition: targetPosition ?? this.targetPosition,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      applicationDate: applicationDate ?? this.applicationDate,
      status: status ?? this.status,
      documents: documents ?? this.documents,
      rhNotes: rhNotes ?? this.rhNotes,
      history: history ?? this.history,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'targetPosition': targetPosition,
    'email': email,
    'phone': phone,
    'applicationDate': applicationDate.toIso8601String(),
    'status': status.name,
    'rhNotes': rhNotes,
    'isDeleted': isDeleted,
  };

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      targetPosition: json['targetPosition'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      applicationDate: DateTime.parse(json['applicationDate'] as String),
      status: CandidateStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CandidateStatus.enAttente,
      ),
      rhNotes: json['rhNotes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}
