import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';
import '../models/fale_permission.dart';
import '../theme/app_theme.dart';

/// Configuration d'un item de navigation
class NavItem {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Libellé abrégé pour la barre du bas, où la place est comptée.
  /// Retombe sur [label] lorsqu'il n'est pas fourni.
  final String? short;

  final FalePermission? requiredPermission;

  const NavItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.short,
    this.requiredPermission,
  });

  String get shortLabel => short ?? label;
}

class RoleBasedNavUtils {
  static List<NavItem> itemsForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const [
          NavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Admin',
          ),
          NavItem(
            index: 1,
            icon: Icons.history_outlined,
            selectedIcon: Icons.history_rounded,
            label: 'Archives',
          ),
          NavItem(
            index: 2,
            icon: Icons.person_search_outlined,
            selectedIcon: Icons.person_search_rounded,
            label: 'Candidats',
          ),
          NavItem(
            index: 3,
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Logistique',
          ),
          NavItem(
            index: 4,
            icon: Icons.manage_accounts_outlined,
            selectedIcon: Icons.manage_accounts_rounded,
            label: 'Équipe',
          ),
        ];
      case UserRole.directeurAdministratif:
        return const [
          NavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Tableau de bord',
            short: 'Accueil',
          ),
          NavItem(
            index: 1,
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Logistique',
          ),
          NavItem(
            index: 2,
            icon: Icons.person_search_outlined,
            selectedIcon: Icons.person_search_rounded,
            label: 'Candidats',
          ),
          NavItem(
            index: 3,
            icon: Icons.history_outlined,
            selectedIcon: Icons.history_rounded,
            label: 'Archives',
          ),
          NavItem(
            index: 4,
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profil',
          ),
        ];
      case UserRole.rh:
        return const [
          NavItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Tableau de bord',
            short: 'Accueil',
          ),
          NavItem(
            index: 1,
            icon: Icons.person_search_outlined,
            selectedIcon: Icons.person_search_rounded,
            label: 'Candidats',
          ),
          NavItem(
            index: 2,
            icon: Icons.history_outlined,
            selectedIcon: Icons.history_rounded,
            label: 'Archives',
          ),
          NavItem(
            index: 3,
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profil',
          ),
        ];
      case UserRole.employe:
        return const [
          NavItem(
            index: 0,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Tableau de bord',
            short: 'Accueil',
          ),
          NavItem(
            index: 1,
            icon: Icons.history_outlined,
            selectedIcon: Icons.history_rounded,
            label: 'Historique',
          ),
        ];
    }
  }
}

/// Navigation adaptée au rôle connecté (barre du bas, mobile).
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
    final accent = isDark ? kPrimaryLight : kPrimaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kSurface,
        border: Border(
          top: BorderSide(color: isDark ? kDarkBorder : kBorderColor),
        ),
        boxShadow: isDark ? null : kSoftShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: items.map((item) {
              final isSelected = selectedIndex == item.index;

              return Expanded(
                child: InkWell(
                  onTap: () => onDestinationSelected(item.index),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: accent.withValues(alpha: 0.1),
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicateur pilule autour de l'icône
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          size: 21,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? kDarkTextSecondary : kTextSecondary),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? accent
                              : (isDark ? kDarkTextSecondary : kTextSecondary),
                        ),
                      ),
                    ],
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

  /// Ouvre l'écran des notifications depuis le pied de sidebar.
  final VoidCallback? onNotifications;

  /// Compteur de notifications non lues, affiché en badge.
  final int unreadCount;

  /// Affiche la tuile « Se déconnecter » en pied de sidebar lorsqu'il est fourni.
  final VoidCallback? onLogout;

  const RoleBasedSidebar({
    super.key,
    required this.role,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onNotifications,
    this.unreadCount = 0,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final items = RoleBasedNavUtils.itemsForRole(role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kSurface,
        border: Border(
          right: BorderSide(color: isDark ? kDarkBorder : kBorderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FALE',
                        style: GoogleFonts.outfit(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Archives',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? kDarkTextMuted : kTextMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Items de navigation ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 22, bottom: 10),
            child: Text(
              'NAVIGATION',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? kDarkTextMuted : kTextMuted,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: items
                  .map(
                    (item) => _SidebarTile(
                      item: item,
                      isSelected: selectedIndex == item.index,
                      onTap: () => onDestinationSelected(item.index),
                    ),
                  )
                  .toList(),
            ),
          ),

          // ── Pied : notifications & déconnexion ────────────────────────────
          if (onNotifications != null || onLogout != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
              child: Column(
                children: [
                  Divider(
                    color: isDark ? kDarkBorder : kBorderColor,
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: 12),
                  if (onNotifications != null)
                    _SidebarTile(
                      item: const NavItem(
                        index: -1,
                        icon: Icons.notifications_none_rounded,
                        selectedIcon: Icons.notifications_rounded,
                        label: 'Notifications',
                      ),
                      isSelected: false,
                      badge: unreadCount,
                      onTap: onNotifications!,
                    ),
                  if (onLogout != null)
                    InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: kDanger,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Se déconnecter',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kDanger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tuile de la sidebar : pilule indigo pleine lorsqu'elle est active.
class _SidebarTile extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final int badge;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = widget.isSelected;
    final accent = isDark ? kPrimaryLight : kPrimaryColor;

    final Color background;
    if (isSelected) {
      background = accent;
    } else if (_hovered) {
      background = isDark ? kDarkSurfaceSubtle : kSurfaceSubtle;
    } else {
      background = Colors.transparent;
    }

    final foreground = isSelected
        ? Colors.white
        : (isDark ? kDarkTextSecondary : kTextSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          // Material transparent : le ripple reste visible au-dessus du fond.
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? widget.item.selectedIcon : widget.item.icon,
                      size: 20,
                      color: foreground,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                    if (widget.badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : kDanger,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${widget.badge}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? accent : Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
