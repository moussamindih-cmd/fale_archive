import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../state/logistics_state.dart';
import '../../models/logistics_item.dart';
import '../../models/user_role.dart';
import '../../theme/app_theme.dart';
import 'logistics_detail_screen.dart';
import 'logistics_form_screen.dart';

class LogisticsListScreen extends StatefulWidget {
  final LogisticsState logisticsState;
  final String currentUserId;
  final String currentUserName;
  final UserRole currentUserRole;

  const LogisticsListScreen({
    super.key,
    required this.logisticsState,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
  });

  @override
  State<LogisticsListScreen> createState() => _LogisticsListScreenState();
}

class _LogisticsListScreenState extends State<LogisticsListScreen> {
  final _searchCtrl = TextEditingController();
  LogisticsDocType? _filterType;
  LogisticsStatus? _filterStatus;
  String _searchText = '';

  bool get _canAdd =>
      widget.currentUserRole == UserRole.employe ||
      widget.currentUserRole == UserRole.admin;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.logisticsState,
      builder: (context, _) {
        final items = widget.logisticsState.filteredItems(
          docType: _filterType,
          status: _filterStatus,
          keyword: _searchText.isEmpty ? null : _searchText,
        );

        return Scaffold(
          backgroundColor: isDark ? kDarkBackground : kBackground,
          floatingActionButton: _canAdd
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    'Nouvelle pièce',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LogisticsFormScreen(
                        logisticsState: widget.logisticsState,
                        currentUserId: widget.currentUserId,
                        currentUserName: widget.currentUserName,
                      ),
                    ),
                  ),
                )
              : null,
          body: Column(
            children: [
              // Search & Filter Header
              Container(
                color: isDark ? kDarkSurface : kSurface,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchText = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par référence, fournisseur...',
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

                    // Filtres types
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip(
                            'Tous types',
                            _filterType == null,
                            () => setState(() => _filterType = null),
                            isDark ? kPrimaryLight : kPrimaryColor,
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          ...LogisticsDocType.values.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _chip(
                                t.label,
                                _filterType == t,
                                () => setState(
                                  () =>
                                      _filterType = _filterType == t ? null : t,
                                ),
                                Color(t.colorValue),
                                isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Filtres statuts
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip(
                            'Tous statuts',
                            _filterStatus == null,
                            () => setState(() => _filterStatus = null),
                            isDark ? kDarkTextSecondary : kTextSecondary,
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          ...LogisticsStatus.values.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _chip(
                                s.label,
                                _filterStatus == s,
                                () => setState(
                                  () => _filterStatus = _filterStatus == s
                                      ? null
                                      : s,
                                ),
                                Color(s.colorValue),
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

              // Summary info bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pièces Logistiques & Achats',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${items.length} document(s)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? kDarkTextMuted : kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 48,
                              color: isDark ? kDarkTextMuted : kTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune pièce trouvée',
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
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildLogisticsCard(items[i], isDark),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
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

  Widget _buildLogisticsCard(LogisticsItem item, bool isDark) {
    final typeColor = Color(item.documentType.colorValue);
    final statusColor = Color(item.status.colorValue);

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
                builder: (_) => LogisticsDetailScreen(
                  itemId: item.id,
                  logisticsState: widget.logisticsState,
                  currentUserName: widget.currentUserName,
                  currentUserRole: widget.currentUserRole,
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
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.documentType.icon,
                        color: typeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.reference,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.supplier,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? kDarkTextSecondary
                                  : kTextSecondary,
                            ),
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
                        item.status.label,
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
                    Text(
                      item.formattedAmount,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(item.issueDate),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? kDarkTextMuted : kTextMuted,
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
