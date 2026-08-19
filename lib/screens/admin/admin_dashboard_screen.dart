import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/daily_archive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../state/app_state.dart';
import '../../state/candidates_state.dart';
import '../../state/logistics_state.dart';
import '../../models/logistics_item.dart';
import '../../models/candidate.dart';
import '../../theme/app_theme.dart';
import 'user_management_screen.dart';

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
        final activityLog = appState.activityLog;

        return Scaffold(
          backgroundColor: isDark ? kDarkBackground : kBackground,
          appBar: AppBar(
            title: Text(
              'Console Administrateur',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.download_rounded, color: isDark ? kDarkTextPrimary : kTextPrimary),
                tooltip: 'Exporter les Archives (CSV)',
                onPressed: () => _showCsvExport(context, appState.archives, isDark),
              ),
              IconButton(
                icon: Icon(Icons.manage_accounts_rounded, color: isDark ? kDarkTextPrimary : kTextPrimary),
                tooltip: 'Gestion des utilisateurs',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserManagementScreen(appState: appState)),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bannière Admin
                _buildAdminBanner(isDark),
                const SizedBox(height: 24),

                // Statistiques globales
                Text(
                  'Indicateurs Clés',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _statCard('Employés actifs', '${stats['totalEmployees']}',
                        Icons.people_alt_rounded, const Color(0xFF3B82F6), isDark),
                    _statCard('Archives du jour', '${stats['archivesToday']}',
                        Icons.today_rounded, const Color(0xFF10B981), isDark),
                    _statCard('Archives 7j', '${stats['archivesThisWeek']}',
                        Icons.insights_rounded, const Color(0xFF0D9488), isDark),
                    _statCard('Logistique en attente', '${logisticsState.pendingCount}',
                        Icons.pending_actions_rounded, const Color(0xFFF59E0B), isDark),
                  ],
                ),
                const SizedBox(height: 24),

                // Pipeline Candidats RH avec PieChart
                Text(
                  'Pipeline Candidats RH',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCard : kSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
                    boxShadow: isDark ? kDarkCardShadow : kSoftShadow,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 35,
                            sections: CandidateStatus.values.map((s) {
                              final count = candidateStats[s] ?? 0;
                              final color = Color(s.colorValue);
                              return PieChartSectionData(
                                color: color,
                                value: count.toDouble(),
                                title: '$count',
                                radius: count > 0 ? 30 : 25,
                                titleStyle: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: CandidateStatus.values.map((s) {
                            final count = candidateStats[s] ?? 0;
                            final color = Color(s.colorValue);
                            final total = candidateStats.values.fold(0, (a, b) => a + b);
                            final pct = total > 0 ? count / total : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.label,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$count',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct.toDouble(),
                                      minHeight: 6,
                                      backgroundColor: color.withValues(alpha: isDark ? 0.12 : 0.08),
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Documents logistiques
                Text(
                  'Pièces Logistiques',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: LogisticsStatus.values.map((s) {
                    final count = logisticsStats[s] ?? 0;
                    final color = Color(s.colorValue);
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? kDarkCard : kSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$count',
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Journal d'activité
                Text(
                  'Dernières Actions Système',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCard : kSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
                    boxShadow: isDark ? kDarkCardShadow : kSoftShadow,
                  ),
                  child: activityLog.isEmpty
                      ? Text(
                          'Aucune activité enregistrée.',
                          style: GoogleFonts.outfit(color: isDark ? kDarkTextMuted : kTextMuted, fontSize: 13),
                        )
                      : Column(
                          children: activityLog.take(6).map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFFEF4444)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.details.isNotEmpty ? e.details : e.displayAction,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${e.userName} · ${DateFormat('dd/MM/yyyy HH:mm').format(e.timestamp)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: isDark ? kDarkTextMuted : kTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
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
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FALE Archives',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                Text(
                  'Supervision & Administration SaaS',
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now()),
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
        boxShadow: isDark ? kDarkCardShadow : kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showCsvExport(BuildContext context, List<DailyArchive> archives, bool isDark) {
    final StringBuffer csv = StringBuffer();
    csv.writeln('ID,Date,Rôle/Poste,Auteur,Fichiers');
    for (final arch in archives) {
      final date = DateFormat('dd/MM/yyyy HH:mm').format(arch.createdAt);
      final dept = arch.jobTitle.replaceAll('"', '""');
      final author = arch.employeeName.replaceAll('"', '""');
      csv.writeln('"${arch.id}","$date","$dept","$author",${arch.files.length}');
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
            Text('Export CSV (${archives.length} lignes)', style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black)),
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
              style: GoogleFonts.firaCode(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
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
                const SnackBar(content: Text('CSV copié dans le presse-papiers !')),
              );
            },
          ),
        ],
      ),
    );
  }
}
