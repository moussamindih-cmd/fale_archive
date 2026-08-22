import 'package:flutter/material.dart';

/// Étape du pipeline de recrutement (§5.3.2).
///
/// Paramétrable par organisation : le cahier des charges impose un pipeline
/// configurable, l'enum Dart figé qu'il remplaçait ne pouvait pas l'être.
class PipelineStage {
  final String id;
  final String organizationId;
  final String code;
  final String label;
  final int position;

  /// Étape de sortie : la candidature ne bouge plus.
  final bool isTerminal;

  /// Étape de succès. Une seule par organisation — c'est elle qui borne le
  /// délai moyen de recrutement (§5.4.1).
  final bool isWon;

  /// Durée au-delà de laquelle la candidature est réputée stagner.
  final int? slaDays;

  final String? colorHex;
  final bool isActive;

  const PipelineStage({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.label,
    required this.position,
    this.isTerminal = false,
    this.isWon = false,
    this.slaDays,
    this.colorHex,
    this.isActive = true,
  });

  /// Étape terminale d'échec : terminale sans être gagnante.
  bool get isLost => isTerminal && !isWon;

  Color get color {
    final hex = colorHex;
    if (hex == null || hex.length != 7 || !hex.startsWith('#')) {
      return const Color(0xFF64748B);
    }
    final value = int.tryParse(hex.substring(1), radix: 16);
    return value == null ? const Color(0xFF64748B) : Color(0xFF000000 | value);
  }

  IconData get icon {
    if (isWon) return Icons.how_to_reg_rounded;
    if (isTerminal) return Icons.block_rounded;
    return Icons.radio_button_unchecked_rounded;
  }

