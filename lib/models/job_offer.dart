import 'package:flutter/material.dart';

/// Étape du workflow de validation interne (§5.2.2).
///
/// Décrit **comment** l'offre a été approuvée. Distinct du cycle de vie,
/// qui décrit où elle en est une fois publiée.
enum OfferWorkflowStatus {
  brouillon('brouillon', 'Brouillon', Color(0xFF64748B), Icons.edit_note_rounded),
  enValidation('en_validation', 'En validation', Color(0xFFF59E0B), Icons.hourglass_top_rounded),
  publiee('publiee', 'Publiée', Color(0xFF10B981), Icons.public_rounded),
  rejetee('rejetee', 'Rejetée', Color(0xFFEF4444), Icons.block_rounded);

  final String code;
  final String label;
  final Color color;
  final IconData icon;

  const OfferWorkflowStatus(this.code, this.label, this.color, this.icon);

  static OfferWorkflowStatus fromCode(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return OfferWorkflowStatus.brouillon;
  }

  /// Transitions autorisées — miroir exact du trigger
  /// `guard_job_offer_workflow`. Le serveur reste seul juge : cette liste
  /// sert à n'afficher que des actions réellement exécutables.
  Set<OfferWorkflowStatus> get allowedNext => switch (this) {
        OfferWorkflowStatus.brouillon => {OfferWorkflowStatus.enValidation},
        OfferWorkflowStatus.enValidation => {
            OfferWorkflowStatus.publiee,
            OfferWorkflowStatus.rejetee,
            OfferWorkflowStatus.brouillon,
          },
        // Une offre rejetée repart en correction, elle n'est pas perdue.
        OfferWorkflowStatus.rejetee => {OfferWorkflowStatus.brouillon},
        // Une offre publiée ne redevient jamais brouillon : on la retire
        // par le cycle de vie, ce qui préserve l'historique.
        OfferWorkflowStatus.publiee => const {},
      };

  bool get isEditable =>
      this == OfferWorkflowStatus.brouillon || this == OfferWorkflowStatus.rejetee;
}

/// Cycle de vie d'une offre publiée (§5.2.3).
enum OfferLifecycleStatus {
  active('active', 'Active', Color(0xFF10B981), Icons.play_circle_outline_rounded),
  suspendue('suspendue', 'Suspendue', Color(0xFFF59E0B), Icons.pause_circle_outline_rounded),
  pourvue('pourvue', 'Pourvue', Color(0xFF4F46E5), Icons.how_to_reg_rounded),
  archivee('archivee', 'Archivée', Color(0xFF64748B), Icons.inventory_2_outlined);

  final String code;
  final String label;
  final Color color;
  final IconData icon;

  const OfferLifecycleStatus(this.code, this.label, this.color, this.icon);

  static OfferLifecycleStatus fromCode(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return OfferLifecycleStatus.active;
  }

  /// Seule une offre active reçoit des candidatures.
  bool get acceptsApplications => this == OfferLifecycleStatus.active;
}

/// Nature du contrat proposé.
enum ContractType {
  cdi('cdi', 'CDI'),
  cdd('cdd', 'CDD'),
  stage('stage', 'Stage'),
  interim('interim', 'Intérim'),
  consultance('consultance', 'Consultance');

  final String code;
  final String label;
  const ContractType(this.code, this.label);

  static ContractType fromCode(String? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return ContractType.cdi;
  }
}

/// Offre d'emploi (§5.2).
class JobOffer {
  final String id;
  final String organizationId;

  /// Référence attribuée par la base : `OFF-2026-001`, par organisation
  /// et par année.
  final String reference;

  final String title;
  final String description;
  final String? requirements;
  final List<String> skills;

  final ContractType contractType;
  final String? location;
  final int positionsCount;

  final double? salaryMin;
  final double? salaryMax;
  final String salaryCurrency;

  /// Le salaire peut être renseigné en interne sans être publié.
  final bool salaryVisible;

  final DateTime? deadline;

  final OfferWorkflowStatus workflowStatus;
  final OfferLifecycleStatus lifecycleStatus;

  /// Un modèle réutilisable (§5.2.5) : jamais publiable, sert de base à
  /// de nouvelles offres.
  final bool isTemplate;
  final String? templateName;

  final DateTime? publishedAt;
  final String? rejectionReason;

  final String? createdBy;
  final String? validatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobOffer({
    required this.id,
    required this.organizationId,
    required this.reference,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.requirements,
    this.skills = const [],
    this.contractType = ContractType.cdi,
    this.location,
    this.positionsCount = 1,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency = 'XAF',
    this.salaryVisible = false,
    this.deadline,
    this.workflowStatus = OfferWorkflowStatus.brouillon,
    this.lifecycleStatus = OfferLifecycleStatus.active,
    this.isTemplate = false,
    this.templateName,
    this.publishedAt,
    this.rejectionReason,
    this.createdBy,
    this.validatedBy,
  });

  /// Visible des candidats externes : publiée, active, non expirée.
  /// Réplique la clause de la vue `public_job_offers`.
  bool get isPubliclyVisible =>
      workflowStatus == OfferWorkflowStatus.publiee &&
      lifecycleStatus == OfferLifecycleStatus.active &&
      !isTemplate &&
      !isExpired;

