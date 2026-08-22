/// Modèle représentant une formule d'abonnement disponible
class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double amount;
  final String currency;
  final int durationDays;
  final List<String> features;
  final bool isActive;
  final int sortOrder;

  // Nouveaux champs pour la Phase 1 (Quotas et Période de grâce)
  final int maxUsers;
  final int maxStorageMb;
  final int gracePeriodDays;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.currency,
    required this.durationDays,
    required this.features,
    required this.isActive,
    required this.sortOrder,
    this.maxUsers = 1,
    this.maxStorageMb = 500,
    this.gracePeriodDays = 0,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    List<String> featuresList = [];
    if (rawFeatures is List) {
      featuresList = rawFeatures.map((f) => f.toString()).toList();
    }
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'XAF',
      durationDays: json['duration_days'] as int? ?? 30,
      features: featuresList,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      maxUsers: json['max_users'] as int? ?? 1,
      maxStorageMb: json['max_storage_mb'] as int? ?? 500,
      gracePeriodDays: json['grace_period_days'] as int? ?? 0,
    );
  }

  /// Libellé humain d'une feature
  static String featureLabel(String feature) {
    const labels = {
      'archivage_quotidien': 'Archivage quotidien',
      'archivage_illimite': 'Archivage illimité',
      'historique_30j': 'Historique 30 jours',
      'historique_illimite': 'Historique illimité',
      'export_pdf': 'Export PDF',
      'gestion_candidats': 'Gestion des candidats',
      'logistique': 'Module Logistique',
      'rapports_avances': 'Rapports avancés',
      '1_utilisateur': '1 utilisateur',
      '10_utilisateurs': 'Jusqu\'à 10 utilisateurs',
      'utilisateurs_illimites': 'Utilisateurs illimités',
      'support_prioritaire': 'Support prioritaire',
    };
    return labels[feature] ?? feature;
  }
}

/// Statut d'un abonnement
enum SubscriptionStatus {
  pending,
  paid,
  failed,
  expired,
  none;

  String get label {
    switch (this) {
      case SubscriptionStatus.pending:
        return 'En attente';
      case SubscriptionStatus.paid:
        return 'Actif';
      case SubscriptionStatus.failed:
        return 'Échoué';
      case SubscriptionStatus.expired:
        return 'Expiré';
      case SubscriptionStatus.none:
        return 'Aucun abonnement';
    }
  }

  static SubscriptionStatus fromString(String? s) {
    switch (s) {
      case 'pending':
        return SubscriptionStatus.pending;
      case 'paid':
        return SubscriptionStatus.paid;
      case 'failed':
        return SubscriptionStatus.failed;
      case 'expired':
        return SubscriptionStatus.expired;
      default:
        return SubscriptionStatus.none;
    }
  }
}

/// Opérateur de paiement mobile
enum PaymentOperator {
  moov,
  airtel;

  String get label {
    switch (this) {
      case PaymentOperator.moov:
        return 'Moov Money';
      case PaymentOperator.airtel:
        return 'Airtel Money';
    }
  }

  String get colorHex {
    switch (this) {
      case PaymentOperator.moov:
        return '#F59E0B'; // Amber — couleur Moov
      case PaymentOperator.airtel:
        return '#EF4444'; // Rouge — couleur Airtel
    }
  }

  static PaymentOperator fromString(String s) =>
      s == 'moov' ? PaymentOperator.moov : PaymentOperator.airtel;
}

/// Une ligne de transaction dans la table `subscriptions`
class SubscriptionTransaction {
  final String id;
  final String organizationId;
  final String planId;
  final String planName;
  final double amount;
  final String currency;
  final PaymentOperator operator;
  final String phoneNumber;
  final String? transactionReference;
  final SubscriptionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? activatedAt;
  final bool isInGracePeriod;

  const SubscriptionTransaction({
    required this.id,
    required this.organizationId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.operator,
    required this.phoneNumber,
    this.transactionReference,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.activatedAt,
    this.isInGracePeriod = false,
  });

  bool get isActive =>
      status == SubscriptionStatus.paid &&
      (isInGracePeriod || (expiresAt?.isAfter(DateTime.now()) ?? false));

  /// Jours restants avant expiration (0 si expiré)
  int get daysRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory SubscriptionTransaction.fromJson(Map<String, dynamic> json) {
    return SubscriptionTransaction(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      planId: json['plan_id'] as String,
      planName: json['plan_name'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'XAF',
      operator: PaymentOperator.fromString(
        json['operator'] as String? ?? 'moov',
      ),
      phoneNumber: json['phone_number'] as String? ?? '',
      transactionReference: json['transaction_reference'] as String?,
      status: SubscriptionStatus.fromString(json['payment_status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      activatedAt: json['activated_at'] != null
          ? DateTime.parse(json['activated_at'] as String)
          : null,
      isInGracePeriod: json['is_in_grace_period'] as bool? ?? false,
    );
  }
}

/// Résumé complet de l'abonnement d'une organisation
class SubscriptionInfo {
  final SubscriptionTransaction? activeTransaction;
  final List<SubscriptionTransaction> history;
  final SubscriptionPlan? activePlan;

  const SubscriptionInfo({
    this.activeTransaction,
    required this.history,
    this.activePlan,
  });

  bool get isActive => activeTransaction?.isActive ?? false;

  SubscriptionStatus get status =>
      activeTransaction?.status ?? SubscriptionStatus.none;
}