  factory PipelineStage.fromJson(Map<String, dynamic> json) {
    return PipelineStage(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      code: json['code'] as String,
      label: json['label'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isTerminal: json['is_terminal'] as bool? ?? false,
      isWon: json['is_won'] as bool? ?? false,
      slaDays: (json['sla_days'] as num?)?.toInt(),
      colorHex: json['color'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Origine de la candidature — alimente l'indicateur « sources » (§5.4.1).
enum ApplicationSource {
  interne('interne', 'Interne'),
  siteWeb('site_web', 'Site web'),
  cooptation('cooptation', 'Cooptation'),
  reseauSocial('reseau_social', 'Réseau social'),
  cabinet('cabinet', 'Cabinet de recrutement'),
  spontanee('spontanee', 'Candidature spontanée'),
  salon('salon', 'Salon / forum'),
  autre('autre', 'Autre');

  final String code;
  final String label;
  const ApplicationSource(this.code, this.label);

  static ApplicationSource fromCode(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return ApplicationSource.interne;
  }
}

/// Candidature : le lien entre un candidat et une offre (§5.3).
class Application {
  final String id;
  final String organizationId;
  final String candidateId;

  /// Nul pour une candidature spontanée, ou pour les candidatures reprises
  /// de l'ancien modèle qui n'avaient pas d'offre.
  final String? jobOfferId;

  final String stageId;
  final ApplicationSource source;

  final DateTime appliedAt;

  /// Entrée dans l'étape courante — base du calcul de stagnation.
  final DateTime stageSince;

  /// Renseigné à l'entrée dans une étape terminale.
  final DateTime? closedAt;

  // Champs joints, pour l'affichage sans requête supplémentaire.
  final String? candidateName;
  final String? candidateEmail;
  final String? jobOfferTitle;
  final String? jobOfferReference;

  const Application({
    required this.id,
    required this.organizationId,
    required this.candidateId,
    required this.stageId,
    required this.appliedAt,
    required this.stageSince,
    this.jobOfferId,
    this.source = ApplicationSource.interne,
    this.closedAt,
    this.candidateName,
    this.candidateEmail,
    this.jobOfferTitle,
    this.jobOfferReference,
  });

  bool get isOpen => closedAt == null;
  bool get isSpontaneous => jobOfferId == null;

  /// Jours passés dans l'étape courante.
  int get daysInStage => DateTime.now().difference(stageSince).inDays;

  /// Durée totale du parcours, close ou en cours.
  int get totalDays => (closedAt ?? DateTime.now()).difference(appliedAt).inDays;

  /// Vrai si la candidature dépasse le délai fixé pour son étape.
  ///
  /// C'est ce qui fait remonter les dossiers oubliés : sans cela, une
  /// candidature peut rester des mois sans que personne ne s'en aperçoive.
  bool isStalled(PipelineStage stage) {
    if (!isOpen || stage.slaDays == null) return false;
    return daysInStage > stage.slaDays!;
  }

  factory Application.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);

    final candidate = json['candidates'] as Map<String, dynamic>?;
    final offer = json['job_offers'] as Map<String, dynamic>?;

    return Application(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      candidateId: json['candidate_id'] as String,
      jobOfferId: json['job_offer_id'] as String?,
      stageId: json['stage_id'] as String,
      source: ApplicationSource.fromCode(json['source'] as String?),
      appliedAt: parse(json['applied_at']) ?? DateTime.now(),
      stageSince: parse(json['stage_since']) ?? DateTime.now(),
      closedAt: parse(json['closed_at']),
      candidateName: candidate?['full_name'] as String?,
      candidateEmail: candidate?['email'] as String?,
      jobOfferTitle: offer?['title'] as String?,
      jobOfferReference: offer?['reference'] as String?,
    );
  }
}

/// Un passage d'étape — source de vérité des indicateurs de délai (§5.4.1).
class StageTransition {
  final String id;
  final String applicationId;
  final String? fromStageId;
  final String toStageId;
  final String? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? reason;
  final int? daysInPreviousStage;

  const StageTransition({
    required this.id,
    required this.applicationId,
    required this.toStageId,
    required this.changedAt,
    this.fromStageId,
    this.changedBy,
    this.changedByName,
    this.reason,
    this.daysInPreviousStage,
  });

  factory StageTransition.fromJson(Map<String, dynamic> json) {
    return StageTransition(
      id: json['id'] as String,
      applicationId: json['application_id'] as String,
      fromStageId: json['from_stage_id'] as String?,
      toStageId: json['to_stage_id'] as String,
      changedBy: json['changed_by'] as String?,
      changedByName: json['changed_by_name'] as String?,
      changedAt:
          DateTime.tryParse(json['changed_at'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
      daysInPreviousStage: (json['days_in_previous_stage'] as num?)?.toInt(),
    );
  }
}

/// Avis d'un recruteur sur une candidature (§5.3.3).
///
/// Remplace le bloc `rh_notes` unique et anonyme : chaque avis porte son
/// auteur, sa date et l'étape à laquelle il a été émis.
class ApplicationNote {
  final String id;
  final String applicationId;
  final String authorId;
  final String? authorName;
  final String body;

  /// Note sur 5, facultative : tous les commentaires ne sont pas des
  /// évaluations.
  final int? rating;

  final String? stageId;
  final DateTime createdAt;

  const ApplicationNote({
    required this.id,
    required this.applicationId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName,
    this.rating,
    this.stageId,
  });

  bool get isRating => rating != null;

  factory ApplicationNote.fromJson(Map<String, dynamic> json) {
    final author = json['employees'] as Map<String, dynamic>?;
    return ApplicationNote(
      id: json['id'] as String,
      applicationId: json['application_id'] as String,
      authorId: json['author_id'] as String,
      authorName: author?['full_name'] as String?,
      body: json['body'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt(),
      stageId: json['stage_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Statut d'un entretien.
enum InterviewStatus {
  planifie('planifie', 'Planifié', Color(0xFF3B82F6)),
  confirme('confirme', 'Confirmé', Color(0xFF10B981)),
  realise('realise', 'Réalisé', Color(0xFF64748B)),
  annule('annule', 'Annulé', Color(0xFFF59E0B)),
  absent('absent', 'Absent', Color(0xFFEF4444));

  final String code;
  final String label;
  final Color color;
  const InterviewStatus(this.code, this.label, this.color);

  static InterviewStatus fromCode(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return InterviewStatus.planifie;
  }

  bool get isPending => this == planifie || this == confirme;
}

/// Entretien planifié (§5.3.5).
class Interview {
  final String id;
  final String organizationId;
  final String applicationId;

  final DateTime scheduledAt;
  final int durationMinutes;
  final String? location;
  final String? meetingUrl;
  final List<String> interviewerIds;

  final InterviewStatus status;
  final String? outcome;

  /// Identifiant iCalendar, stable d'une mise à jour à l'autre : sans lui,
  /// chaque envoi créerait un doublon dans l'agenda du destinataire.
  final String icsUid;

  final DateTime createdAt;

  const Interview({
    required this.id,
    required this.organizationId,
    required this.applicationId,
    required this.scheduledAt,
    required this.icsUid,
    required this.createdAt,
    this.durationMinutes = 60,
    this.location,
    this.meetingUrl,
    this.interviewerIds = const [],
    this.status = InterviewStatus.planifie,
    this.outcome,
  });

  DateTime get endsAt => scheduledAt.add(Duration(minutes: durationMinutes));

  bool get isPast => endsAt.isBefore(DateTime.now());

  /// Entretien à venir et non annulé — ce qu'il faut faire remonter.
  bool get isUpcoming => !isPast && status.isPending;

  factory Interview.fromJson(Map<String, dynamic> json) {
    return Interview(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      applicationId: json['application_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      location: json['location'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      interviewerIds:
          (json['interviewer_ids'] as List?)?.cast<String>() ?? const [],
      status: InterviewStatus.fromCode(json['status'] as String?),
      outcome: json['outcome'] as String?,
      icsUid: json['ics_uid'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toWritableJson() => {
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'location': location,
        'meeting_url': meetingUrl,
        'interviewer_ids': interviewerIds,
        'status': status.code,
        'outcome': outcome,
      };
}
