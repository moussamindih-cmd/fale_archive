import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../state/candidates_state.dart';
import '../state/logistics_state.dart';
import '../state/theme_state.dart';
import '../state/notifications_state.dart';
import '../theme/app_theme.dart';
import '../models/daily_archive.dart';
import '../models/attached_file.dart';
import '../models/user_role.dart';
import '../models/employee.dart';
import '../widgets/role_based_nav.dart';
import '../widgets/global_search_dialog.dart';
import '../widgets/mesh_background.dart';
import 'login_screen.dart';
import 'submit_archive_screen.dart';
import 'history_screen.dart';
import 'candidates/candidates_list_screen.dart';
import 'logistics/logistics_list_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/user_management_screen.dart';
import 'notifications_screen.dart';
import 'reports/reports_screen.dart';
import '../state/subscription_state.dart';
import 'subscription/subscription_screen.dart';
import 'admin/subscription_admin_screen.dart';
import 'admin/audit_logs_screen.dart';
import 'trash_screen.dart';

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
      animation: Listenable.merge([_appState, _notificationsState, _themeState]),
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
        final unreadNotifs = _notificationsState.unreadCount(userId: emp.id, role: role);

        final appBar = AppBar(
          elevation: 0,
          titleSpacing: 16,
          title: Row(
            children: [
              _buildAvatar(emp),
              const SizedBox(width: 12),
              Expanded(
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Recherche Globale
            IconButton(
              tooltip: 'Recherche globale',
              icon: Icon(
                Icons.search_rounded,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
                size: 22,
              ),
              onPressed: () => GlobalSearchDialog.show(
                context,
                appState: _appState,
                candidatesState: _candidatesState,
                logisticsState: _logisticsState,
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
            // Notifications avec Badge
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(
                    notificationsState: _notificationsState,
                    appState: _appState,
                  ),
                ),
              ),
            ),
            // Dark Mode Toggle
            IconButton(
              tooltip: isDark ? 'Mode clair' : 'Mode sombre',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                color: isDark ? const Color(0xFFFBBF24) : kTextSecondary,
                size: 21,
              ),
              onPressed: () => _themeState.toggleTheme(),
            ),
            const SizedBox(width: 4),
          ],
        );

        return AnimatedMeshBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              if (isWide) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Row(
                    children: [
                      RoleBasedSidebar(
                        role: role,
                        selectedIndex: safeIndex,
                        onDestinationSelected: (i) => setState(() => _tabIndex = i),
                      ),
                      Expanded(
                        child: Scaffold(
                          appBar: appBar,
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
                appBar: appBar,
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
      child: Container(
        key: ValueKey<int>(index),
        child: content,
      ),
    );
  }

  // ── Admin : Dashboard | Archives | Candidats | Logistique | Utilisateurs ──
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

  // ── Directeur Administratif : Logistique | Candidats | Archives | Profil ──
  Widget _directeurBody(int index) {
    final emp = _appState.currentEmployee!;
    switch (index) {
      case 0:
        return LogisticsListScreen(
          logisticsState: _logisticsState,
          currentUserId: emp.id,
          currentUserName: emp.fullName,
          currentUserRole: emp.role,
        );
      case 1:
        return CandidatesListScreen(
          candidatesState: _candidatesState,
          currentUserName: emp.fullName,
          canEdit: false,
        );
      case 2:
        return HistoryScreen(appState: _appState, showAll: true);
      case 3:
        return _buildProfileTab(emp);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── RH : Candidats | Archives | Profil ────────────────────────────────────
  Widget _rhBody(int index) {
    final emp = _appState.currentEmployee!;
    switch (index) {
      case 0:
        return CandidatesListScreen(
          candidatesState: _candidatesState,
          currentUserName: emp.fullName,
          canEdit: true,
        );
      case 1:
        return HistoryScreen(appState: _appState, showAll: true);
      case 2:
        return _buildProfileTab(emp);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Employé : Tableau de bord | Historique ────────────────────────────────
  Widget _employeBody(int index) {
    final emp = _appState.currentEmployee!;
    final color = jobColor(emp.jobTitle);
    final submitted = _appState.hasSubmittedToday;
    final myArchives = _appState.myArchives;
    switch (index) {
      case 0:
        return _buildEmployeeDashboard(emp, color, submitted, myArchives);
      case 1:
        return HistoryScreen(appState: _appState);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFAB(UserRole role, int index, Employee emp) {
    if (role == UserRole.employe && index == 0 && !_appState.hasSubmittedToday) {
      final color = jobColor(emp.jobTitle);
      return FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text('Nouvelle archive', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SubmitArchiveScreen(appState: _appState)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? kDarkCard : kSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
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
                    if (result != null && result.files.single.bytes != null) {
                      final ext = result.files.single.extension ?? 'png';
                      final error = await _appState.updateProfilePicture(result.files.single.bytes!, ext);
                      if (error != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
                          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
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
                                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: color),
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
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(employeeIcon(emp.jobTitle, emp.role), size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        emp.role.label,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color),
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
                MaterialPageRoute(builder: (_) => const SubscriptionAdminScreen()),
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
                MaterialPageRoute(builder: (_) => const AuditLogsScreen(organizationId: 'org-creposa-default-id')),
              ),
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          if (emp.role == UserRole.admin || emp.role == UserRole.directeurAdministratif) ...[
            _profileOptionCard(
              icon: Icons.delete_outline_rounded,
              iconColor: kDanger,
              title: 'Corbeille',
              subtitle: 'Gérer les archives supprimées récemment',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TrashScreen(appState: _appState)),
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
            onTap: () {
              _appState.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            isDark: isDark,
          ),
        ],
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

  // ── Dashboard Employé ────────────────────────────────────────────────────
  Widget _buildEmployeeDashboard(Employee emp, Color color, bool submitted, List<DailyArchive> myArchives) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut du jour
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: submitted
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [color, color.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (submitted ? const Color(0xFF10B981) : color).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        submitted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        submitted ? 'Archive du jour validée ✓' : 'Archive du jour en attente',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  today.substring(0, 1).toUpperCase() + today.substring(1),
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    submitted
                        ? 'Votre archive quotidienne a été enregistrée avec succès.'
                        : 'Veuillez déposer vos documents du jour avant la fin de service.',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.white, height: 1.3),
                  ),
                ),
                if (!submitted) ...[
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(Icons.add_circle_outline_rounded, color: color, size: 18),
                    label: Text('Déposer l\'archive maintenant', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SubmitArchiveScreen(appState: _appState)),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ],
            ),
          ).animate().fade(duration: 350.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          // Catégorie du poste
          Container(
            decoration: BoxDecoration(
              color: isDark ? kDarkCard : kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
              boxShadow: isDark ? kDarkCardShadow : kSoftShadow,
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(jobIcon(emp.jobTitle), color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registre assigné à votre poste',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        emp.archiveCategory,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 24),

          // Mes dernières archives
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Archives récentes',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${myArchives.length} entrée(s)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (myArchives.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: isDark ? kDarkCard : kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 42, color: isDark ? kDarkTextMuted : kTextMuted),
                  const SizedBox(height: 10),
                  Text(
                    'Aucune archive enregistrée',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vos soumissions quotidiennes apparaîtront ici.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myArchives.length > 5 ? 5 : myArchives.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _archiveCard(myArchives[i], color, isDark),
            ),
        ],
      ),
    );
  }

  Widget _archiveCard(DailyArchive arc, Color color, bool isDark) {
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(arc.archiveDate);
    final timeStr = DateFormat('HH:mm', 'fr_FR').format(arc.submittedAt);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
        boxShadow: isDark ? null : kSoftShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  arc.reference,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const Spacer(),
              Text(
                '$dateStr à $timeStr',
                style: GoogleFonts.outfit(fontSize: 11, color: isDark ? kDarkTextMuted : kTextMuted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            arc.title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          if (arc.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              arc.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (arc.files.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: arc.files.take(4).map((f) => _fileChip(f, isDark)).toList()
                ..addAll(arc.files.length > 4
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${arc.files.length - 4}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
                          ),
                        )
                      ]
                    : []),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.attach_file_rounded, size: 14, color: isDark ? kDarkTextMuted : kTextMuted),
              const SizedBox(width: 4),
              Text(
                '${arc.documentCount} fichier(s)',
                style: GoogleFonts.outfit(fontSize: 12, color: isDark ? kDarkTextMuted : kTextMuted),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.check_circle_rounded, size: 14, color: kSuccess),
              const SizedBox(width: 4),
              Text(
                'Enregistré',
                style: GoogleFonts.outfit(fontSize: 12, color: kSuccess, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fileChip(AttachedFile f, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForExt(f.extension), size: 12, color: _colorForExt(f.extension)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              f.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      case 'jpg': case 'jpeg': case 'png': return Icons.image_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return const Color(0xFFEF4444);
      case 'doc': case 'docx': return const Color(0xFF3B82F6);
      case 'xls': case 'xlsx': return const Color(0xFF10B981);
      case 'ppt': case 'pptx': return const Color(0xFFF97316);
      case 'jpg': case 'jpeg': case 'png': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF64748B);
    }
  }
}
