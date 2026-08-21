import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/daily_archive.dart';
import '../../state/app_state.dart';
import '../../state/candidates_state.dart';
import '../../state/logistics_state.dart';
import '../../models/logistics_item.dart';
import '../../models/candidate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_kit.dart';
import '../../widgets/dashboard_charts.dart';
import 'user_management_screen.dart';

/// Fenêtre d'observation des graphiques d'activité.
const int _kChartDays = 7;

class AdminDashboardScreen extends StatelessWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;

  const AdminDashboardScreen({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([appState, candidatesState, logisticsState]),
      builder: (context, _) {
        final stats = appState.globalStats;
        final candidateStats = candidatesState.candidatesByStatus;
        final logisticsStats = logisticsState.itemsByStatus;
        final archivesSeries = appState.archivesPerDay(_kChartDays);

        return DashboardCanvas(
          children: [
            // ── Bannière ──────────────────────────────────────────────────
            const _AdminBanner().animated(0),
            const SizedBox(height: 16),

            // ── Actions de la console ─────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ConsoleAction(
                  icon: Icons.download_rounded,
                  label: 'Exporter les archives (CSV)',
                  onTap: () =>
                      _showCsvExport(context, appState.archives, isDark),
                ),
                _ConsoleAction(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Gérer l\'équipe',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserManagementScreen(appState: appState),
                    ),
                  ),
                ),
              ],
            ).animated(1),
            const SizedBox(height: 26),

            // ── Indicateurs clés ──────────────────────────────────────────
            const DashboardSectionTitle(title: 'Indicateurs clés'),
            KpiStrip(
              items: [
                KpiData(
                  label: 'Employés actifs',
                  value: stats['totalEmployees'] ?? 0,
                  icon: Icons.people_alt_rounded,
                  color: kInfo,
                ),
                KpiData(
                  label: 'Archives du jour',
                  value: stats['archivesToday'] ?? 0,
                  icon: Icons.today_rounded,
                  color: kSuccess,
                  previous: appState.archivesYesterday,
                  comparisonLabel: 'par rapport à hier',
                  spark: archivesSeries,
                ),
                KpiData(
                  label: 'Archives cette semaine',
                  value: stats['archivesThisWeek'] ?? 0,
                  icon: Icons.insights_rounded,
                  color: const Color(0xFF0D9488),
                  previous: appState.archivesPreviousWeek,
                  comparisonLabel: 'par rapport à la semaine dernière',
                ),
                KpiData(
                  label: 'Logistique en attente',
                  value: logisticsState.pendingCount,
                  icon: Icons.pending_actions_rounded,
                  color: kWarning,
                  previous: logisticsState.itemsPreviousWeek,
                  comparisonLabel: 'par rapport aux 7 jours précédents',
                ),
              ],
            ).animated(2),
            const SizedBox(height: 26),

            // ── Activité d'archivage + pipeline candidats ─────────────────
            DashboardSplit(
              leftFlex: 6,
              rightFlex: 4,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(
                    title: 'Activité d\'archivage',
                    badge: '7 derniers jours',
                  ),
                  DashboardCard(
                    child: ActivityBarChart(
                      values: archivesSeries,
                      labels: lastDaysLabels(_kChartDays),
                      dates: lastDays(_kChartDays),
                    ),
                  ),
                ],
              ).animated(3),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(title: 'Pipeline candidats RH'),
                  _CandidatePipelineCard(stats: candidateStats),
                ],
              ).animated(4),
            ),
            const SizedBox(height: 26),

            // ── Tendance + pièces logistiques ─────────────────────────────
            DashboardSplit(
              leftFlex: 6,
              rightFlex: 4,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(
                    title: 'Tendance sur 30 jours',
                    badge: 'volume quotidien',
                  ),
                  DashboardCard(
                    child: TrendLineChart(
                      values: appState.archivesPerDay(30),
                      dates: lastDays(30),
                    ),
                  ),
                ],
              ).animated(5),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(title: 'Pièces logistiques'),
                  DashboardCard(
                    child: BreakdownList(
                      entries: LogisticsStatus.values
                          .map(
                            (s) => BreakdownEntry(
                              label: s.label,
                              count: logisticsStats[s] ?? 0,
                              color: Color(s.colorValue),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ).animated(6),
            ),
            const SizedBox(height: 26),

            // ── Journal d'activité + archives récentes ────────────────────
            DashboardSplit(
              leftFlex: 4,
              rightFlex: 6,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(
                    title: 'Dernières actions système',
                  ),
                  ActivityFeed(entries: appState.activityLog, maxItems: 6),
                ],
              ).animated(7),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardSectionTitle(
                    title: 'Archives récentes',
                    badge: '${appState.archives.length} au total',
                  ),
                  RecentArchivesTable(archives: appState.archives),
                ],
              ).animated(8),
            ),
          ],
        );
      },
    );
  }

  void _showCsvExport(
    BuildContext context,
    List<DailyArchive> archives,
    bool isDark,
  ) {
    final StringBuffer csv = StringBuffer();
    csv.writeln('ID,Date,Rôle/Poste,Auteur,Fichiers');
    for (final arch in archives) {
      final date = DateFormat('dd/MM/yyyy HH:mm').format(arch.createdAt);
      final dept = arch.jobTitle.replaceAll('"', '""');
      final author = arch.employeeName.replaceAll('"', '""');
      csv.writeln(
        '"${arch.id}","$date","$dept","$author",${arch.files.length}',
      );
    }

    final String csvContent = csv.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? kDarkCard : kSurface,
        title: Row(
          children: [
            const Icon(Icons.table_view_rounded, color: kPrimaryColor),
            const SizedBox(width: 10),
            Text(
              'Export CSV (${archives.length} lignes)',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? kDarkBackground : kBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Text(
              csvContent,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV copié dans le presse-papiers !'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Action de la console ────────────────────────────────────────────────────

/// Bouton d'action de la console admin, posé sous la bannière.
class _ConsoleAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ConsoleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ConsoleAction> createState() => _ConsoleActionState();
}

class _ConsoleActionState extends State<_ConsoleAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? kPrimaryColor.withValues(alpha: isDark ? 0.16 : 0.08)
                : (isDark ? kDarkCard : kSurface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? kPrimaryColor.withValues(alpha: 0.4)
                  : (isDark ? kDarkBorder : kBorderColor),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: kPrimaryColor),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bannière administrateur ─────────────────────────────────────────────────

class _AdminBanner extends StatelessWidget {
  const _AdminBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: kPrimaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FALE Archives',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Supervision & Administration SaaS',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat(
                    'EEEE d MMMM yyyy',
                    'fr_FR',
                  ).format(DateTime.now()),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
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

// ─── Pipeline candidats (donut + répartition) ────────────────────────────────

class _CandidatePipelineCard extends StatefulWidget {
  final Map<CandidateStatus, int> stats;

  const _CandidatePipelineCard({required this.stats});

  @override
  State<_CandidatePipelineCard> createState() => _CandidatePipelineCardState();
}

class _CandidatePipelineCardState extends State<_CandidatePipelineCard> {
  /// Section survolée du donut ; -1 = aucune.
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = CandidateStatus.values
        .map(
          (s) => BreakdownEntry(
            label: s.label,
            count: widget.stats[s] ?? 0,
            color: Color(s.colorValue),
          ),
        )
        .toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.count);

    return DashboardCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 44,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        setState(() {
                          _touchedIndex =
                              event.isInterestedForInteractions &&
                                  response?.touchedSection != null
                              ? response!.touchedSection!.touchedSectionIndex
                              : -1;
                        });
                      },
                    ),
                    sections: [
                      for (var i = 0; i < CandidateStatus.values.length; i++)
                        _section(i, CandidateStatus.values[i], isDark),
                    ],
                  ),
                ),
                // Total au centre du donut, remplacé par la section survolée.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedCounter(
                      value: _touchedIndex >= 0
                          ? entries[_touchedIndex].count
                          : total,
                      duration: const Duration(milliseconds: 350),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _touchedIndex >= 0
                            ? entries[_touchedIndex].color
                            : (isDark ? kDarkTextPrimary : kTextPrimary),
                      ),
                    ),
                    Text(
                      _touchedIndex >= 0
                          ? entries[_touchedIndex].label
                          : 'candidats',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? kDarkTextMuted : kTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          // Sous 420 px, le donut passe au-dessus de la répartition.
          if (constraints.maxWidth < 420) {
            return Column(
              children: [
                chart,
                const SizedBox(height: 20),
                BreakdownList(entries: entries),
              ],
            );
          }

          return Row(
            children: [
              chart,
              const SizedBox(width: 20),
              Expanded(child: BreakdownList(entries: entries)),
            ],
          );
        },
      ),
    );
  }

  PieChartSectionData _section(int i, CandidateStatus status, bool isDark) {
    final count = widget.stats[status] ?? 0;
    final isTouched = i == _touchedIndex;

    return PieChartSectionData(
      color: Color(status.colorValue),
      value: count.toDouble(),
      title: '$count',
      // La section survolée s'épaissit légèrement.
      radius: isTouched ? 36 : (count > 0 ? 30 : 25),
      titleStyle: GoogleFonts.outfit(
        fontSize: isTouched ? 14 : 12,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }
}
