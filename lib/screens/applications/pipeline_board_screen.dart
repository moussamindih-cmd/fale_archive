import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/application.dart';
import '../../models/fale_permission.dart';
import '../../state/app_state.dart';
import '../../state/applications_state.dart';
import '../../state/job_offers_state.dart';
import '../../theme/app_theme.dart';
import 'application_detail_screen.dart';

/// Tableau de bord du pipeline de recrutement (§5.3.6).
///
/// Board d'étapes réel : chaque colonne est une étape paramétrée en base,
/// et l'on y déplace les candidatures. L'écran précédent affichait le titre
/// « Pipeline Recrutement » au-dessus d'une simple liste filtrée.
class PipelineBoardScreen extends StatefulWidget {
  final AppState appState;
  final ApplicationsState applicationsState;
  final JobOffersState offersState;

  const PipelineBoardScreen({
    super.key,
    required this.appState,
    required this.applicationsState,
    required this.offersState,
  });

  @override
  State<PipelineBoardScreen> createState() => _PipelineBoardScreenState();
}

class _PipelineBoardScreenState extends State<PipelineBoardScreen> {
  String? _offerFilter;

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.applicationsState.stages.isEmpty) {
        widget.applicationsState.load();
      }
      if (widget.offersState.offers.isEmpty) widget.offersState.load();
    });
  }

  bool get _canMove =>
      widget.appState.currentEmployee?.can(FalePermission.moveApplication) ??
      false;

  Future<void> _move(Application application, PipelineStage target) async {
    final error =
        await widget.applicationsState.moveToStage(application.id, target.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ??
          '${application.candidateName ?? 'Candidature'} → ${target.label}'),
      backgroundColor: error == null ? null : kDanger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.applicationsState;

    return AnimatedBuilder(
      animation: Listenable.merge([state, widget.offersState]),
      builder: (context, _) {
        if (state.isLoading && state.stages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.stages.isEmpty) {
          return _empty(
            isDark,
            'Aucun pipeline configuré',
            'Le pipeline de recrutement n\'a pas encore été paramétré '
                'pour cette organisation.',
          );
        }

        return Column(
          children: [
            _buildHeader(isDark),
            Expanded(child: _buildBoard(isDark)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    final state = widget.applicationsState;
    final stalled = state.stalled.length;
    final upcoming = state.upcomingInterviews.length;
    final tth = state.averageTimeToHire;
    final conversion = state.conversionRate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pipeline de recrutement',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _kpi('Candidatures en cours',
                    state.openApplications.length.toString(), kInfo, isDark),
                _kpi(
                  'Délai moyen',
                  tth == null ? '—' : '${tth.round()} j',
                  kPrimaryColor,
                  isDark,
                ),
                _kpi(
                  'Taux de conversion',
                  conversion == null
                      ? '—'
                      : '${(conversion * 100).round()} %',
                  kSuccess,
                  isDark,
                ),
                _kpi('Entretiens à venir', upcoming.toString(), kAccentColor,
                    isDark),
                if (stalled > 0)
                  _kpi('En souffrance', stalled.toString(), kWarning, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _offerFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.work_outline_rounded, size: 18),
                  ),
                  hint: const Text('Toutes les offres'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes les offres'),
                    ),
                    for (final o in widget.offersState.offers)
                      DropdownMenuItem<String?>(
                        value: o.id,
                        child: Text('${o.reference} — ${o.title}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _offerFilter = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? kDarkTextSecondary : kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildBoard(bool isDark) {
    final state = widget.applicationsState;
    final columns = [...state.openStages, ...state.terminalStages];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in columns) _buildColumn(stage, isDark),
        ],
      ),
    );
  }

  Widget _buildColumn(PipelineStage stage, bool isDark) {
    final items =
        widget.applicationsState.inStage(stage.id, jobOfferId: _offerFilter);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: stage.color, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(stage.icon, size: 15, color: stage.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: stage.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    items.length.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: stage.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aucune candidature',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _buildCard(items[i], stage, isDark),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
      Application application, PipelineStage stage, bool isDark) {
    final stalled = application.isStalled(stage);

    return Material(
      color: isDark ? kDarkCard : kSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApplicationDetailScreen(
              applicationId: application.id,
              appState: widget.appState,
              applicationsState: widget.applicationsState,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: stalled ? kWarning : (isDark ? kDarkBorder : kBorderColor),
              width: stalled ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                application.candidateName ?? 'Candidat',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                application.jobOfferTitle ?? 'Candidature spontanée',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: application.isSpontaneous
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 12,
                      color: stalled
                          ? kWarning
                          : (isDark ? kDarkTextMuted : kTextMuted)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      stalled
                          ? '${application.daysInStage} j — en souffrance'
                          : 'Depuis ${application.daysInStage} j',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            stalled ? FontWeight.w600 : FontWeight.w400,
                        color: stalled
                            ? kWarning
                            : (isDark ? kDarkTextMuted : kTextMuted),
                      ),
                    ),
                  ),
                  if (_canMove && !stage.isTerminal)
                    _moveMenu(application, stage),
                ],
              ),
              Text(
                'Reçue le ${_dateFormat.format(application.appliedAt)}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moveMenu(Application application, PipelineStage current) {
    final targets = widget.applicationsState.stages
        .where((s) => s.id != current.id)
        .toList();

    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<PipelineStage>(
        padding: EdgeInsets.zero,
        iconSize: 16,
        tooltip: 'Déplacer',
        icon: const Icon(Icons.drive_file_move_outline),
        onSelected: (stage) => _move(application, stage),
        itemBuilder: (_) => [
          for (final s in targets)
            PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  Icon(s.icon, size: 15, color: s.color),
                  const SizedBox(width: 8),
                  Text(s.label),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(bool isDark, String title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_kanban_outlined,
                size: 46, color: isDark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? kDarkTextPrimary : kTextPrimary)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? kDarkTextSecondary : kTextSecondary)),
          ],
        ),
      ),
    );
  }
}
