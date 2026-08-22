/// Moteur de conservation légale des archives (§5.1.4).
///
/// Le calcul est volontairement pur et sans dépendance : il est rejoué à
/// l'identique côté base par la fonction `apply_retention()`. Le client s'en
/// sert pour afficher les échéances, le serveur pour purger — les deux doivent
/// donner le même résultat, d'où l'absence de toute logique d'affichage ici.
library;

/// Ce que devient une archive au terme de sa durée de conservation.
enum RetentionAction {
  /// Destruction définitive après le délai.
  destroy('destroy', 'Détruire'),

  /// Versement en archive définitive, jamais détruite.
  archive('archive', 'Archiver définitivement'),

  /// Décision humaine requise à l'échéance.
  review('review', 'Revue manuelle');

  final String code;
  final String label;
  const RetentionAction(this.code, this.label);

  static RetentionAction fromCode(String? code) {
    for (final action in RetentionAction.values) {
      if (action.code == code) return action;
    }
    return RetentionAction.review;
  }
}

/// Position d'une archive dans son cycle de conservation.
enum RetentionStatus {
  active('Conservation en cours'),
  expiringSoon('Échéance proche'),
  expired('Échue'),
  toDestroy('À détruire'),
  legalHold('Gel conservatoire');

  final String label;
  const RetentionStatus(this.label);

  bool get requiresAttention =>
      this == RetentionStatus.expiringSoon ||
      this == RetentionStatus.expired ||
      this == RetentionStatus.toDestroy;
}

/// Règle de conservation attachée à un type de document.
///
/// Reflet côté Dart de la table `document_types`.
class RetentionRule {
  final String id;
  final String label;

  /// Durée légale de conservation, en années révolues.
  final int retentionYears;

  /// Préavis avant échéance, en jours, pour l'alerte.
  final int warningDays;

  final RetentionAction action;

  /// Texte légal fondant la durée — affiché dans les rapports de conformité.
  final String? legalBasis;

  const RetentionRule({
    required this.id,
    required this.label,
    this.retentionYears = 10,
    this.warningDays = 90,
    this.action = RetentionAction.review,
    this.legalBasis,
  });

  factory RetentionRule.fromJson(Map<String, dynamic> json) {
    return RetentionRule(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Sans libellé',
      retentionYears: (json['retention_years'] as num?)?.toInt() ?? 10,
      warningDays: (json['warning_days'] as num?)?.toInt() ?? 90,
      action: RetentionAction.fromCode(json['retention_action'] as String?),
      legalBasis: json['legal_basis'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'retention_years': retentionYears,
        'warning_days': warningDays,
        'retention_action': action.code,
        'legal_basis': legalBasis,
      };
}

/// Évaluation d'une archive au regard de sa règle de conservation.
class RetentionAssessment {
  final RetentionStatus status;
  final DateTime dueDate;
  final int daysRemaining;
  final RetentionAction action;

  const RetentionAssessment({
    required this.status,
    required this.dueDate,
    required this.daysRemaining,
    required this.action,
  });

  /// Vrai si l'archive peut être purgée automatiquement, sans intervention.
  bool get isPurgeable => status == RetentionStatus.toDestroy;
}

class RetentionService {
  const RetentionService._();

  /// Règle appliquée quand aucun type de document n'est renseigné.
  /// Volontairement en revue manuelle : en l'absence de base légale explicite,
  /// rien ne doit être détruit automatiquement.
  static const RetentionRule defaultRule = RetentionRule(
    id: '_default',
    label: 'Règle par défaut',
    retentionYears: 10,
    warningDays: 90,
    action: RetentionAction.review,
  );

  /// Date d'échéance = date d'archivage + N années **calendaires**.
  ///
  /// L'ajout se fait par `DateTime(année + n, …)` et non par une durée en
  /// jours : une durée de 10 ans exprimée en `10 * 365` jours dérive d'environ
  /// deux jours et demi à cause des années bissextiles, ce qui suffit à faire
  /// purger un document avant son terme légal.
  ///
  /// Le 29 février est ramené au 28 lorsque l'année d'échéance n'est pas
  /// bissextile — `DateTime` déborderait sinon sur le 1er mars.
  static DateTime dueDateFor(DateTime archivedAt, int retentionYears) {
    final targetYear = archivedAt.year + retentionYears;
    final lastDayOfMonth = DateTime(targetYear, archivedAt.month + 1, 0).day;
    final day = archivedAt.day > lastDayOfMonth ? lastDayOfMonth : archivedAt.day;
    return DateTime(targetYear, archivedAt.month, day);
  }

  /// Évalue une archive. [legalHold] gèle le cycle : une archive sous gel
  /// conservatoire n'est jamais purgée, quelle que soit son échéance.
  static RetentionAssessment evaluate({
    required DateTime archivedAt,
    RetentionRule? rule,
    bool legalHold = false,
    DateTime? now,
  }) {
    final effectiveRule = rule ?? defaultRule;
    final today = _dateOnly(now ?? DateTime.now());
    final dueDate = dueDateFor(_dateOnly(archivedAt), effectiveRule.retentionYears);
    final daysRemaining = dueDate.difference(today).inDays;

    if (legalHold) {
      return RetentionAssessment(
        status: RetentionStatus.legalHold,
        dueDate: dueDate,
        daysRemaining: daysRemaining,
        action: effectiveRule.action,
      );
    }

    final RetentionStatus status;
    if (daysRemaining > effectiveRule.warningDays) {
      status = RetentionStatus.active;
    } else if (daysRemaining > 0) {
      status = RetentionStatus.expiringSoon;
    } else if (effectiveRule.action == RetentionAction.destroy) {
      status = RetentionStatus.toDestroy;
    } else {
      status = RetentionStatus.expired;
    }

    return RetentionAssessment(
      status: status,
      dueDate: dueDate,
      daysRemaining: daysRemaining,
      action: effectiveRule.action,
    );
  }

  /// Taux de conformité de conservation (§5.4.2) : part des archives dont la
  /// règle de conservation est connue et l'échéance non dépassée sans décision.
  ///
  /// Une archive échue laissée en l'état est *non conforme* : c'est
  /// précisément ce que l'indicateur doit faire remonter.
  static double complianceRate(Iterable<RetentionAssessment> assessments) {
    final total = assessments.length;
    if (total == 0) return 1;
    final compliant = assessments
        .where((a) =>
            a.status == RetentionStatus.active ||
            a.status == RetentionStatus.expiringSoon ||
            a.status == RetentionStatus.legalHold)
        .length;
    return compliant / total;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
