import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/subscription_plan.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class SubscriptionScreen extends StatelessWidget {
  final AppStateProvider appState;

  const SubscriptionScreen({super.key, required this.appState});

  void _showUpgradeModal(BuildContext context, SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mise à niveau vers l offre ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarif: ${plan.priceMonthly}'),
            const SizedBox(height: 12),
            const Text(
              'Prêt pour intégration Stripe / Wave / Orange Money / Paiement par virement.\n'
              'Aucune clé de paiement n est configurée en environnement de démonstration.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Demande de souscription au plan ${plan.name} enregistrée !')),
              );
            },
            child: const Text('Confirmer la demande'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = appState.currentOrg;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Abonnement SaaS & Forfaits',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Gérez votre formule d abonnement, vos utilisateurs et vos quotas de stockage.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Offre Actuelle: ${org.planName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Storage & User Quota Progress Cards
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Consommation du Stockage Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${org.storageUsedGB} GB / ${org.storageLimitGB} GB utilisés'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: org.storagePercentage,
                            minHeight: 8,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Comptes Utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${appState.users.length} / ${org.maxUsers} utilisateurs actifs'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: appState.users.length / org.maxUsers,
                            minHeight: 8,
                            color: AppColors.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Grille des Forfaits SaaS FALE ARCHIVES',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          // Plan Cards Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              childAspectRatio: 0.72,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: SubscriptionPlan.plans.length,
            itemBuilder: (context, index) {
              final plan = SubscriptionPlan.plans[index];
              final isCurrent = plan.name == org.planName;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCurrent
                        ? AppColors.primary
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.isPopular) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'RECOMMANDÉ',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        plan.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.priceMonthly,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Divider(height: 20),
                      for (var feat in plan.features) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: AppColors.accentEmerald),
                            const SizedBox(width: 8),
                            Expanded(child: Text(feat, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      const Spacer(),
                      AppButton(
                        label: isCurrent ? 'Plan Actuel' : 'Choisir ce plan',
                        variant: isCurrent ? AppButtonVariant.secondary : AppButtonVariant.primary,
                        isFullWidth: true,
                        onPressed: isCurrent ? null : () => _showUpgradeModal(context, plan),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
