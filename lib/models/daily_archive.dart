import 'attached_file.dart';

// Modèle d'une archive journalière soumise par un employé
class DailyArchive {
  final String id;
  final String employeeId;
  final String employeeName;
  final String jobTitle;
  final DateTime archiveDate; // Date du jour concerné
  final String title; // Titre de l'archive du jour
  final String summary; // Résumé de ce qui a été archivé
  final String category; // Catégorie automatique selon le poste
  final int documentCount; // Nombre de pièces numérisées / documents
  final List<AttachedFile> files; // Fichiers joints (PDF, Word, Excel...)
  final String
  physicalLocation; // Emplacement physique (ex: Armoire B > Rayon 2 > Boîte 14)
  final DateTime submittedAt;
  final DateTime? deletedAt;

  const DailyArchive({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.jobTitle,
    required this.archiveDate,
    required this.title,
    required this.summary,
    required this.category,
    required this.documentCount,
    this.files = const [],
    this.physicalLocation = '',
    required this.submittedAt,
    this.deletedAt,
  });

  // Référence unique auto-générée à l affichage
  String get reference {
    final prefix = switch (jobTitle) {
      'Secrétaire' => 'SEC',
      'Comptable' => 'COMPTA',
      'Gestionnaire' => 'GEST',
      'Conseiller Principal' => 'CONS-P',
      'Conseiller Adjoint' => 'CONS-A',
      _ => 'ARC',
    };
    return '$prefix-${archiveDate.day.toString().padLeft(2, '0')}${archiveDate.month.toString().padLeft(2, '0')}${archiveDate.year}';
  }

  /// Nombre de jours restants avant suppression définitive (7 jours max)
  int get daysUntilDeletion {
    if (deletedAt == null) return 0;
    final deletionDate = deletedAt!.add(const Duration(days: 7));
    final remaining = deletionDate.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    // Arrondi au jour supérieur : juste après suppression, il reste bien
    // "7 jours" affichés, pas 6 (troncature de la durée résiduelle de
    // 6j 23h59 par .inDays).
    return (remaining.inHours / 24).ceil();
  }

  bool get isToday {
    final now = DateTime.now();
    return archiveDate.year == now.year &&
        archiveDate.month == now.month &&
        archiveDate.day == now.day;
  }

  DateTime get createdAt => submittedAt;

  DailyArchive copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? jobTitle,
    DateTime? submittedAt,
    DateTime? deletedAt,
  }) {
    return DailyArchive(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      jobTitle: jobTitle ?? this.jobTitle,
      archiveDate: archiveDate,
      title: title,
      summary: summary,
      category: category,
      documentCount: documentCount,
      submittedAt: submittedAt ?? this.submittedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'job_title': jobTitle,
    'archiveDate': archiveDate.toIso8601String(),
    'title': title,
    'summary': summary,
    'category': category,
    'documentCount': documentCount,
    'physicalLocation': physicalLocation,
    'submittedAt': submittedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory DailyArchive.fromJson(Map<String, dynamic> json) {
    return DailyArchive(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      jobTitle: json['job_title'] as String,
      archiveDate: DateTime.parse(json['archiveDate'] as String),
      title: json['title'] as String,
      summary: json['summary'] as String,
      category: json['category'] as String,
      documentCount: json['documentCount'] as int,
      physicalLocation: json['physicalLocation'] as String? ?? '',
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
}
