import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/responsive.dart';
import '../app_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/document_card.dart';
import '../widgets/app_button.dart';

class DashboardScreen extends StatelessWidget {
  final AppStateProvider appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docs = appState.documents;
    final totalDocs = docs.length;
    final pendingReqs = appState.accessRequests.where((r) => r.status.name == 'pending').length;
    final expiringCount = docs.where((d) => d.retentionStatus.name == 'expiringSoon').length;
    final org = appState.currentOrg;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Welcome & Quick Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, ${appState.currentUser.fullName} 👋',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Voici la synthèse de vos archives électroniques et physiques.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  AppButton(
                    label: 'Scanner document',
                    icon: Icons.document_scanner,
                    variant: AppButtonVariant.outlined,
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.scanner);
                    },
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Ajouter une archive',
                    icon: Icons.add,
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.addDocument);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Expiration Warning Alert Banner if any doc expiring soon
          if (expiringCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerte de conservation : $expiringCount document(s) expirent bientôt',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Veuillez examiner la durée de conservation et planifier le sort final (destruction ou archivage définitif).',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.archives);
                    },
                    child: const Text('Examiner', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Grid of Stat Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100
                  ? 4
                  : (constraints.maxWidth > 650 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  StatCard(
                    title: 'Total Documents',
                    value: '$totalDocs archives',
                    subtitle: '784 fichiers enregistrés',
                    icon: Icons.folder_copy,
                    color: AppColors.primary,
                  ),
                  StatCard(
                    title: 'Arborescence Dossiers',
                    value: '${appState.folders.length} dossiers',
                    subtitle: '5 départements connectés',
                    icon: Icons.account_tree,
                    color: AppColors.accentTeal,
                  ),
                  StatCard(
                    title: 'Stockage Utilisé',
                    value: '${org.storageUsedGB} GB / ${org.storageLimitGB} GB',
                    subtitle: '${(org.storagePercentage * 100).toStringAsFixed(1)}% du quota SaaS',
                    icon: Icons.cloud_done,
                    color: AppColors.accentPurple,
                    progressValue: org.storagePercentage,
                  ),
                  StatCard(
                    title: 'Demandes en attente',
                    value: '$pendingReqs demandes',
                    subtitle: '$expiringCount document(s) expirant bientôt',
                    icon: Icons.lock_clock,
                    color: AppColors.accentAmber,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Two Column Section: Recent Documents + Activity & Storage Distribution
          Responsive(
            mobile: Column(
              children: [
                _buildRecentDocsSection(context),
                const SizedBox(height: 24),
                _buildActivitySection(context),
              ],
            ),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentDocsSection(context)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildActivitySection(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDocsSection(BuildContext context) {
    final docs = appState.documents.take(4).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Documents numérisés récents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.archives);
                  },
                  child: const Text('Tout voir →'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return DocumentCard(
                  document: doc,
                  mode: DocumentViewMode.list,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.documentDetails,
                      arguments: doc,
                    );
                  },
                  onMoreTap: () {},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logs = appState.auditLogs.take(5).toList();

    return Column(
      children: [
        // Storage Breakdown Chart Simulation
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Répartition par catégorie',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                for (var cat in appState.categories) ...[
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(int.parse('0xFF${cat.colorHex}')),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cat.name, style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        '${cat.documentCount} docs',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (cat.documentCount / 400).clamp(0.05, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(int.parse('0xFF${cat.colorHex}')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Activity Timeline Feed
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activités récents du système',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (var log in logs) ...[
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                    ),
                    title: Text(
                      '${log.userName} • ${log.action}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    subtitle: Text(
                      'Cible: ${log.targetResource} • IP: ${log.ipAddress}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
