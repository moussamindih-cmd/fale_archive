import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '../state/candidates_state.dart';
import '../state/logistics_state.dart';
import '../models/daily_archive.dart';
import '../models/candidate.dart';
import '../models/logistics_item.dart';
import '../models/employee.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../screens/candidates/candidate_detail_screen.dart';
import '../screens/logistics/logistics_detail_screen.dart';

enum SearchCategory {
  tous('Tous', Icons.search_rounded),
  archives('Archives', Icons.folder_open_rounded),
  logistique('Logistique', Icons.receipt_long_rounded),
  candidats('Candidats', Icons.people_outline_rounded),
  utilisateurs('Équipe', Icons.badge_outlined);

  final String label;
  final IconData icon;
  const SearchCategory(this.label, this.icon);
}

class GlobalSearchDialog extends StatefulWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;

  const GlobalSearchDialog({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
  });

  static void show(
    BuildContext context, {
    required AppState appState,
    required CandidatesState candidatesState,
    required LogisticsState logisticsState,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => GlobalSearchDialog(
        appState: appState,
        candidatesState: candidatesState,
        logisticsState: logisticsState,
      ),
    );
  }

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  SearchCategory _selectedCategory = SearchCategory.tous;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = widget.appState.currentEmployee;
    final role = currentUser?.role ?? UserRole.employe;

    final matchingArchives = _filterArchives();
    final matchingLogistics = _filterLogistics();
    final matchingCandidates = _filterCandidates();
    final matchingEmployees = _filterEmployees(role);

    final totalCount =
        matchingArchives.length +
        matchingLogistics.length +
        matchingCandidates.length +
        matchingEmployees.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        decoration: BoxDecoration(
          color: isDark ? kDarkSurface : kSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? kDarkBorder : kBorderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? kDarkBorder : kBorderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: kPrimaryLight,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText:
                                'Rechercher un document, candidat, dépense...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 15,
                              color: isDark ? kDarkTextMuted : kTextMuted,
                            ),
                          ),
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: SearchCategory.values.map((cat) {
                        final selected = _selectedCategory == cat;
                        final accent = isDark ? kPrimaryLight : kPrimaryColor;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? accent
                                    : (isDark ? kDarkCard : kSurfaceSubtle),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? accent
                                      : (isDark ? kDarkBorder : kBorderColor),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cat.icon,
                                    size: 14,
                                    color: selected
                                        ? Colors.white
                                        : (isDark
                                              ? kDarkTextSecondary
                                              : kTextSecondary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.label,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? Colors.white
                                          : (isDark
                                                ? kDarkTextPrimary
                                                : kTextPrimary),
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
                ],
              ),
            ),

            // Results List
            Expanded(
              child: _query.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.manage_search_rounded,
                      title: 'Command Palette de Recherche',
                      subtitle:
                          'Tapez un mot-clé (titre, nom, facture, catégorie) pour parcourir instantanément tout l\'écosystème.',
                      isDark: isDark,
                    )
                  : totalCount == 0
                  ? _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun résultat trouvé',
                      subtitle: 'Aucune donnée ne correspond à "$_query".',
                      isDark: isDark,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_selectedCategory == SearchCategory.tous ||
                            _selectedCategory == SearchCategory.archives)
                          ..._buildArchivesSection(matchingArchives, isDark),
                        if (_selectedCategory == SearchCategory.tous ||
                            _selectedCategory == SearchCategory.logistique)
                          ..._buildLogisticsSection(matchingLogistics, isDark),
                        if (_selectedCategory == SearchCategory.tous ||
                            _selectedCategory == SearchCategory.candidats)
                          ..._buildCandidatesSection(
                            matchingCandidates,
                            isDark,
                          ),
                        if (_selectedCategory == SearchCategory.tous ||
                            _selectedCategory == SearchCategory.utilisateurs)
                          ..._buildEmployeesSection(matchingEmployees, isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<DailyArchive> _filterArchives() {
    if (_query.isEmpty) return [];
    return widget.appState.archives.where((a) {
      return a.title.toLowerCase().contains(_query) ||
          a.summary.toLowerCase().contains(_query) ||
          a.employeeName.toLowerCase().contains(_query) ||
          a.jobTitle.toLowerCase().contains(_query);
    }).toList();
  }

  List<LogisticsItem> _filterLogistics() {
    if (_query.isEmpty) return [];
    return widget.logisticsState.items.where((i) {
      return i.reference.toLowerCase().contains(_query) ||
          i.supplier.toLowerCase().contains(_query) ||
          i.documentType.label.toLowerCase().contains(_query) ||
          i.notes.toLowerCase().contains(_query);
    }).toList();
  }

  List<Candidate> _filterCandidates() {
    if (_query.isEmpty) return [];
    return widget.candidatesState.candidates.where((c) {
      return c.fullName.toLowerCase().contains(_query) ||
          c.targetPosition.toLowerCase().contains(_query) ||
          c.phone.contains(_query) ||
          c.email.toLowerCase().contains(_query) ||
          c.rhNotes.toLowerCase().contains(_query);
    }).toList();
  }

  List<Employee> _filterEmployees(UserRole role) {
    if (_query.isEmpty) return [];
    if (role != UserRole.admin && role != UserRole.directeurAdministratif) {
      return [];
    }
    return widget.appState.employees.where((e) {
      return e.fullName.toLowerCase().contains(_query) ||
          e.email.toLowerCase().contains(_query) ||
          e.jobTitle.toLowerCase().contains(_query) ||
          e.role.label.toLowerCase().contains(_query);
    }).toList();
  }

  List<Widget> _buildArchivesSection(List<DailyArchive> archives, bool isDark) {
    if (archives.isEmpty) return [];
    return [
      _sectionHeader(
        'Archives Journalières (${archives.length})',
        kPrimaryColor,
      ),
      ...archives.map(
        (a) => _searchResultCard(
          icon: jobIcon(a.jobTitle),
          iconColor: jobColor(a.jobTitle),
          title: a.title,
          subtitle:
              '${a.employeeName} • ${DateFormat('dd/MM/yyyy').format(a.createdAt)} • ${a.documentCount} doc(s)',
          onTap: () => Navigator.pop(context),
          isDark: isDark,
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildLogisticsSection(List<LogisticsItem> items, bool isDark) {
    if (items.isEmpty) return [];
    return [
      _sectionHeader(
        'Logistique & Dépenses (${items.length})',
        const Color(0xFF8B5CF6),
      ),
      ...items.map(
        (i) => _searchResultCard(
          icon: i.documentType.icon,
          iconColor: const Color(0xFF8B5CF6),
          title: '${i.documentType.label} : ${i.reference}',
          subtitle:
              '${i.supplier} • ${i.status.label} • ${DateFormat('dd/MM/yyyy').format(i.issueDate)}',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LogisticsDetailScreen(
                  itemId: i.id,
                  logisticsState: widget.logisticsState,
                  currentUserRole:
                      widget.appState.currentEmployee?.role ?? UserRole.employe,
                  currentUserName:
                      widget.appState.currentEmployee?.fullName ?? '',
                ),
              ),
            );
          },
          isDark: isDark,
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildCandidatesSection(
    List<Candidate> candidates,
    bool isDark,
  ) {
    if (candidates.isEmpty) return [];
    return [
      _sectionHeader(
        'Candidats RH (${candidates.length})',
        const Color(0xFFEC4899),
      ),
      ...candidates.map(
        (c) => _searchResultCard(
          icon: Icons.person_rounded,
          iconColor: const Color(0xFFEC4899),
          title: c.fullName,
          subtitle: 'Poste : ${c.targetPosition} • Statut : ${c.status.label}',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CandidateDetailScreen(
                  candidateId: c.id,
                  candidatesState: widget.candidatesState,
                  canEdit:
                      widget.appState.currentEmployee?.role == UserRole.rh ||
                      widget.appState.currentEmployee?.role == UserRole.admin,
                  currentUserName:
                      widget.appState.currentEmployee?.fullName ?? '',
                ),
              ),
            );
          },
          isDark: isDark,
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildEmployeesSection(List<Employee> employees, bool isDark) {
    if (employees.isEmpty) return [];
    return [
      _sectionHeader(
        'Équipe & Utilisateurs (${employees.length})',
        const Color(0xFF10B981),
      ),
      ...employees.map(
        (e) => _searchResultCard(
          icon: roleIcon(e.role),
          iconColor: roleColor(e.role),
          title: e.fullName,
          subtitle:
              '${e.role.label} ${e.jobTitle.isNotEmpty ? "• ${e.jobTitle}" : ""} • ${e.email}',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: e.isActive
                  ? kSuccess.withValues(alpha: 0.12)
                  : kDanger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              e.isActive ? 'Actif' : 'Inactif',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: e.isActive ? kSuccess : kDanger,
              ),
            ),
          ),
          onTap: () => Navigator.pop(context),
          isDark: isDark,
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _searchResultCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? kDarkBorder.withValues(alpha: 0.6)
                    : kBorderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: isDark ? kDarkTextMuted : kTextMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: isDark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
