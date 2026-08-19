import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/role.dart';
import '../app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_navigation.dart';

class MainLayout extends StatefulWidget {
  final String activeRoute;
  final Widget child;
  final AppStateProvider appState;

  const MainLayout({
    super.key,
    required this.activeRoute,
    required this.child,
    required this.appState,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _mobileNavIndex = 0;

  void _onMobileNavTap(int index) {
    setState(() => _mobileNavIndex = index);
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed(AppRoutes.archives);
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed(AppRoutes.scanner);
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed(AppRoutes.notifications);
        break;
      case 4:
        Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(
              child: AppDrawer(
                activeRoute: widget.activeRoute,
                appState: widget.appState,
              ),
            ),
      body: Row(
        children: [
          // Pinned Sidebar on Desktop
          if (isDesktop)
            AppDrawer(
              activeRoute: widget.activeRoute,
              appState: widget.appState,
            ),
          
          // Main Body Area
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!isDesktop)
                        Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      // Tenant Org Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              widget.appState.currentOrg.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Global Quick Search Bar
                      if (isDesktop)
                        Expanded(
                          child: Container(
                            height: 40,
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.bgDark : AppColors.bgLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: TextField(
                              onChanged: widget.appState.setSearchQuery,
                              decoration: const InputDecoration(
                                hintText: 'Recherche rapide d archives, réfs...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Role Simulator Selector
                      Tooltip(
                        message: 'Simulateur de rôle utilisateur',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDark : AppColors.bgLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Role>(
                              value: widget.appState.currentUser.role,
                              icon: const Icon(Icons.shield_outlined, size: 18),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              onChanged: (Role? r) {
                                if (r != null) widget.appState.switchUserRole(r);
                              },
                              items: const [
                                DropdownMenuItem(value: Role.superAdmin, child: Text('Super Admin')),
                                DropdownMenuItem(value: Role.administrator, child: Text('Admin')),
                                DropdownMenuItem(value: Role.archivist, child: Text('Archiviste')),
                                DropdownMenuItem(value: Role.secretaire, child: Text('Secrétaire')),
                                DropdownMenuItem(value: Role.comptable, child: Text('Comptable')),
                                DropdownMenuItem(value: Role.gestionnaire, child: Text('Gestionnaire')),
                                DropdownMenuItem(value: Role.conseillerPrincipal, child: Text('Conseiller Principal')),
                                DropdownMenuItem(value: Role.conseillerAdjoint, child: Text('Conseiller Adjoint')),
                                DropdownMenuItem(value: Role.auditor, child: Text('Auditeur')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Language Selector
                      IconButton(
                        icon: Text(
                          widget.appState.currentLanguage,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        tooltip: 'Changer la langue (FR/EN/AR)',
                        onPressed: () {
                          final next = widget.appState.currentLanguage == 'FR'
                              ? 'EN'
                              : (widget.appState.currentLanguage == 'EN' ? 'AR' : 'FR');
                          widget.appState.setLanguage(next);
                        },
                      ),
                      // Dark / Light Theme Toggle
                      IconButton(
                        icon: Icon(
                          widget.appState.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          size: 20,
                        ),
                        tooltip: 'Mode sombre / clair',
                        onPressed: widget.appState.toggleTheme,
                      ),
                      // Notifications Center Trigger
                      IconButton(
                        icon: Badge(
                          isLabelVisible: widget.appState.unreadNotificationsCount > 0,
                          label: Text('${widget.appState.unreadNotificationsCount}'),
                          child: const Icon(Icons.notifications_outlined, size: 22),
                        ),
                        tooltip: 'Notifications',
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.notifications);
                        },
                      ),
                    ],
                  ),
                ),

                // Main Content View
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : AppBottomNavigation(
              currentIndex: _mobileNavIndex,
              onTap: _onMobileNavTap,
              unreadNotifications: widget.appState.unreadNotificationsCount,
            ),
    );
  }
}
