import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/application.dart';
import '../../models/fale_permission.dart';
import '../../services/ics_service.dart';
import '../../state/app_state.dart';
import '../../state/applications_state.dart';
import '../../theme/app_theme.dart';

/// Détail d'une candidature : parcours, avis collaboratifs et entretiens.
class ApplicationDetailScreen extends StatefulWidget {
  final String applicationId;
  final AppState appState;
  final ApplicationsState applicationsState;

  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.appState,
    required this.applicationsState,
  });

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  List<ApplicationNote> _notes = [];
  List<StageTransition> _history = [];
  bool _isBusy = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final notes =
          await widget.applicationsState.notesOf(widget.applicationId);
      final history =
          await widget.applicationsState.historyOf(widget.applicationId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _history = history;
      });
    } catch (_) {
      // Le détail reste consultable même si les compléments échouent.
    }
  }

  bool get _canRate =>
      widget.appState.currentEmployee?.can(FalePermission.rateApplication) ??
      false;

  bool get _canSchedule =>
      widget.appState.currentEmployee
          ?.can(FalePermission.scheduleInterview) ??
      false;

  /// Moyenne des notes attribuées. `null` si personne n'a encore noté :
  /// afficher « 0/5 » suggérerait un avis unanimement négatif.
  double? get _averageRating {
    final rated = _notes.where((n) => n.rating != null).toList();
    if (rated.isEmpty) return null;
    return rated.fold<int>(0, (s, n) => s + n.rating!) / rated.length;
  }

  Future<void> _addNote() async {
    final bodyCtrl = TextEditingController();
    var rating = 0;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un avis'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: bodyCtrl,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Commentaire *',
                  hintText: 'Impressions, points forts, réserves…',
                ),
              ),
              const SizedBox(height: 16),
              Text('Note (facultative)',
                  style: GoogleFonts.inter(fontSize: 12)),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: kWarning,
                      ),
                      onPressed: () => setDialogState(
                          () => rating = rating == i ? 0 : i),
                    ),
                  if (rating > 0)
                    TextButton(
                      onPressed: () => setDialogState(() => rating = 0),
                      child: const Text('Effacer'),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    final body = bodyCtrl.text;
    bodyCtrl.dispose();
    if (saved != true || !mounted) return;

    final application = _application;
    setState(() => _isBusy = true);
    final error = await widget.applicationsState.addNote(
      applicationId: widget.applicationId,
      body: body,
      rating: rating > 0 ? rating : null,
      stageId: application?.stageId,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    await _reload();
    if (!mounted) return;
    if (error != null) _snack(error, kDanger);
  }

  Future<void> _scheduleInterview() async {
    final application = _application;
    if (application == null) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);

    setState(() => _isBusy = true);
    final error = await widget.applicationsState.scheduleInterview(
      Interview(
        id: '',
        organizationId: application.organizationId,
        applicationId: application.id,
        scheduledAt: scheduledAt,
        icsUid: '',
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    _snack(
      error ?? 'Entretien planifié le ${_dateTimeFormat.format(scheduledAt)}.',
      error == null ? null : kDanger,
    );
  }

  Future<void> _exportIcs(Interview interview) async {
    final application = _application;
    try {
      final destination = await IcsService.download(
        interview: interview,
        candidateName: application?.candidateName ?? 'Candidat',
        positionTitle: application?.jobOfferTitle,
      );
      if (!mounted) return;
      _snack('Invitation enregistrée : $destination', null);
    } catch (e) {
      if (!mounted) return;
      _snack('Échec de la génération de l\'invitation : $e', kDanger);
    }
  }

  void _snack(String message, Color? color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Application? get _application {
    for (final a in widget.applicationsState.applications) {
      if (a.id == widget.applicationId) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.applicationsState,
      builder: (context, _) {
        final application = _application;
        if (application == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Candidature introuvable.')),
          );
        }
        final stage = widget.applicationsState.stageById(application.stageId);

        return Scaffold(
          backgroundColor: isDark ? kDarkBackground : kBackground,
          appBar: AppBar(
            title: Text(application.candidateName ?? 'Candidature'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _summaryCard(application, stage, isDark),
              const SizedBox(height: 16),
              _interviewsCard(application, isDark),
              const SizedBox(height: 16),
              _notesCard(isDark),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 16),
                _historyCard(isDark),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(
      Application application, PipelineStage? stage, bool isDark) {
    final average = _averageRating;
    final stalled = stage != null && application.isStalled(stage);

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (stage != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: stage.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stage.icon, size: 13, color: stage.color),
                      const SizedBox(width: 5),
                      Text(stage.label,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: stage.color)),
                    ],
                  ),
                ),
              const Spacer(),
              if (average != null)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: kWarning),
                    const SizedBox(width: 4),
                    Text('${average.toStringAsFixed(1)} / 5',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _row('Poste visé',
              application.jobOfferTitle ?? 'Candidature spontanée', isDark),
          if (application.jobOfferReference != null)
            _row('Référence', application.jobOfferReference!, isDark),
          _row('Source', application.source.label, isDark),
          _row('Reçue le', _dateFormat.format(application.appliedAt), isDark),
          _row('Dans l\'étape depuis', '${application.daysInStage} jours',
              isDark),
          _row(
            'Durée totale',
            '${application.totalDays} jours'
                '${application.isOpen ? ' (en cours)' : ''}',
            isDark,
          ),
          if (stalled) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Cette candidature dépasse le délai fixé pour l\'étape '
                '« ${stage.label} » (${stage.slaDays} jours).',
                style: GoogleFonts.inter(fontSize: 12, color: kWarning),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _interviewsCard(Application application, bool isDark) {
    final interviews =
        widget.applicationsState.interviewsOf(application.id);

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Entretiens', isDark),
              const Spacer(),
              if (_canSchedule)
                TextButton.icon(
                  onPressed: _isBusy ? null : _scheduleInterview,
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Planifier'),
                ),
            ],
          ),
          if (interviews.isEmpty)
            Text('Aucun entretien planifié.',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? kDarkTextMuted : kTextMuted))
          else
            for (final interview in interviews)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded,
                        size: 16, color: interview.status.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateTimeFormat.format(interview.scheduledAt),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          Text(
                            '${interview.durationMinutes} min — '
                            '${interview.status.label}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  isDark ? kDarkTextMuted : kTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Fichier .ics : s'importe dans tout agenda sans OAuth
                    // ni fournisseur tiers (§5.3.5).
                    IconButton(
                      tooltip: 'Télécharger l\'invitation (.ics)',
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      onPressed: () => _exportIcs(interview),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _notesCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Avis des recruteurs', isDark),
              const Spacer(),
              if (_canRate)
                TextButton.icon(
                  onPressed: _isBusy ? null : _addNote,
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Ajouter'),
                ),
            ],
          ),
          if (_notes.isEmpty)
            Text(
              'Aucun avis. Les commentaires sont partagés entre recruteurs '
              'et chacun reste signé de son auteur.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? kDarkTextMuted : kTextMuted),
            )
          else
            for (final note in _notes)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          note.authorName ?? 'Recruteur',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _dateFormat.format(note.createdAt),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? kDarkTextMuted : kTextMuted),
                        ),
                        const Spacer(),
                        if (note.rating != null)
                          Row(
                            children: [
                              for (var i = 1; i <= 5; i++)
                                Icon(
                                  i <= note.rating!
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 13,
                                  color: kWarning,
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _historyCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Parcours', isDark),
          const SizedBox(height: 10),
          for (final transition in _history)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward_rounded,
                      size: 14,
                      color: isDark ? kDarkTextMuted : kTextMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.applicationsState
                                  .stageById(transition.toStageId)
                                  ?.label ??
                              'Étape',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                        Text(
                          '${transition.changedByName ?? 'Système'} — '
                          '${_dateFormat.format(transition.changedAt)}'
                          '${transition.daysInPreviousStage != null ? ' (après ${transition.daysInPreviousStage} j)' : ''}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? kDarkTextMuted : kTextMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
        ),
        child: child,
      );

  Widget _sectionTitle(String label, bool isDark) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? kDarkTextPrimary : kTextPrimary,
        ),
      );

  Widget _row(String label, String value, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? kDarkTextMuted : kTextMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? kDarkTextPrimary : kTextPrimary)),
            ),
          ],
        ),
      );
}
