import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/fale_permission.dart';
import '../../models/job_offer.dart';
import '../../state/app_state.dart';
import '../../state/job_offers_state.dart';
import '../../theme/app_theme.dart';
import 'job_offer_form_screen.dart';

/// Détail d'une offre, avec les actions de workflow (§5.2.2) et de cycle
/// de vie (§5.2.3).
///
/// Seules les actions réellement autorisées sont proposées : le rôle et la
/// transition sont vérifiés côté base, afficher un bouton qui échouerait
/// serait mentir sur ce que l'utilisateur peut faire.
class JobOfferDetailScreen extends StatefulWidget {
  final String offerId;
  final AppState appState;
  final JobOffersState offersState;

  const JobOfferDetailScreen({
    super.key,
    required this.offerId,
    required this.appState,
    required this.offersState,
  });

  @override
  State<JobOfferDetailScreen> createState() => _JobOfferDetailScreenState();
}

class _JobOfferDetailScreenState extends State<JobOfferDetailScreen> {
  List<JobOfferTransition> _transitions = [];
  bool _isBusy = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadTransitions();
  }

  Future<void> _loadTransitions() async {
    try {
      final list = await widget.offersState.transitionsOf(widget.offerId);
      if (mounted) setState(() => _transitions = list);
    } catch (_) {
      // L'historique est un complément : son absence ne doit pas masquer
      // l'offre elle-même.
    }
  }

  bool get _canManage =>
      widget.appState.currentEmployee?.can(FalePermission.manageJobOffers) ??
      false;

  bool get _canPublish =>
      widget.appState.currentEmployee?.can(FalePermission.publishJobOffer) ??
      false;

  Future<void> _act(Future<String?> Function() action, String successMessage) async {
    setState(() => _isBusy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);
    await _loadTransitions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? successMessage),
      backgroundColor: error == null ? null : kDanger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _rejectWithReason(JobOffer offer) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter l\'offre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet *',
            hintText: 'Expliquez ce qui doit être corrigé',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || !mounted) return;
    await _act(() => widget.offersState.reject(offer.id, reason),
        'Offre rejetée, son auteur peut la corriger.');
  }

  Future<void> _duplicate(JobOffer offer, {required bool asTemplate}) async {
    await _act(
      () => widget.offersState.duplicate(offer.id, asTemplate: asTemplate),
      asTemplate ? 'Modèle créé.' : 'Copie créée en brouillon.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.offersState,
      builder: (context, _) {
        final offer = widget.offersState.byId(widget.offerId);
        if (offer == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Offre introuvable.')),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? kDarkBackground : kBackground,
          appBar: AppBar(
            title: Text(offer.reference),
            actions: [
              if (_canManage)
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'duplicate' => _duplicate(offer, asTemplate: false),
                    'template' => _duplicate(offer, asTemplate: true),
                    _ => null,
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: ListTile(
                        leading: Icon(Icons.copy_rounded),
                        title: Text('Dupliquer'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'template',
                      child: ListTile(
                        leading: Icon(Icons.bookmark_add_outlined),
                        title: Text('Enregistrer comme modèle'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _statusCard(offer, isDark),
              const SizedBox(height: 16),
              _actionsCard(offer, isDark),
              const SizedBox(height: 16),
              _detailsCard(offer, isDark),
              if (_transitions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _historyCard(isDark),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(JobOffer offer, bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(offer.workflowStatus.label, offer.workflowStatus.color,
                  offer.workflowStatus.icon),
              _pill(offer.lifecycleStatus.label, offer.lifecycleStatus.color,
                  offer.lifecycleStatus.icon),
              if (offer.isTemplate)
                _pill('Modèle', kInfo, Icons.bookmark_rounded),
              if (offer.isExpired)
                _pill('Échéance dépassée', kDanger, Icons.event_busy_rounded),
            ],
          ),
          if (offer.rejectionReason != null &&
              offer.workflowStatus == OfferWorkflowStatus.rejetee) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Motif du rejet : ${offer.rejectionReason}',
                style: GoogleFonts.inter(fontSize: 13, color: kDanger),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            offer.isPubliclyVisible
                ? 'Cette offre est visible des candidats externes.'
                : 'Cette offre n\'est pas visible des candidats externes.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark ? kDarkTextMuted : kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(JobOffer offer, bool isDark) {
    final actions = <Widget>[];

    if (_canManage && offer.workflowStatus.isEditable) {
      actions.add(OutlinedButton.icon(
        onPressed: _isBusy
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobOfferFormScreen(
                      offersState: widget.offersState,
                      existing: offer,
                    ),
                  ),
                ),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Modifier'),
      ));
    }

    // Workflow de validation.
    if (_canManage &&
        offer.workflowStatus == OfferWorkflowStatus.brouillon &&
        !offer.isTemplate) {
      actions.add(FilledButton.icon(
        onPressed: _isBusy
            ? null
            : () => _act(() => widget.offersState.submitForValidation(offer.id),
                'Offre soumise à validation.'),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text('Soumettre à validation'),
      ));
    }

    if (offer.workflowStatus == OfferWorkflowStatus.enValidation) {
      if (_canPublish) {
        actions.add(FilledButton.icon(
          onPressed: _isBusy
              ? null
              : () => _act(() => widget.offersState.publish(offer.id),
                  'Offre publiée.'),
          icon: const Icon(Icons.public_rounded, size: 18),
          label: const Text('Valider et publier'),
        ));
        actions.add(OutlinedButton.icon(
          onPressed: _isBusy ? null : () => _rejectWithReason(offer),
          icon: const Icon(Icons.block_rounded, size: 18),
          label: const Text('Rejeter'),
          style: OutlinedButton.styleFrom(foregroundColor: kDanger),
        ));
      } else {
        actions.add(_notice(
          'En attente d\'une décision d\'un directeur administratif '
          'ou d\'un administrateur.',
          isDark,
        ));
      }
    }

    if (_canManage && offer.workflowStatus == OfferWorkflowStatus.rejetee) {
      actions.add(FilledButton.icon(
        onPressed: _isBusy
            ? null
            : () => _act(() => widget.offersState.returnToDraft(offer.id),
                'Offre remise en brouillon.'),
        icon: const Icon(Icons.undo_rounded, size: 18),
        label: const Text('Reprendre en brouillon'),
      ));
    }

    // Cycle de vie : uniquement une fois publiée.
    if (_canManage && offer.workflowStatus == OfferWorkflowStatus.publiee) {
      for (final target in OfferLifecycleStatus.values) {
        if (target == offer.lifecycleStatus) continue;
        actions.add(OutlinedButton.icon(
          onPressed: _isBusy
              ? null
              : () => _act(
                  () => widget.offersState.changeLifecycle(offer.id, target),
                  'Offre marquée « ${target.label} ».'),
          icon: Icon(target.icon, size: 18),
          label: Text(target.label),
        ));
      }
    }

    // La suppression n'est possible que sur un brouillon jamais publié —
    // la RLS l'impose, l'interface le reflète.
    if (_canManage &&
        offer.workflowStatus == OfferWorkflowStatus.brouillon &&
        offer.publishedAt == null) {
      actions.add(TextButton.icon(
        onPressed: _isBusy
            ? null
            : () => _act(() => widget.offersState.delete(offer.id),
                'Brouillon supprimé.').then((_) {
                  if (mounted) Navigator.pop(context);
                }),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Supprimer'),
        style: TextButton.styleFrom(foregroundColor: kDanger),
      ));
    }

    if (actions.isEmpty) {
      actions.add(_notice('Aucune action disponible pour votre rôle.', isDark));
    }

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Actions', isDark),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }

  Widget _detailsCard(JobOffer offer, bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Description du poste', isDark),
          const SizedBox(height: 8),
          Text(
            offer.description.isEmpty ? '—' : offer.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.6,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
            ),
          ),
          if (offer.requirements != null && offer.requirements!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Profil recherché', isDark),
            const SizedBox(height: 8),
            Text(
              offer.requirements!,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.6,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
          ],
          if (offer.skills.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Compétences', isDark),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in offer.skills)
                  Chip(label: Text(s), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Conditions', isDark),
          const SizedBox(height: 8),
          _row('Contrat', offer.contractType.label, isDark),
          _row('Lieu', offer.location ?? '—', isDark),
          _row('Postes à pourvoir', offer.positionsCount.toString(), isDark),
          _row(
            'Rémunération',
            offer.formattedSalary ??
                (offer.salaryMin == null && offer.salaryMax == null
                    ? '—'
                    : 'Renseignée, non publiée'),
            isDark,
          ),
          _row(
            'Date limite',
            offer.deadline == null ? '—' : _dateFormat.format(offer.deadline!),
            isDark,
          ),
          if (offer.publishedAt != null)
            _row('Publiée le', _dateFormat.format(offer.publishedAt!), isDark),
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
          _sectionTitle('Circuit de validation', isDark),
          const SizedBox(height: 12),
          for (final t in _transitions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(t.toStatus.icon, size: 16, color: t.toStatus.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.fromStatus == null
                              ? t.toStatus.label
                              : '${t.fromStatus!.label} → ${t.toStatus.label}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                        Text(
                          '${t.changedByName ?? 'Système'} — '
                          '${_dateTimeFormat.format(t.changedAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? kDarkTextMuted : kTextMuted,
                          ),
                        ),
                        if (t.reason != null && t.reason!.isNotEmpty)
                          Text(
                            t.reason!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
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

  // ── Fragments partagés ───────────────────────────────────────────────────

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

  Widget _pill(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _notice(String message, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isDark ? kDarkSurfaceSubtle : kSurfaceSubtle),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? kDarkTextSecondary : kTextSecondary,
          ),
        ),
      );
}
