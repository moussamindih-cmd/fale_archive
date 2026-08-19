class SubscriptionPlan {
  final String id;
  final String name;
  final String priceMonthly;
  final int maxUsers;
  final double storageGB;
  final List<String> features;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.maxUsers,
    required this.storageGB,
    required this.features,
    this.isPopular = false,
  });

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'plan_free',
      name: 'FREE',
      priceMonthly: '0 FCFA / mois',
      maxUsers: 2,
      storageGB: 1,
      features: [
        '2 Utilisateurs',
        '1 Go de Stockage',
        'jusqu\'à 500 documents',
        'Recherche de base',
      ],
    ),
    SubscriptionPlan(
      id: 'plan_basic',
      name: 'BASIC',
      priceMonthly: '25 000 FCFA / mois',
      maxUsers: 10,
      storageGB: 20,
      features: [
        '10 Utilisateurs',
        '20 Go de Stockage',
        'Gestion des versions',
        'Exportation PDF & Excel',
      ],
    ),
    SubscriptionPlan(
      id: 'plan_business',
      name: 'BUSINESS',
      priceMonthly: '75 000 FCFA / mois',
      maxUsers: 50,
      storageGB: 100,
      features: [
        '50 Utilisateurs',
        '100 Go de Stockage',
        'Scanner & OCR Intégré',
        'Workflows & Valdateurs',
        'ArchiveAI Assistant',
      ],
      isPopular: true,
    ),
    SubscriptionPlan(
      id: 'plan_enterprise',
      name: 'ENTERPRISE',
      priceMonthly: 'Sur mesure',
      maxUsers: 999,
      storageGB: 1000,
      features: [
        'Utilisateurs illimités',
        'Stockage illimité / S3',
        'Accès API complet & Webhooks',
        'Support Dédié 24/7',
        'Infrastructure privée',
      ],
    ),
  ];
}
