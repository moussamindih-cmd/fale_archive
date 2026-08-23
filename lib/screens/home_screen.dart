import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/candidates_state.dart';
import '../state/logistics_state.dart';
import '../state/theme_state.dart';
import '../state/notifications_state.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../models/employee.dart';
import '../models/fale_permission.dart';
import '../widgets/role_based_nav.dart';
import '../widgets/global_search_dialog.dart';
import '../widgets/mesh_background.dart';
import '../services/data_export_service.dart';
import 'login_screen.dart';
import 'archive_search_screen.dart';
import 'auth/two_factor_setup_screen.dart';
import 'applications/pipeline_board_screen.dart';
import 'job_offers/job_offers_list_screen.dart';
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
import 'reports/hr_metrics_screen.dart';
import 'reports/reports_screen.dart';
import '../state/subscription_state.dart';
import 'subscription/subscription_screen.dart';
import 'admin/subscription_admin_screen.dart';
import 'admin/audit_logs_screen.dart';
import 'trash_screen.dart';

/// Largeur à partir de laquelle la sidebar remplace la barre du bas.
const double _kSidebarBreakpoint = 800;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  late AppScope _scope;
  bool _bootstrapped = false;

  AppState get _appState => _scope.appState;
  CandidatesState get _candidatesState => _scope.candidatesState;
  LogisticsState get _logisticsState => _scope.logisticsState;
  NotificationsState get _notificationsState => _scope.notificationsState;
  ThemeState get _themeState => _scope.themeState;
  SubscriptionState get _subscriptionState => _scope.subscriptionState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);

    if (_bootstrapped) return;
    _bootstrapped = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employee = _appState.currentEmployee;
      // L'organisation vient du compte connecté : c'est elle qui porte
      // le cloisonnement, jamais une constante.
      if (employee != null && employee.organizationId.isNotEmpty) {
        _subscriptionState.load(employee.organizationId);
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
        // Les index des items sont déclarés, pas positionnels : depuis que
        // `itemsForRole` filtre par droit, comparer à `navItems.length`
        // laisserait passer un index qui ne correspond à aucun onglet.
        final safeIndex = navItems.any((i) => i.index == _tabIndex)
            ? _tabIndex
            : (navItems.isEmpty ? 0 : navItems.first.index);
        final unreadNotifs = _notificationsState.unreadCount(
          userId: emp.id,
          role: role,
        );

        return AnimatedMeshBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > _kSidebarBreakpoint;

              if (isWide) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
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
                          backgroundColor: Colors.transparent,
                          body: _buildBody(role, safeIndex),
                          floatingActionButton: _buildFAB(role, safeIndex, emp),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Scaffold(
                backgroundColor: Colors.transparent,
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
          ),
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
      leading: Builder(
        builder: (ctx) {
          if (!Navigator.of(ctx).canPop()) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : kTextPrimary).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              tooltip: 'Retour',
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
                size: 22,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          );
        },
      ),
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
        // Recherche avancée : interroge l'index plein texte serveur, là où
        // la recherche globale ne filtre que ce qui est déjà chargé.
        IconButton(
          tooltip: 'Recherche avancée dans les archives',
          icon: Icon(
            Icons.manage_search_rounded,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArchiveSearchScreen(appState: _appState),
            ),
          ),
        ),
        // Pilotage : indicateurs calculés par vues SQL (§5.4).
        if (emp.can(FalePermission.viewReports))
          IconButton(
            tooltip: 'Pilotage RH',
            icon: Icon(
              Icons.query_stats_rounded,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
              size: 21,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HrMetricsScreen()),
            ),
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
        // Corbeille : restaurer archives, candidats, documents logistiques
        // et pièces jointes supprimés (accessible à tous — n'importe quel
        // rôle peut supprimer un dossier, donc n'importe qui doit pouvoir
        // le restaurer).
        IconButton(
          tooltip: 'Corbeille',
          icon: Icon(
            Icons.delete_outline_rounded,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrashScreen(
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
                  organizationId: emp.organizationId,
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

  /// Export JSON complet des données de l'organisation (candidats,
  /// logistique, archives — y compris la corbeille) pour audit, portabilité
  /// ou sauvegarde externe.
  Future<void> _exportAllData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    bool saved = false;
    String? error;
    try {
      saved = await DataExportService.exportAndSave(
        candidates: _candidatesState.allCandidatesIncludingDeleted,
        logisticsItems: [
          ..._logisticsState.items,
          ..._logisticsState.deletedItems,
        ],
        archives: [..._appState.allArchives, ..._appState.deletedArchives],
      );
    } catch (e) {
      error = e.toString();
    }
    if (!context.mounted) return;
    Navigator.pop(context); // Ferme l'indicateur de chargement
    final message = error != null
        ? 'Échec de l\'export : $error'
        : saved
        ? 'Export téléchargé avec succès.'
        : 'Export annulé.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error != null ? kDanger : kSuccess,
      ),
    );
  }

  // ── Corps par rôle ───────────────────────────────────────────────────────

  Widget _buildBody(UserRole role, int index) {
    Widget content;
    switch (role) {
      // Le super administrateur voit la console d'administration d'une
      // organisation ; sa console d'exploitation multi-entreprises est un
      // écran distinct, encore à construire.
      case UserRole.superAdmin:
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

  // ── RH : Dashboard | Offres | Candidats | Archives | Profil ──────────────
  Widget _rhBody(int index) {
    final emp = _appState.currentEmployee!;
    switch (index) {
      case 0:
        return RhDashboardScreen(
          appState: _appState,
          candidatesState: _candidatesState,
        );
      case 1:
        return JobOffersListScreen(
          appState: _appState,
          offersState: _scope.jobOffersState,
        );
      case 2:
        return PipelineBoardScreen(
          appState: _appState,
          applicationsState: _scope.applicationsState,
          offersState: _scope.jobOffersState,
        );
      case 3:
        return HistoryScreen(appState: _appState, showAll: true);
      case 4:
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
                        builder: (_) => AuditLogsScreen(
                          organizationId: emp.organizationId,
                        ),
                      ),
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                // Double authentification — ouverte à tous les rôles : c'est
                // le compte de chacun qu'elle protège (§5.5.3).
                _profileOptionCard(
                  icon: Icons.verified_user_outlined,
                  iconColor: kPrimaryColor,
                  title: 'Double authentification',
                  subtitle: 'Protéger votre compte par un second facteur',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TwoFactorSetupScreen(),
                    ),
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),

                if (emp.role == UserRole.admin ||
                    emp.role == UserRole.directeurAdministratif) ...[
                  _profileOptionCard(
                    icon: Icons.delete_outline_rounded,
                    iconColor: kDanger,
                    title: 'Corbeille',
                    subtitle:
                        'Récupérer archives, candidats et documents supprimés',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrashScreen(
                          appState: _appState,
                          candidatesState: _candidatesState,
                          logisticsState: _logisticsState,
                        ),
                      ),
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _profileOptionCard(
                    icon: Icons.download_for_offline_outlined,
                    iconColor: kPrimaryColor,
                    title: 'Exporter toutes les données',
                    subtitle:
                        'Télécharger un export JSON complet (candidats, logistique, archives)',
                    onTap: () => _exportAllData(context),
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
