import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/logistics_item.dart';
import '../../state/app_state.dart';
import '../../state/candidates_state.dart';
import '../../state/logistics_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_kit.dart';
import '../../widgets/dashboard_charts.dart';

/// Fenêtre d'observation des graphiques d'activité.
const int _kChartDays = 7;

/// Tableau de bord du Directeur Administratif : supervision de la logistique,
/// des candidatures et de l'archivage.
class DirecteurDashboardScreen extends StatelessWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;

  const DirecteurDashboardScreen({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appState, candidatesState, logisticsState]),
      builder: (context, _) {
        final emp = appState.currentEmployee;
        final stats = appState.globalStats;
        final logisticsByStatus = logisticsState.itemsByStatus;
        final logisticsSeries = logisticsState.itemsPerDay(_kChartDays);

        return DashboardCanvas(
          children: [
            _WelcomeBanner(
              name: emp?.fullName ?? '',
              pendingCount: logisticsState.pendingCount,
            ).animated(0),
            const SizedBox(height: 26),

            const DashboardSectionTitle(title: 'Indicateurs clés'),
            KpiStrip(
              items: [
                KpiData(
                  label: 'Pièces en attente',
                  value: logisticsState.pendingCount,
                  icon: Icons.pending_actions_rounded,
                  color: kWarning,
                ),
                KpiData(
                  label: 'Pièces reçues (7 j)',
                  value: logisticsState.itemsThisWeek,
                  icon: Icons.receipt_long_rounded,
                  color: kInfo,
                  previous: logisticsState.itemsPreviousWeek,
                  comparisonLabel: 'par rapport aux 7 jours précédents',
                  spark: logisticsSeries,
                ),
                KpiData(
                  label: 'Candidats actifs',
                  value: candidatesState.totalActive,
                  icon: Icons.person_search_rounded,
                  color: const Color(0xFF7C3AED),
                  previous: candidatesState.candidatesPreviousWeek,
                  comparisonLabel: 'par rapport aux 7 jours précédents',
                ),
                KpiData(
                  label: 'Archives cette semaine',
                  value: stats['archivesThisWeek'] ?? 0,
                  icon: Icons.inventory_2_rounded,
                  color: kSuccess,
                  previous: appState.archivesPreviousWeek,
                  comparisonLabel: 'par rapport à la semaine dernière',
                ),
              ],
            ).animated(1),
            const SizedBox(height: 26),

            DashboardSplit(
              leftFlex: 6,
              rightFlex: 4,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(
                    title: 'Flux logistique',
                    badge: '7 derniers jours',
                  ),
                  DashboardCard(
                    child: ActivityBarChart(
                      values: logisticsSeries,
                      labels: lastDaysLabels(_kChartDays),
                      dates: lastDays(_kChartDays),
                      accent: const Color(0xFF8B5CF6),
                      unitSingular: 'pièce',
                      unitPlural: 'pièces',
                    ),
                  ),
                ],
              ).animated(2),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(title: 'Validation logistique'),
                  DashboardCard(
                    child: BreakdownList(
                      entries: LogisticsStatus.values
                          .map(
                            (s) => BreakdownEntry(
                              label: s.label,
                              count: logisticsByStatus[s] ?? 0,
                              color: Color(s.colorValue),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ).animated(3),
            ),
            const SizedBox(height: 26),

            DashboardSplit(
              leftFlex: 4,
              rightFlex: 6,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(title: 'Activité récente'),
                  ActivityFeed(entries: appState.activityLog, maxItems: 5),
                ],
              ).animated(4),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(title: 'Archives récentes'),
                  RecentArchivesTable(archives: appState.archives),
                ],
              ).animated(5),
            ),
          ],
        );
      },
    );
  }
}

// ─── Bandeau de bienvenue ────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final int pendingCount;

  const _WelcomeBanner({required this.name, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat(
      'EEEE d MMMM yyyy',
      'fr_FR',
    ).format(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              Icons.account_balance_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? 'Direction Administrative'
                      : 'Bonjour, ${name.split(' ').first}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingCount > 0
                      ? 'Direction Administrative · $pendingCount pièce(s) à valider'
                      : 'Direction Administrative · aucune pièce en attente',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today.substring(0, 1).toUpperCase() + today.substring(1),
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
