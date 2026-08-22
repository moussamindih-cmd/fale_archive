import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../models/daily_archive.dart';
import '../models/user_role.dart';
import '../widgets/document_preview.dart';
import '../services/archive_label_service.dart';

class HistoryScreen extends StatefulWidget {
  final AppState appState;
  final bool showAll;

  const HistoryScreen({
    super.key,
    required this.appState,
    this.showAll = false,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _filterJob;
  String _filterDate = 'Tous';
  String _searchQuery = '';

  static const List<String> _dateFilters = [
    'Tous',
    "Aujourd'hui",
    'Cette semaine',
  ];
  static const List<String> _jobs = [
    'Tous les postes',
    'Secrétaire',
    'Comptable',
    'Gestionnaire',
    'Conseiller Principal',
    'Conseiller Adjoint',
  ];

  List<DailyArchive> _filtered(List<DailyArchive> all) {
    final now = DateTime.now();
    return all.where((a) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final match =
            a.title.toLowerCase().contains(query) ||
            a.summary.toLowerCase().contains(query) ||
            a.employeeName.toLowerCase().contains(query) ||
            a.reference.toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_filterJob != null &&
          _filterJob != 'Tous les postes' &&
          a.jobTitle != _filterJob) {
        return false;
      }
      if (_filterDate == "Aujourd'hui") {
        if (!(a.archiveDate.year == now.year &&
            a.archiveDate.month == now.month &&
            a.archiveDate.day == now.day)) {
          return false;
        }
      } else if (_filterDate == 'Cette semaine') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        if (a.archiveDate.isBefore(
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        )) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = widget.showAll
        ? widget.appState.allArchives.toList()
        : widget.appState.myArchives;
    final filtered = _filtered(all);

    final todayArchives = widget.appState.todayArchives;
    const jobsList = [
      'Secrétaire',
      'Comptable',
      'Gestionnaire',
      'Conseiller Principal',
      'Conseiller Adjoint',
    ];
    final submittedJobs = todayArchives.map((a) => a.jobTitle).toSet();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suivi quotidien par poste (si vue superviseur ou d'ensemble)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? kDarkCard : kSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
              boxShadow: isDark ? kDarkCardShadow : kSoftShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.today_rounded,
                        color: kPrimaryLight,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Suivi des dépôts du jour — ${DateFormat('dd/MM/yyyy', 'fr_FR').format(DateTime.now())}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (submittedJobs.length == jobsList.length
                                    ? kSuccess
                                    : kWarning)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${submittedJobs.length}/${jobsList.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: submittedJobs.length == jobsList.length
                              ? kSuccess
                              : kWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...jobsList.map((job) {
                  final done = submittedJobs.contains(job);
                  final color = jobColor(job);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: done
                              ? color
                              : (isDark
                                    ? kDarkTextMuted
                                    : const Color(0xFFCBD5E1)),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            job,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: done
                                  ? (isDark ? kDarkTextPrimary : kTextPrimary)
                                  : (isDark ? kDarkTextMuted : kTextMuted),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: done
                                ? color.withValues(alpha: 0.12)
                                : (isDark
                                      ? kDarkSurfaceSubtle
                                      : kSurfaceSubtle),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            done ? 'Versé' : 'En attente',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: done
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: done
                                  ? color
                                  : (isDark ? kDarkTextMuted : kTextMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Barre de recherche
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText:
                        'Filtrer les archives par titre, résumé ou référence...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  tooltip: 'Rechercher une archive par code QR',
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => _openCodeLookup(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Filtres Dates
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dateFilters.map((f) {
                final active = _filterDate == f;
                final accent = isDark ? kPrimaryLight : kPrimaryColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _filterDate = f),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? accent
                            : (isDark ? kDarkCard : kSurface),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? accent
                              : (isDark ? kDarkBorder : kBorderColor),
                        ),
                      ),
                      child: Text(
                        f,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : (isDark ? kDarkTextPrimary : kTextPrimary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Filtres Postes
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _jobs.map((j) {
                final active = (_filterJob ?? 'Tous les postes') == j;
                final color = j == 'Tous les postes'
                    ? (isDark ? kPrimaryLight : kPrimaryColor)
                    : jobColor(j);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _filterJob = j),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? color.withValues(alpha: isDark ? 0.2 : 0.1)
                            : (isDark ? kDarkCard : kSurface),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? color
                              : (isDark ? kDarkBorder : kBorderColor),
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (j != 'Tous les postes') ...[
                            Icon(
                              jobIcon(j),
                              size: 14,
                              color: active
                                  ? color
                                  : (isDark ? kDarkTextMuted : kTextMuted),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            j,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? color
                                  : (isDark
                                        ? kDarkTextSecondary
                                        : kTextSecondary),
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

          const SizedBox(height: 16),

          // En-tête résultats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registre des archives',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${filtered.length} élément(s)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              decoration: BoxDecoration(
                color: isDark ? kDarkCard : kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 44,
                    color: isDark ? kDarkTextMuted : kTextMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune archive correspondante',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modifiez vos critères de recherche ou sélectionnez une autre période.',
                    textAlign: TextAlign.center,
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
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildCard(filtered[i], isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(DailyArchive arc, bool isDark) {
    final color = jobColor(arc.jobTitle);
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(arc.archiveDate);
    final timeStr = DateFormat('HH:mm').format(arc.submittedAt);

    final role = widget.appState.currentEmployee?.role;
    final canDelete =
        role == UserRole.admin || role == UserRole.directeurAdministratif;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
        boxShadow: isDark ? null : kSoftShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            DocumentPreviewSheet.show(context, arc: arc);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        jobIcon(arc.jobTitle),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arc.employeeName,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          Text(
                            arc.jobTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          dateStr,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isDark ? kDarkTextMuted : kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? kDarkBorder : kBorderColor),
                const SizedBox(height: 12),
                Text(
                  arc.title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
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
                      fontSize: 12,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        arc.reference,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 14,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${arc.documentCount} doc(s)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? kDarkTextMuted : kTextMuted,
                      ),
                    ),
                    const Spacer(),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: kDanger,
                        ),
                        tooltip: 'Mettre à la corbeille',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmSoftDelete(arc),
                      )
                    else ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: kSuccess,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Validé',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kSuccess,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSoftDelete(DailyArchive arc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Mettre à la corbeille ?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'L\'archive "${arc.title}" sera déplacée dans la corbeille pendant 7 jours avant d\'être supprimée définitivement.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mettre à la corbeille'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.appState.softDeleteArchive(arc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archive déplacée vers la corbeille.')),
        );
        setState(() {}); // Rafraîchir la liste
      }
    }
  }

  /// Retrouver directement une archive à partir du code affiché sur son
  /// étiquette QR (saisi manuellement en l'absence de scanner caméra).
  Future<void> _openCodeLookup(BuildContext context) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechercher par code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisissez ou collez le code de l\'étiquette QR de l\'archive.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'falearchive://archive/... ou code brut',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final archive = widget.appState.getArchiveById(
      ArchiveLabelService.parseArchiveId(code),
    );
    if (!context.mounted) return;
    if (archive == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune archive ne correspond à ce code.'),
        ),
      );
      return;
    }
    DocumentPreviewSheet.show(context, arc: archive);
  }
}
