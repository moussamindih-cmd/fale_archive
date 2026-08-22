import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/candidates_state.dart';
import '../../models/candidate.dart';
import '../../theme/app_theme.dart';
import 'candidate_detail_screen.dart';
import 'candidate_form_screen.dart';

class CandidatesListScreen extends StatefulWidget {
  final CandidatesState candidatesState;
  final String currentUserName;
  final bool canEdit;

  const CandidatesListScreen({
    super.key,
    required this.candidatesState,
    required this.currentUserName,
    this.canEdit = true,
  });

  @override
  State<CandidatesListScreen> createState() => _CandidatesListScreenState();
}

class _CandidatesListScreenState extends State<CandidatesListScreen> {
  final _searchCtrl = TextEditingController();
  CandidateStatus? _filterStatus;
  String? _filterPosition;
  String _searchText = '';

  static const List<String> _positions = [
    'Secrétaire',
    'Comptable',
    'Gestionnaire',
    'Conseiller Principal',
    'Conseiller Adjoint',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.candidatesState,
      builder: (context, _) {
        final filtered = widget.candidatesState.filteredCandidates(
          status: _filterStatus,
          targetPosition: _filterPosition,
          keyword: _searchText.isEmpty ? null : _searchText,
        );
        final stats = widget.candidatesState.candidatesByStatus;

        return Scaffold(
          backgroundColor: isDark ? kDarkBackground : kBackground,
          floatingActionButton: widget.canEdit
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: Text(
                    'Nouveau candidat',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CandidateFormScreen(
                          candidatesState: widget.candidatesState,
                          currentUserName: widget.currentUserName,
                        ),
                      ),
                    );
                  },
                )
              : null,
          body: Column(
            children: [
              // Search & Filters Header
              Container(
                color: isDark ? kDarkSurface : kSurface,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchText = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, poste, notes...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchText = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filtres statut
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(
                            'Tous (${widget.candidatesState.candidates.length})',
                            _filterStatus == null,
                            () => setState(() => _filterStatus = null),
                            isDark ? kPrimaryLight : kPrimaryColor,
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          ...CandidateStatus.values.map((s) {
                            final count = stats[s] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _filterChip(
                                '${s.label} ($count)',
                                _filterStatus == s,
                                () => setState(
                                  () => _filterStatus = _filterStatus == s
                                      ? null
                                      : s,
                                ),
                                Color(s.colorValue),
                                isDark,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Filtres postes
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(
                            'Tous postes',
                            _filterPosition == null,
                            () => setState(() => _filterPosition = null),
                            isDark ? kDarkTextSecondary : kTextSecondary,
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          ..._positions.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _filterChip(
                                p,
                                _filterPosition == p,
                                () => setState(
                                  () => _filterPosition = _filterPosition == p
                                      ? null
                                      : p,
                                ),
                                jobColor(p),
                                isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Total count info
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pipeline Recrutement',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${filtered.length} candidat(s)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? kDarkTextMuted : kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Candidates List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 48,
                              color: isDark ? kDarkTextMuted : kTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun candidat trouvé',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? kDarkTextPrimary : kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildCandidateCard(filtered[i], isDark),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color color,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : (isDark ? kDarkCard : kSurfaceSubtle),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : (isDark ? kDarkBorder : kBorderColor),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? kDarkTextPrimary : kTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateCard(Candidate c, bool isDark) {
    final statusColor = Color(c.status.colorValue);
    final posColor = jobColor(c.targetPosition);

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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CandidateDetailScreen(
                  candidateId: c.id,
                  candidatesState: widget.candidatesState,
                  currentUserName: widget.currentUserName,
                  canEdit: widget.canEdit,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: posColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          c.initials,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: posColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.fullName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.work_outline_rounded,
                                size: 13,
                                color: posColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                c.targetPosition,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: posColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.status.label,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? kDarkBorder : kBorderColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      c.phone,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.attach_file_rounded,
                      size: 13,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${c.documents.length} doc(s)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
