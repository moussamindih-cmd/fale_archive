import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../app_state.dart';

class AppDrawer extends StatelessWidget {
  final String activeRoute;
  final Function(String route)? onSelectRoute;
  final AppStateProvider appState;

  const AppDrawer({
    super.key,
    required this.activeRoute,
    this.onSelectRoute,
    required this.appState,
  });

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    int? badgeCount,
  }) {
    final isSelected = activeRoute == route;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (onSelectRoute != null) {
              onSelectRoute!(route);
            } else {
              Navigator.of(context).pushReplacementNamed(route);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentCrimson,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Column(
        children: [
          // Branding Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.archive, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FALE ARCHIVES',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'SaaS GED Platform',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // FALE TECH Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 12, color: AppColors.accentTeal),
                      const SizedBox(width: 6),
                      Text(
                        'Propulsé par FALE TECH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.accentTeal : const Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Scrollable List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.dashboard_outlined,
                  label: 'Tableau de bord',
                  route: AppRoutes.dashboard,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.folder_copy_outlined,
                  label: 'Archives numérisées',
                  route: AppRoutes.archives,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.edit_calendar_outlined,
                  label: 'Archives Journalières',
                  route: AppRoutes.dailyArchives,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.account_tree_outlined,
                  label: 'Dossiers & Arborescence',
                  route: AppRoutes.folders,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.document_scanner_outlined,
                  label: 'Scanner document',
                  route: AppRoutes.scanner,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.psychology_outlined,
                  label: 'ArchiveAI Assistant',
                  route: AppRoutes.archiveAI,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.search_outlined,
                  label: 'Recherche avancée',
                  route: AppRoutes.search,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.lock_clock_outlined,
                  label: 'Demandes d accès',
                  route: AppRoutes.requests,
                  badgeCount: appState.accessRequests
                      .where((r) => r.status.name == 'pending')
                      .length,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  route: AppRoutes.notifications,
                  badgeCount: appState.unreadNotificationsCount,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.history_edu_outlined,
                  label: 'Journal d audit',
                  route: AppRoutes.audit,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Divider(),
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.people_alt_outlined,
                  label: 'Utilisateurs & Rôles',
                  route: AppRoutes.users,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.corporate_fare_outlined,
                  label: 'Départements',
                  route: AppRoutes.departments,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.category_outlined,
                  label: 'Catégories',
                  route: AppRoutes.categories,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.inventory_2_outlined,
                  label: 'Archives physiques (GAE)',
                  route: AppRoutes.physicalArchives,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.analytics_outlined,
                  label: 'Rapports & Stats',
                  route: AppRoutes.reports,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.card_membership_outlined,
                  label: 'Abonnement SaaS',
                  route: AppRoutes.subscription,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  label: 'Paramètres Organisation',
                  route: AppRoutes.settings,
                ),
              ],
            ),
          ),

          // User Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    appState.currentUser.fullName.substring(0, 1),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appState.currentUser.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        appState.currentUser.role.name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20, color: AppColors.accentCrimson),
                  tooltip: 'Se déconnecter',
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
