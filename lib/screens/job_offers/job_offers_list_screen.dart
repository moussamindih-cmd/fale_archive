import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/fale_permission.dart';
import '../../models/job_offer.dart';
import '../../state/app_state.dart';
import '../../state/job_offers_state.dart';
import '../../theme/app_theme.dart';
import 'job_offer_detail_screen.dart';
import 'job_offer_form_screen.dart';

/// Liste des offres d'emploi (§5.2).
class JobOffersListScreen extends StatefulWidget {
  final AppState appState;
  final JobOffersState offersState;

  const JobOffersListScreen({
    super.key,
    required this.appState,
    required this.offersState,
  });

  @override
  State<JobOffersListScreen> createState() => _JobOffersListScreenState();
}

class _JobOffersListScreenState extends State<JobOffersListScreen> {
  OfferWorkflowStatus? _workflow;
  OfferLifecycleStatus? _lifecycle;
  String _keyword = '';

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.offersState.offers.isEmpty) widget.offersState.load();
    });
  }

  bool get _canManage =>
      widget.appState.currentEmployee?.can(FalePermission.manageJobOffers) ??
      false;

  Future<void> _openForm({JobOffer? offer}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobOfferFormScreen(
          offersState: widget.offersState,
          existing: offer,
        ),
      ),
    );
  }

  Future<void> _openTemplates() async {
    final templates = widget.offersState.templates;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucun modèle enregistré. Depuis une offre, '
            '« Enregistrer comme modèle » en crée un.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final selected = await showModalBottomSheet<JobOffer>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Créer depuis un modèle'),
              subtitle: Text('La copie repart en brouillon'),
            ),
            const Divider(height: 1),
            for (final t in templates)
              ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded),
                title: Text(t.displayName),
                subtitle: Text(t.contractType.label),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final error = await widget.offersState.duplicate(selected.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Offre créée depuis « ${selected.displayName} ».'),
      backgroundColor: error == null ? null : kDanger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.offersState,
      builder: (context, _) {
        final results = widget.offersState.filtered(
          workflow: _workflow,
          lifecycle: _lifecycle,
          keyword: _keyword,
        );
        final pending = widget.offersState.awaitingValidation.length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _canManage
              ? FloatingActionButton.extended(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvelle offre'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: widget.offersState.load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(isDark, pending, results.length),
                ),
                if (widget.offersState.isLoading && results.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (results.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(isDark),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _buildOfferCard(results[i], isDark),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, int pending, int shown) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Offres d\'emploi',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ),
              if (_canManage)
                TextButton.icon(
                  onPressed: _openTemplates,
                  icon: const Icon(Icons.bookmarks_outlined, size: 18),
                  label: const Text('Modèles'),
                ),
            ],
          ),
          if (pending > 0) ...[
            const SizedBox(height: 8),
            _banner(
              icon: Icons.hourglass_top_rounded,
              color: kWarning,
              text: '$pending offre${pending > 1 ? 's' : ''} '
                  'en attente de validation.',
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Rechercher par titre, référence, lieu ou compétence…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
            onChanged: (v) => setState(() => _keyword = v),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: 'Tous statuts',
                  selected: _workflow == null,
                  onTap: () => setState(() => _workflow = null),
                  isDark: isDark,
                ),
                for (final s in OfferWorkflowStatus.values)
                  _filterChip(
                    label: s.label,
                    color: s.color,
                    count: widget.offersState
                        .filtered(workflow: s)
                        .length,
                    selected: _workflow == s,
                    onTap: () => setState(
                        () => _workflow = _workflow == s ? null : s),
                    isDark: isDark,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: 'Tout cycle de vie',
                  selected: _lifecycle == null,
                  onTap: () => setState(() => _lifecycle = null),
                  isDark: isDark,
                ),
                for (final s in OfferLifecycleStatus.values)
                  _filterChip(
                    label: s.label,
                    color: s.color,
                    selected: _lifecycle == s,
                    onTap: () => setState(
                        () => _lifecycle = _lifecycle == s ? null : s),
                    isDark: isDark,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$shown offre${shown > 1 ? 's' : ''} affichée${shown > 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? kDarkTextMuted : kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
    int? count,
  }) {
    final accent = color ?? (isDark ? kPrimaryLight : kPrimaryColor);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.15)
                : (isDark ? kDarkSurfaceSubtle : kSurfaceSubtle),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
            ),
          ),
          child: Text(
            count == null || count == 0 ? label : '$label ($count)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? accent
                  : (isDark ? kDarkTextSecondary : kTextSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(JobOffer offer, bool isDark) {
    final deadlineDays = offer.daysUntilDeadline;

    return Material(
      color: isDark ? kDarkCard : kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobOfferDetailScreen(
              offerId: offer.id,
              appState: widget.appState,
              offersState: widget.offersState,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    offer.reference,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? kPrimaryLight : kPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  _statusPill(offer.workflowStatus.label,
                      offer.workflowStatus.color, offer.workflowStatus.icon),
                  if (offer.workflowStatus == OfferWorkflowStatus.publiee) ...[
                    const SizedBox(width: 6),
                    _statusPill(offer.lifecycleStatus.label,
                        offer.lifecycleStatus.color, offer.lifecycleStatus.icon),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                offer.title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _meta(Icons.badge_outlined, offer.contractType.label, isDark),
                  if (offer.location != null && offer.location!.isNotEmpty)
                    _meta(Icons.place_outlined, offer.location!, isDark),
                  if (offer.positionsCount > 1)
                    _meta(Icons.groups_outlined,
                        '${offer.positionsCount} postes', isDark),
                  if (offer.formattedSalary != null)
                    _meta(Icons.payments_outlined, offer.formattedSalary!,
                        isDark),
                ],
              ),
              if (offer.deadline != null) ...[
                const SizedBox(height: 8),
                Text(
                  offer.isExpired
                      ? 'Échéance dépassée le ${_dateFormat.format(offer.deadline!)}'
                      : 'Candidatures jusqu\'au '
                          '${_dateFormat.format(offer.deadline!)}'
                          '${deadlineDays != null && deadlineDays <= 7 ? ' — J-$deadlineDays' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: offer.isExpired || (deadlineDays ?? 99) <= 7
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: offer.isExpired
                        ? kDanger
                        : ((deadlineDays ?? 99) <= 7
                            ? kWarning
                            : (isDark ? kDarkTextMuted : kTextMuted)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: isDark ? kDarkTextMuted : kTextMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? kDarkTextSecondary : kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_outline_rounded,
                size: 46, color: isDark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 14),
            Text(
              'Aucune offre',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _canManage
                  ? 'Créez une offre, ou partez d\'un modèle existant.'
                  : 'Aucune offre ne correspond à ces filtres.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
