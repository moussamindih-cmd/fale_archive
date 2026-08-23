import 'attached_file.dart';

/// Archive journalière déposée par un collaborateur (§5.1).
class DailyArchive {
  final String id;
  final String employeeId;
  final String employeeName;
  final String jobTitle;

  /// Jour concerné par le dépôt.
  final DateTime archiveDate;
  final String title;
  final String summary;

  /// Libellé de catégorie. Historiquement déduit du poste ; désormais un
  /// simple libellé dénormalisé, la référence étant [categoryId].
  final String category;

  /// Catégorie choisie dans la taxonomie de l'organisation (§5.1.2).
  final String? categoryId;

  /// Type de document : c'est lui qui porte la durée légale de
  /// conservation (§5.1.4).
  final String? documentTypeId;

  /// Mots-clés libres, indexés pour la recherche plein texte (§5.1.3).
  final List<String> keywords;

  final int documentCount;
  final List<AttachedFile> files;

  /// Emplacement physique (ex : « Armoire B > Rayon 2 > Boîte 14 »).
  final String physicalLocation;

  final DateTime submittedAt;
  final DateTime? deletedAt;

  /// Gel conservatoire : suspend toute purge, quelle que soit l'échéance.
  final bool legalHold;

  /// Échéance de conservation, calculée côté base à partir du type.
  final DateTime? retentionUntil;

  /// Horodatage de la destruction au terme de la durée légale.
  final DateTime? purgedAt;

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
    required this.submittedAt,
    this.categoryId,
    this.documentTypeId,
    this.keywords = const [],
    this.files = const [],
    this.physicalLocation = '',
    this.deletedAt,
    this.legalHold = false,
    this.retentionUntil,
    this.purgedAt,
  });

  /// Référence lisible, dérivée du poste du déposant.
  String get reference {
    final prefix = switch (jobTitle) {
      'Secrétaire' => 'SEC',
      'Comptable' => 'COMPTA',
      'Gestionnaire' => 'GEST',
      'Conseiller Principal' => 'CONS-P',
      'Conseiller Adjoint' => 'CONS-A',
      _ => 'ARC',
    };
    final d = archiveDate.day.toString().padLeft(2, '0');
    final m = archiveDate.month.toString().padLeft(2, '0');
    return '$prefix-$d$m${archiveDate.year}';
  }

  /// Jours restants avant suppression définitive depuis la corbeille.
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

  bool get isInTrash => deletedAt != null;

  /// Contenu détruit au terme de la conservation légale : la fiche subsiste
  /// comme trace, mais les pièces ont disparu.
  bool get isPurged => purgedAt != null;

  DateTime get createdAt => submittedAt;

  /// Sentinelle permettant de distinguer « ne pas toucher » de « remettre à
  /// null ». Sans elle, `deletedAt ?? this.deletedAt` rendait la restauration
  /// depuis la corbeille impossible.
  static const Object _absent = Object();

  DailyArchive copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? jobTitle,
    DateTime? archiveDate,
    String? title,
    String? summary,
    String? category,
    Object? categoryId = _absent,
    Object? documentTypeId = _absent,
    List<String>? keywords,
    int? documentCount,
    List<AttachedFile>? files,
    String? physicalLocation,
    DateTime? submittedAt,
    Object? deletedAt = _absent,
    bool? legalHold,
    Object? retentionUntil = _absent,
    Object? purgedAt = _absent,
  }) {
    return DailyArchive(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      jobTitle: jobTitle ?? this.jobTitle,
      archiveDate: archiveDate ?? this.archiveDate,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      categoryId: identical(categoryId, _absent)
          ? this.categoryId
          : categoryId as String?,
      documentTypeId: identical(documentTypeId, _absent)
          ? this.documentTypeId
          : documentTypeId as String?,
      keywords: keywords ?? this.keywords,
      documentCount: documentCount ?? this.documentCount,
      // Auparavant absents de copyWith : toute copie perdait silencieusement
      // les pièces jointes et l'emplacement physique.
      files: files ?? this.files,
      physicalLocation: physicalLocation ?? this.physicalLocation,
      submittedAt: submittedAt ?? this.submittedAt,
      deletedAt:
          identical(deletedAt, _absent) ? this.deletedAt : deletedAt as DateTime?,
      legalHold: legalHold ?? this.legalHold,
      retentionUntil: identical(retentionUntil, _absent)
          ? this.retentionUntil
          : retentionUntil as DateTime?,
      purgedAt:
          identical(purgedAt, _absent) ? this.purgedAt : purgedAt as DateTime?,
    );
  }

  /// Sérialisation alignée sur les colonnes de la base (snake_case).
  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'job_title': jobTitle,
        'archive_date': _dateOnly(archiveDate),
        'title': title,
        'summary': summary,
        'category': category,
        'category_id': categoryId,
        'document_type_id': documentTypeId,
        'keywords': keywords,
        'document_count': documentCount,
        'physical_location': physicalLocation,
        'documents': files.map((f) => f.toJson()).toList(),
        'submitted_at': submittedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'legal_hold': legalHold,
        'retention_until':
            retentionUntil == null ? null : _dateOnly(retentionUntil!),
        'purged_at': purgedAt?.toIso8601String(),
      };

  factory DailyArchive.fromJson(Map<String, dynamic> json) {
    // Les clés camelCase sont celles de l'ancienne sérialisation locale ;
    // elles restent acceptées pour ne pas perdre les données déjà stockées.
    T? pick<T>(String snake, String camel) =>
        (json[snake] ?? json[camel]) as T?;

    return DailyArchive(
      id: json['id'] as String,
      employeeId: pick<String>('employee_id', 'employeeId') ?? '',
      employeeName: pick<String>('employee_name', 'employeeName') ?? '',
      jobTitle: pick<String>('job_title', 'jobTitle') ?? '',
      archiveDate:
          DateTime.parse(pick<String>('archive_date', 'archiveDate')!),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      documentTypeId: json['document_type_id'] as String?,
      keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
      documentCount: pick<int>('document_count', 'documentCount') ?? 0,
      files: (json['documents'] as List?)
              ?.map((e) => AttachedFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      physicalLocation:
          pick<String>('physical_location', 'physicalLocation') ?? '',
      submittedAt:
          DateTime.parse(pick<String>('submitted_at', 'submittedAt')!),
      deletedAt: _parseNullable(json['deleted_at']),
      legalHold: json['legal_hold'] as bool? ?? false,
      retentionUntil: _parseNullable(json['retention_until']),
      purgedAt: _parseNullable(json['purged_at']),
    );
  }

  static DateTime? _parseNullable(Object? value) =>
      value == null ? null : DateTime.tryParse(value as String);

  static String _dateOnly(DateTime value) =>
      value.toIso8601String().substring(0, 10);
}
