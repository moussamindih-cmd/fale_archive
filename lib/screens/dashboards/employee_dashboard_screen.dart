import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_kit.dart';
import '../../widgets/dashboard_charts.dart';
import '../submit_archive_screen.dart';

/// Fenêtre d'observation du graphique de dépôts.
const int _kChartDays = 7;

/// Tableau de bord de l'employé : statut du jour, indicateurs personnels,
/// rythme de dépôt, archives récentes et journal d'activité.
class EmployeeDashboardScreen extends StatelessWidget {
  final AppState appState;

  const EmployeeDashboardScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final emp = appState.currentEmployee;
        if (emp == null) return const SizedBox.shrink();

        final color = jobColor(emp.jobTitle);
        final submitted = appState.hasSubmittedToday;
        final myArchives = appState.myArchives;
        final myActivity = appState.activityLog
            .where((e) => e.userName == emp.fullName)
            .toList();

        // Rythme de dépôt personnel sur la fenêtre d'observation.
        final mySeries = appState.myArchivesPerDay(_kChartDays);
        final thisWeek = mySeries.fold<int>(0, (sum, v) => sum + v);
        // Les 7 jours précédents = première moitié d'une fenêtre double.
        final previousWeek = appState
            .myArchivesPerDay(_kChartDays * 2)
            .take(_kChartDays)
            .fold<int>(0, (sum, v) => sum + v);
        final totalFiles = myArchives.fold<int>(
          0,
          (sum, a) => sum + a.files.length,
        );

        return DashboardCanvas(
          children: [
            _StatusBanner(
              color: color,
              submitted: submitted,
              onSubmit: () => _openSubmitScreen(context),
            ).animated(0),
            const SizedBox(height: 18),

            _AssignedRegisterCard(
              category: emp.archiveCategory,
              jobTitle: emp.jobTitle,
              color: color,
            ).animated(1),
            const SizedBox(height: 26),

            const DashboardSectionTitle(title: 'Mes indicateurs'),
            KpiStrip(
              items: [
                KpiData(
                  label: 'Dépôts cette semaine',
                  value: thisWeek,
                  icon: Icons.event_available_rounded,
                  color: color,
                  previous: previousWeek,
                  comparisonLabel: 'par rapport aux 7 jours précédents',
                  spark: mySeries,
                ),
                KpiData(
                  label: 'Total de mes archives',
                  value: myArchives.length,
                  icon: Icons.inventory_2_rounded,
                  color: kInfo,
                ),
                KpiData(
                  label: 'Pièces déposées',
                  value: totalFiles,
                  icon: Icons.attach_file_rounded,
                  color: kAccentColor,
                ),
              ],
            ).animated(2),
            const SizedBox(height: 26),

            const DashboardSectionTitle(
              title: 'Mon rythme de dépôt',
              badge: '7 derniers jours',
            ),
            DashboardCard(
              child: ActivityBarChart(
                values: mySeries,
                labels: lastDaysLabels(_kChartDays),
                dates: lastDays(_kChartDays),
                accent: color,
              ),
            ).animated(3),
            const SizedBox(height: 26),

            DashboardSectionTitle(
              title: 'Mes archives récentes',
              badge: '${myArchives.length} entrée(s)',
            ),
            RecentArchivesTable(
              archives: myArchives,
              emptyMessage:
                  'Aucune archive enregistrée.\nVos soumissions quotidiennes apparaîtront ici.',
            ).animated(4),
            const SizedBox(height: 26),

            const DashboardSectionTitle(title: 'Mon activité récente'),
            ActivityFeed(
              entries: myActivity,
              maxItems: 5,
              emptyMessage:
                  'Vos actions apparaîtront ici au fil de vos dépôts.',
            ).animated(5),
          ],
        );
      },
    );
  }

  Future<void> _openSubmitScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmitArchiveScreen(appState: appState),
      ),
    );
  }
}

// ─── Bannière de statut du jour ──────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Color color;
  final bool submitted;
  final VoidCallback onSubmit;

  const _StatusBanner({
    required this.color,
    required this.submitted,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateFormat(
      'EEEE d MMMM yyyy',
      'fr_FR',
    ).format(DateTime.now());
    final accent = submitted ? kSuccess : color;

    return Container(
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
            color: accent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
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
                  submitted
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  submitted
                      ? 'Archive du jour validée ✓'
                      : 'Archive du jour en attente',
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
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
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
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          if (!submitted) ...[
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: color,
                  size: 18,
                ),
                label: Text(
                  'Déposer l\'archive maintenant',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                onPressed: onSubmit,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Registre assigné au poste ───────────────────────────────────────────────

class _AssignedRegisterCard extends StatelessWidget {
  final String category;
  final String jobTitle;
  final Color color;

  const _AssignedRegisterCard({
    required this.category,
    required this.jobTitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(jobIcon(jobTitle), color: color, size: 24),
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
                  category,
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
    );
  }
}
