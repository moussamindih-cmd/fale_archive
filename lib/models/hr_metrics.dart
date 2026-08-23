/// Indicateurs RH et d'archivage (§5.4).
///
/// Tous sont calculés par des vues SQL : les agréger côté client
/// supposerait de rapatrier l'intégralité des candidatures et des archives,
/// ce qui ne tient pas au-delà de quelques milliers de lignes et interdit
/// tout historique.
library;

/// Délai de recrutement, par offre et par mois (§5.4.1).
class TimeToHireMetric {
  final String? jobOfferId;
  final String? offerReference;
  final String? offerTitle;
  final DateTime? month;
  final int hires;
  final double avgDays;
  final int minDays;
  final int maxDays;

  const TimeToHireMetric({
    required this.hires,
    required this.avgDays,
    required this.minDays,
    required this.maxDays,
    this.jobOfferId,
    this.offerReference,
    this.offerTitle,
    this.month,
  });

  String get label => offerTitle ?? 'Candidatures spontanées';

  /// Écart entre le recrutement le plus rapide et le plus lent : une
  /// moyenne seule masque des parcours très inégaux.
  int get spread => maxDays - minDays;

  factory TimeToHireMetric.fromJson(Map<String, dynamic> json) {
    return TimeToHireMetric(
      jobOfferId: json['job_offer_id'] as String?,
      offerReference: json['offer_reference'] as String?,
      offerTitle: json['offer_title'] as String?,
      month: json['month'] == null
          ? null
          : DateTime.tryParse(json['month'] as String),
      hires: (json['hires'] as num?)?.toInt() ?? 0,
      avgDays: (json['avg_days'] as num?)?.toDouble() ?? 0,
      minDays: (json['min_days'] as num?)?.toInt() ?? 0,
      maxDays: (json['max_days'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un palier de l'entonnoir de recrutement (§5.4.1).
class FunnelStep {
  final String stageId;
  final String stageCode;
  final String stageLabel;
  final int position;
  final bool isTerminal;
  final bool isWon;

  /// Candidatures ayant **atteint** l'étape, d'après l'historique — et non
  /// celles qui s'y trouvent à l'instant. Une candidature passée par
  /// l'entretien puis rejetée compte dans l'entretien.
  final int reachedCount;

  final int? previousCount;

  /// Conversion depuis l'étape précédente du parcours. Nulle pour les
  /// étapes terminales, qui sortent du parcours au lieu de le poursuivre.
  final double? conversionRatePct;

  const FunnelStep({
    required this.stageId,
    required this.stageCode,
    required this.stageLabel,
    required this.position,
    required this.reachedCount,
    this.isTerminal = false,
    this.isWon = false,
    this.previousCount,
    this.conversionRatePct,
  });

  factory FunnelStep.fromJson(Map<String, dynamic> json) {
    return FunnelStep(
      stageId: json['stage_id'] as String,
      stageCode: json['stage_code'] as String? ?? '',
      stageLabel: json['stage_label'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      isTerminal: json['is_terminal'] as bool? ?? false,
      isWon: json['is_won'] as bool? ?? false,
      reachedCount: (json['reached_count'] as num?)?.toInt() ?? 0,
      previousCount: (json['previous_count'] as num?)?.toInt(),
      conversionRatePct: (json['conversion_rate_pct'] as num?)?.toDouble(),
    );
  }
}

/// Performance d'une source de candidature (§5.4.1).
class SourceMetric {
  final String source;
  final int total;
  final int hired;
  final int inProgress;

  /// Rapporté aux seules candidatures closes : inclure celles en cours
  /// ferait mécaniquement baisser toute source récente.
  final double? successRatePct;

  const SourceMetric({
    required this.source,
    required this.total,
    required this.hired,
    required this.inProgress,
    this.successRatePct,
  });

  factory SourceMetric.fromJson(Map<String, dynamic> json) {
    return SourceMetric(
      source: json['source'] as String? ?? 'autre',
      total: (json['total'] as num?)?.toInt() ?? 0,
      hired: (json['hired'] as num?)?.toInt() ?? 0,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
      successRatePct: (json['success_rate_pct'] as num?)?.toDouble(),
    );
  }
}

/// Volume archivé par mois et par catégorie (§5.4.2).
class ArchiveVolumeMetric {
  final DateTime month;
  final String? categoryLabel;
  final int archiveCount;
  final int documentCount;
  final int totalBytes;

  const ArchiveVolumeMetric({
    required this.month,
    required this.archiveCount,
    required this.documentCount,
    required this.totalBytes,
    this.categoryLabel,
  });

  String get readableSize {
    if (totalBytes < 1024) return '$totalBytes o';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} Ko';
    }
    if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  factory ArchiveVolumeMetric.fromJson(Map<String, dynamic> json) {
    return ArchiveVolumeMetric(
      month: DateTime.tryParse(json['month'] as String? ?? '') ?? DateTime.now(),
      categoryLabel: json['category_label'] as String?,
      archiveCount: (json['archive_count'] as num?)?.toInt() ?? 0,
      documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Conformité des durées légales de conservation (§5.4.2).
class RetentionCompliance {
  final int total;
  final int compliant;
  final int expiringSoon;
  final int expired;
  final int unclassified;
  final int legalHold;
  final int purged;
  final double? complianceRatePct;

  const RetentionCompliance({
    required this.total,
    required this.compliant,
    required this.expiringSoon,
    required this.expired,
    required this.unclassified,
    required this.legalHold,
    required this.purged,
    this.complianceRatePct,
  });

  const RetentionCompliance.empty()
      : total = 0,
        compliant = 0,
        expiringSoon = 0,
        expired = 0,
        unclassified = 0,
        legalHold = 0,
        purged = 0,
        complianceRatePct = null;

  /// Archives qui demandent une décision : échues sans action, ou déposées
  /// sans règle de conservation.
  int get needsAttention => expired + unclassified;

  factory RetentionCompliance.fromJson(Map<String, dynamic> json) {
    return RetentionCompliance(
      total: (json['total'] as num?)?.toInt() ?? 0,
      compliant: (json['compliant'] as num?)?.toInt() ?? 0,
      expiringSoon: (json['expiring_soon'] as num?)?.toInt() ?? 0,
      expired: (json['expired'] as num?)?.toInt() ?? 0,
      unclassified: (json['unclassified'] as num?)?.toInt() ?? 0,
      legalHold: (json['legal_hold'] as num?)?.toInt() ?? 0,
      purged: (json['purged'] as num?)?.toInt() ?? 0,
      complianceRatePct: (json['compliance_rate_pct'] as num?)?.toDouble(),
    );
  }
}

/// Synthèse du pilotage, obtenue en un seul appel.
class DashboardSummary {
  final int openApplications;
  final int hiresThisYear;
  final double? avgTimeToHire;
  final int publishedOffers;
  final int upcomingInterviews;
  final int archivesThisMonth;
  final double? retentionCompliancePct;

  const DashboardSummary({
    this.openApplications = 0,
    this.hiresThisYear = 0,
    this.avgTimeToHire,
    this.publishedOffers = 0,
    this.upcomingInterviews = 0,
    this.archivesThisMonth = 0,
    this.retentionCompliancePct,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      openApplications: (json['open_applications'] as num?)?.toInt() ?? 0,
      hiresThisYear: (json['hires_this_year'] as num?)?.toInt() ?? 0,
      avgTimeToHire: (json['avg_time_to_hire'] as num?)?.toDouble(),
      publishedOffers: (json['published_offers'] as num?)?.toInt() ?? 0,
      upcomingInterviews: (json['upcoming_interviews'] as num?)?.toInt() ?? 0,
      archivesThisMonth: (json['archives_this_month'] as num?)?.toInt() ?? 0,
      retentionCompliancePct:
          (json['retention_compliance_pct'] as num?)?.toDouble(),
    );
  }
}
