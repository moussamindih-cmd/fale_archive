import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';
import '../models/fale_permission.dart';
import '../theme/app_theme.dart';
import '../theme/glassmorphism.dart';

/// Configuration d'un item de navigation
class NavItem {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final FalePermission? requiredPermission;

  const NavItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.requiredPermission,
  });
}

class RoleBasedNavUtils {
  static List<NavItem> itemsForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const [
          NavItem(index: 0, icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Admin'),
          NavItem(index: 1, icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: 'Archives'),
          NavItem(index: 2, icon: Icons.person_search_outlined, selectedIcon: Icons.person_search_rounded, label: 'Candidats'),
          NavItem(index: 3, icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Logistique'),
          NavItem(index: 4, icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts_rounded, label: 'Équipe'),
        ];
      case UserRole.directeurAdministratif:
        return const [
          NavItem(index: 0, icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Logistique'),
          NavItem(index: 1, icon: Icons.person_search_outlined, selectedIcon: Icons.person_search_rounded, label: 'Candidats'),
          NavItem(index: 2, icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: 'Archives'),
          NavItem(index: 3, icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profil'),
        ];
      case UserRole.rh:
        return const [
          NavItem(index: 0, icon: Icons.person_search_outlined, selectedIcon: Icons.person_search_rounded, label: 'Candidats'),
          NavItem(index: 1, icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: 'Archives'),
          NavItem(index: 2, icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profil'),
        ];
      case UserRole.employe:
        return const [
          NavItem(index: 0, icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Tableau de bord'),
          NavItem(index: 1, icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: 'Historique'),
        ];
    }
  }
}

/// Navigation adaptée au rôle connecté avec rendu SaaS haut de gamme (Barre du bas).
class RoleBasedNav extends StatelessWidget {
  final UserRole role;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const RoleBasedNav({
    super.key,
    required this.role,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = RoleBasedNavUtils.itemsForRole(role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      color: isDark ? const Color(0x33000000) : const Color(0x33FFFFFF),
      borderRadius: 0,
      blurX: 15,
      blurY: 15,
      border: Border(
        top: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),

      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isSelected = selectedIndex == item.index;
              final accent = isDark ? kPrimaryLight : kPrimaryColor;

              return Expanded(
                child: InkWell(
                  onTap: () => onDestinationSelected(item.index),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: accent.withValues(alpha: 0.1),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          size: 22,
                          color: isSelected
                              ? accent
                              : (isDark ? kDarkTextSecondary : kTextSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? accent
                                : (isDark ? kDarkTextSecondary : kTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Navigation latérale (Sidebar) pour le Web et Desktop.
class RoleBasedSidebar extends StatelessWidget {
  final UserRole role;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const RoleBasedSidebar({
    super.key,
    required this.role,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = RoleBasedNavUtils.itemsForRole(role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      width: 250,
      color: isDark ? const Color(0x33000000) : const Color(0x33FFFFFF),
      borderRadius: 0,
      blurX: 20,
      blurY: 20,
      border: Border(
        right: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'FALE',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: items.map((item) {
                final isSelected = selectedIndex == item.index;
                final accent = isDark ? kPrimaryLight : kPrimaryColor;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onDestinationSelected(item.index),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            size: 22,
                            color: isSelected
                                ? accent
                                : (isDark ? kDarkTextSecondary : kTextSecondary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item.label,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? accent
                                    : (isDark ? kDarkTextSecondary : kTextSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