  bool get isExpired {
    if (deadline == null) return false;
    final today = DateTime.now();
    return deadline!.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Jours restants avant l'échéance. `null` si aucune date limite.
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final today = DateTime.now();
    return deadline!.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  bool get acceptsApplications =>
      isPubliclyVisible && lifecycleStatus.acceptsApplications;

  /// Fourchette salariale formatée, ou `null` si non publiée ou absente.
  String? get formattedSalary {
    if (!salaryVisible || (salaryMin == null && salaryMax == null)) return null;
    String fmt(double v) {
      final s = v.round().toString();
      final buffer = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
        buffer.write(s[i]);
      }
      return buffer.toString();
    }

    if (salaryMin != null && salaryMax != null) {
      return '${fmt(salaryMin!)} – ${fmt(salaryMax!)} $salaryCurrency';
    }
    return '${fmt(salaryMin ?? salaryMax!)} $salaryCurrency';
  }

  String get displayName => isTemplate ? (templateName ?? title) : title;

  JobOffer copyWith({
    String? title,
    String? description,
    String? requirements,
    List<String>? skills,
    ContractType? contractType,
    String? location,
    int? positionsCount,
    double? salaryMin,
    double? salaryMax,
    bool? salaryVisible,
    DateTime? deadline,
    OfferWorkflowStatus? workflowStatus,
    OfferLifecycleStatus? lifecycleStatus,
    DateTime? publishedAt,
    String? rejectionReason,
    String? validatedBy,
    DateTime? updatedAt,
  }) {
    return JobOffer(
      id: id,
      organizationId: organizationId,
      reference: reference,
      title: title ?? this.title,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      skills: skills ?? this.skills,
      contractType: contractType ?? this.contractType,
      location: location ?? this.location,
      positionsCount: positionsCount ?? this.positionsCount,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      salaryCurrency: salaryCurrency,
      salaryVisible: salaryVisible ?? this.salaryVisible,
      deadline: deadline ?? this.deadline,
      workflowStatus: workflowStatus ?? this.workflowStatus,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      isTemplate: isTemplate,
      templateName: templateName,
      publishedAt: publishedAt ?? this.publishedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdBy: createdBy,
      validatedBy: validatedBy ?? this.validatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);

    return JobOffer(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      reference: json['reference'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requirements: json['requirements'] as String?,
      skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      contractType: ContractType.fromCode(json['contract_type'] as String?),
      location: json['location'] as String?,
      positionsCount: (json['positions_count'] as num?)?.toInt() ?? 1,
      salaryMin: (json['salary_min'] as num?)?.toDouble(),
      salaryMax: (json['salary_max'] as num?)?.toDouble(),
      salaryCurrency: json['salary_currency'] as String? ?? 'XAF',
      salaryVisible: json['salary_visible'] as bool? ?? false,
      deadline: parse(json['deadline']),
      workflowStatus:
          OfferWorkflowStatus.fromCode(json['workflow_status'] as String?),
      lifecycleStatus:
          OfferLifecycleStatus.fromCode(json['lifecycle_status'] as String?),
      isTemplate: json['is_template'] as bool? ?? false,
      templateName: json['template_name'] as String?,
      publishedAt: parse(json['published_at']),
      rejectionReason: json['rejection_reason'] as String?,
      createdBy: json['created_by'] as String?,
      validatedBy: json['validated_by'] as String?,
      createdAt: parse(json['created_at']) ?? DateTime.now(),
      updatedAt: parse(json['updated_at']) ?? DateTime.now(),
    );
  }

  /// Champs modifiables — la référence, les statuts et les horodatages sont
  /// gérés par la base et n'ont rien à faire dans une écriture cliente.
  Map<String, dynamic> toWritableJson() => {
        'title': title,
        'description': description,
        'requirements': requirements,
        'skills': skills,
        'contract_type': contractType.code,
        'location': location,
        'positions_count': positionsCount,
        'salary_min': salaryMin,
        'salary_max': salaryMax,
        'salary_currency': salaryCurrency,
        'salary_visible': salaryVisible,
        'deadline': deadline?.toIso8601String().substring(0, 10),
      };
}

/// Une étape franchie du workflow de validation.
class JobOfferTransition {
  final String id;
  final String jobOfferId;
  final OfferWorkflowStatus? fromStatus;
  final OfferWorkflowStatus toStatus;
  final String? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? reason;

  const JobOfferTransition({
    required this.id,
    required this.jobOfferId,
    required this.toStatus,
    required this.changedAt,
    this.fromStatus,
    this.changedBy,
    this.changedByName,
    this.reason,
  });

  factory JobOfferTransition.fromJson(Map<String, dynamic> json) {
    return JobOfferTransition(
      id: json['id'] as String,
      jobOfferId: json['job_offer_id'] as String,
      fromStatus: json['from_status'] == null
          ? null
          : OfferWorkflowStatus.fromCode(json['from_status'] as String),
      toStatus: OfferWorkflowStatus.fromCode(json['to_status'] as String?),
      changedBy: json['changed_by'] as String?,
      changedByName: json['changed_by_name'] as String?,
      changedAt:
          DateTime.tryParse(json['changed_at'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
    );
  }
}
