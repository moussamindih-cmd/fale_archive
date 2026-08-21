import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/candidate.dart';
import '../../state/app_state.dart';
import '../../state/candidates_state.dart';
import '../../widgets/dashboard_kit.dart';
import '../../widgets/dashboard_charts.dart';

/// Fenêtre d'observation des graphiques d'activité.
const int _kChartDays = 7;

/// Couleur d'accent des Ressources Humaines (fuchsia).
const Color _kRhAccent = Color(0xFFD946EF);

/// Tableau de bord RH : pipeline de recrutement et suivi des candidatures.
class RhDashboardScreen extends StatelessWidget {
  final AppState appState;
  final CandidatesState candidatesState;

  const RhDashboardScreen({
    super.key,
    required this.appState,
    required this.candidatesState,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appState, candidatesState]),
      builder: (context, _) {
        final emp = appState.currentEmployee;
        final byStatus = candidatesState.candidatesByStatus;
        final candidatesSeries = candidatesState.candidatesPerDay(_kChartDays);

        return DashboardCanvas(
          children: [
            _WelcomeBanner(
              name: emp?.fullName ?? '',
              pendingCount: byStatus[CandidateStatus.enAttente] ?? 0,
            ).animated(0),
            const SizedBox(height: 26),

            const DashboardSectionTitle(title: 'Indicateurs clés'),
            KpiStrip(
              items: [
                KpiData(
                  label: 'Candidats actifs',
                  value: candidatesState.totalActive,
                  icon: Icons.groups_rounded,
                  color: _kRhAccent,
                ),
                KpiData(
                  label: 'Reçues (7 j)',
                  value: candidatesState.candidatesThisWeek,
                  icon: Icons.mark_email_unread_rounded,
                  color: const Color(0xFF7C3AED),
                  previous: candidatesState.candidatesPreviousWeek,
                  comparisonLabel: 'par rapport aux 7 jours précédents',
                  spark: candidatesSeries,
                ),
                KpiData(
                  label: CandidateStatus.enEntretien.label,
                  value: byStatus[CandidateStatus.enEntretien] ?? 0,
                  icon: Icons.record_voice_over_rounded,
                  color: Color(CandidateStatus.enEntretien.colorValue),
                ),
                KpiData(
                  label: CandidateStatus.retenu.label,
                  value: byStatus[CandidateStatus.retenu] ?? 0,
                  icon: Icons.how_to_reg_rounded,
                  color: Color(CandidateStatus.retenu.colorValue),
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
                    title: 'Candidatures reçues',
                    badge: '7 derniers jours',
                  ),
                  DashboardCard(
                    child: ActivityBarChart(
                      values: candidatesSeries,
                      labels: lastDaysLabels(_kChartDays),
                      dates: lastDays(_kChartDays),
                      accent: _kRhAccent,
                      unitSingular: 'candidature',
                      unitPlural: 'candidatures',
                    ),
                  ),
                ],
              ).animated(2),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardSectionTitle(title: 'Pipeline de recrutement'),
                  DashboardCard(
                    child: BreakdownList(
                      entries: CandidateStatus.values
                          .map(
                            (s) => BreakdownEntry(
                              label: s.label,
                              count: byStatus[s] ?? 0,
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
        gradient: const LinearGradient(
          colors: [Color(0xFFA21CAF), _kRhAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kRhAccent.withValues(alpha: 0.3),
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
              Icons.people_alt_outlined,
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
                      ? 'Ressources Humaines'
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
                      ? 'Ressources Humaines · $pendingCount candidature(s) à traiter'
                      : 'Ressources Humaines · aucune candidature en attente',
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
