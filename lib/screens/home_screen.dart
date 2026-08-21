import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_state.dart';
import '../state/candidates_state.dart';
import '../state/logistics_state.dart';
import '../state/theme_state.dart';
import '../state/notifications_state.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../models/employee.dart';
import '../widgets/role_based_nav.dart';
import '../widgets/global_search_dialog.dart';
import 'login_screen.dart';
import 'submit_archive_screen.dart';
import 'history_screen.dart';
import 'candidates/candidates_list_screen.dart';
import 'logistics/logistics_list_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/user_management_screen.dart';
import 'dashboards/employee_dashboard_screen.dart';
import 'dashboards/directeur_dashboard_screen.dart';
import 'dashboards/rh_dashboard_screen.dart';
import 'notifications_screen.dart';
import 'reports/reports_screen.dart';
import '../state/subscription_state.dart';
import 'subscription/subscription_screen.dart';
import 'admin/subscription_admin_screen.dart';
import 'admin/audit_logs_screen.dart';
import 'trash_screen.dart';

/// Largeur à partir de laquelle la sidebar remplace la barre du bas.
const double _kSidebarBreakpoint = 800;

class HomeScreen extends StatefulWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;
  final ThemeState? themeState;
  final NotificationsState? notificationsState;
  final SubscriptionState? subscriptionState;

  const HomeScreen({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
    this.themeState,
    this.notificationsState,
    this.subscriptionState,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  AppState get _appState => widget.appState;
  CandidatesState get _candidatesState => widget.candidatesState;
  LogisticsState get _logisticsState => widget.logisticsState;
  late final NotificationsState _notificationsState;
  late final ThemeState _themeState;
  late final SubscriptionState _subscriptionState;

  @override
  void initState() {
    super.initState();
    _notificationsState = widget.notificationsState ?? NotificationsState();
    _themeState = widget.themeState ?? ThemeState();
    _subscriptionState = widget.subscriptionState ?? SubscriptionState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appState.currentEmployee != null) {
        _subscriptionState.load('org-creposa-default-id');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _appState,
        _notificationsState,
        _themeState,
      ]),
      builder: (context, _) {
        final emp = _appState.currentEmployee;
        if (emp == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = emp.role;
        final navItems = RoleBasedNavUtils.itemsForRole(role);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final safeIndex = _tabIndex < navItems.length ? _tabIndex : 0;
        final unreadNotifs = _notificationsState.unreadCount(
          userId: emp.id,
          role: role,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > _kSidebarBreakpoint;

            if (isWide) {
              return Scaffold(
                backgroundColor: isDark ? kDarkBackground : kBackground,
                body: Row(
                  children: [
                    RoleBasedSidebar(
                      role: role,
                      selectedIndex: safeIndex,
                      onDestinationSelected: (i) =>
                          setState(() => _tabIndex = i),
                      onNotifications: _openNotifications,
                      unreadCount: unreadNotifs,
                      onLogout: _logout,
                    ),
                    Expanded(
                      child: Scaffold(
                        appBar: _buildAppBar(
                          emp: emp,
                          role: role,
                          isDark: isDark,
                          unreadNotifs: unreadNotifs,
                          showSearchField: true,
                        ),
                        backgroundColor: isDark ? kDarkBackground : kBackground,
                        body: _buildBody(role, safeIndex),
                        floatingActionButton: _buildFAB(role, safeIndex, emp),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: isDark ? kDarkBackground : kBackground,
              appBar: _buildAppBar(
                emp: emp,
                role: role,
                isDark: isDark,
                unreadNotifs: unreadNotifs,
                showSearchField: false,
              ),
              body: _buildBody(role, safeIndex),
              bottomNavigationBar: RoleBasedNav(
                role: role,
                selectedIndex: safeIndex,
                onDestinationSelected: (i) => setState(() => _tabIndex = i),
              ),
              floatingActionButton: _buildFAB(role, safeIndex, emp),
            );
          },
        );
      },
    );
  }

  // ── Barre du haut ────────────────────────────────────────────────────────
  //
  // Desktop : champ de recherche à gauche, actions puis bloc profil à droite.
  // Mobile  : avatar et identité à gauche, actions (dont la loupe) à droite.
  PreferredSizeWidget _buildAppBar({
    required Employee emp,
    required UserRole role,
    required bool isDark,
    required int unreadNotifs,
    required bool showSearchField,
  }) {
    return AppBar(
      elevation: 0,
      titleSpacing: 16,
      backgroundColor: isDark ? kDarkSurface : kSurface,
      shape: Border(
        bottom: BorderSide(color: isDark ? kDarkBorder : kBorderColor),
      ),
      title: showSearchField
          ? _buildSearchField(isDark)
          : _buildIdentity(emp, isDark),
      actions: [
        if (!showSearchField)
          IconButton(
            tooltip: 'Recherche globale',
            icon: Icon(
              Icons.search_rounded,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
              size: 22,
            ),
            onPressed: _openGlobalSearch,
          ),
        // Rapports & Exports
        IconButton(
          tooltip: 'Rapports & Exports',
          icon: Icon(
            Icons.insights_rounded,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
            size: 21,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportsScreen(
                appState: _appState,
                candidatesState: _candidatesState,
                logisticsState: _logisticsState,
              ),
            ),
          ),
        ),
        // Abonnement
        if (role == UserRole.admin || role == UserRole.directeurAdministratif)
          IconButton(
            tooltip: 'Abonnement SaaS',
            icon: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubscriptionScreen(
                  subscriptionState: _subscriptionState,
                  organizationId: 'org-creposa-default-id',
                ),
              ),
            ),
          ),
        // Notifications avec badge
        IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unreadNotifs > 0,
            label: Text('$unreadNotifs'),
            backgroundColor: kDanger,
            child: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
              size: 22,
            ),
          ),
          onPressed: _openNotifications,
        ),
        // Bascule clair / sombre
        IconButton(
          tooltip: isDark ? 'Mode clair' : 'Mode sombre',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
            color: isDark ? const Color(0xFFFBBF24) : kTextSecondary,
            size: 21,
          ),
          onPressed: () => _themeState.toggleTheme(),
        ),
        // Bloc profil, à droite comme dans la maquette
        if (showSearchField) ...[
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 26,
            color: isDark ? kDarkBorder : kBorderColor,
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildIdentity(emp, isDark),
          ),
        ] else
          const SizedBox(width: 4),
      ],
    );
  }

  /// Champ de recherche cliquable qui ouvre le dialogue de recherche globale.
  Widget _buildSearchField(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: InkWell(
          onTap: _openGlobalSearch,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rechercher un document, un candidat…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Avatar + nom + rôle de l'utilisateur connecté.
  Widget _buildIdentity(Employee emp, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(emp),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emp.fullName,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                emp.displayRole,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: employeeColor(emp.jobTitle, emp.role),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(Employee emp) {
    final color = employeeColor(emp.jobTitle, emp.role);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        image: emp.avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(emp.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: emp.avatarUrl == null
          ? Center(
              child: Text(
                emp.initials,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: color,
                ),
              ),
            )
          : null,
    );
  }

  // ── Actions communes ─────────────────────────────────────────────────────

  void _openGlobalSearch() => GlobalSearchDialog.show(
    context,
    appState: _appState,
    candidatesState: _candidatesState,
    logisticsState: _logisticsState,
  );

  void _openNotifications() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NotificationsScreen(
        notificationsState: _notificationsState,
        appState: _appState,
      ),
    ),
  );

  void _logout() {
    _appState.logout();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ── Corps par rôle ───────────────────────────────────────────────────────

  Widget _buildBody(UserRole role, int index) {
    Widget content;
    switch (role) {
      case UserRole.admin:
        content = _adminBody(index);
        break;
      case UserRole.directeurAdministratif:
        content = _directeurBody(index);
        break;
      case UserRole.rh:
        content = _rhBody(index);
        break;
      case UserRole.employe:
        content = _employeBody(index);
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(key: ValueKey<int>(index), child: content),
    );
  }

  // ── Admin : Dashboard | Archives | Candidats | Logistique | Équipe ────────
  Widget _adminBody(int index) {
    final emp = _appState.currentEmployee!;
    switch (index) {
      case 0:
        return AdminDashboardScreen(
          appState: _appState,
          candidatesState: _candidatesState,
          logisticsState: _logisticsState,
        );
      case 1:
        return HistoryScreen(appState: _appState, showAll: true);
      case 2:
        return CandidatesListScreen(
          candidatesState: _candidatesState,
          currentUserName: emp.fullName,
          canEdit: true,
        );
      case 3:
        return LogisticsListScreen(
          logisticsState: _logisticsState,
          currentUserId: emp.id,
          currentUserName: emp.fullName,
          currentUserRole: emp.role,
        );
      case 4:
        return UserManagementScreen(appState: _appState);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Directeur : Dashboard | Logistique | Candidats | Archives | Profil ────
  Widget _directeurBody(int index) {
    final emp = _appState.currentEmployee!;
    switch (index) {
      case 0:
        return DirecteurDashboardScreen(
          appState: _appState,
          candidatesState: _candidatesState,
          logisticsState: _logisticsState,
        );
      case 1:
        return LogisticsListScreen(
          logisticsState: _logisticsState,
          currentUserId: emp.id,
          currentUserName: emp.fullName,
          currentUserRole: emp.role,
        );
      case 2:
        return CandidatesListScreen(
          candidatesState: _candidatesState,
          currentUserName: emp.fullName,
          canEdit: false,
        );
      case 3:
        return HistoryScreen(appState: _appState, showAll: true);
      case 4:
        return _buildProfileTab(emp);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── RH : Dashboard | Candidats | Archives | Profil ────────────────────────
  Widget _rhBody(int index) {
    final emp = _appState.currentEmployee!;
    switch (index) {
      case 0:
        return RhDashboardScreen(
          appState: _appState,
          candidatesState: _candidatesState,
        );
      case 1:
        return CandidatesListScreen(
          candidatesState: _candidatesState,
          currentUserName: emp.fullName,
          canEdit: true,
        );
      case 2:
        return HistoryScreen(appState: _appState, showAll: true);
      case 3:
        return _buildProfileTab(emp);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Employé : Tableau de bord | Historique ───────────────────────────────
  Widget _employeBody(int index) {
    switch (index) {
      case 0:
        return EmployeeDashboardScreen(appState: _appState);
      case 1:
        return HistoryScreen(appState: _appState);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFAB(UserRole role, int index, Employee emp) {
    if (role == UserRole.employe &&
        index == 0 &&
        !_appState.hasSubmittedToday) {
      final color = jobColor(emp.jobTitle);
      return FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Nouvelle archive',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubmitArchiveScreen(appState: _appState),
            ),
          );
          setState(() {});
        },
      );
    }
    return null;
  }

  // ── Onglet Profil pour superviseurs ──────────────────────────────────────
  Widget _buildProfileTab(Employee emp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = employeeColor(emp.jobTitle, emp.role);

    return Container(
      color: isDark ? kDarkBackground : kBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCard : kSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? kDarkBorder : kBorderColor,
                    ),
                    boxShadow: isDark ? kDarkCardShadow : kSoftShadow,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (result != null &&
                              result.files.single.bytes != null) {
                            final ext = result.files.single.extension ?? 'png';
                            final error = await _appState.updateProfilePicture(
                              result.files.single.bytes!,
                              ext,
                            );
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            }
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                image: emp.avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(emp.avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: emp.avatarUrl == null
                                  ? Center(
                                      child: Text(
                                        emp.initials,
                                        style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: kPrimaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emp.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              employeeIcon(emp.jobTitle, emp.role),
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              emp.role.label,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emp.email,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (emp.role == UserRole.admin) ...[
                  _profileOptionCard(
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Gestion des abonnements & plans',
                    subtitle: 'Supervision des forfaits CinetPay',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionAdminScreen(),
                      ),
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _profileOptionCard(
                    icon: Icons.history_edu_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Journal d\'audit système',
                    subtitle: 'Traçabilité des actions administratives',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AuditLogsScreen(
                          organizationId: 'org-creposa-default-id',
                        ),
                      ),
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                if (emp.role == UserRole.admin ||
                    emp.role == UserRole.directeurAdministratif) ...[
                  _profileOptionCard(
                    icon: Icons.delete_outline_rounded,
                    iconColor: kDanger,
                    title: 'Corbeille',
                    subtitle: 'Gérer les archives supprimées récemment',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrashScreen(appState: _appState),
                      ),
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                _profileOptionCard(
                  icon: Icons.logout_rounded,
                  iconColor: kDanger,
                  title: 'Se déconnecter',
                  subtitle: 'Mettre fin à la session en cours',
                  onTap: _logout,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      color: isDark ? kDarkCard : kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: isDark ? kDarkTextSecondary : kTextSecondary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDark ? kDarkTextMuted : kTextMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}
