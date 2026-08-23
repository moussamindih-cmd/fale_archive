import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/archive_search.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Recherche avancée dans les archives (§5.1.3).
///
/// Interroge l'index plein texte français côté serveur — la recherche
/// globale, elle, reste un filtrage rapide sur ce qui est déjà chargé en
/// mémoire. La différence compte dès que le volume dépasse ce qu'on peut
/// raisonnablement rapatrier.
class ArchiveSearchScreen extends StatefulWidget {
  final AppState appState;

  const ArchiveSearchScreen({super.key, required this.appState});

  @override
  State<ArchiveSearchScreen> createState() => _ArchiveSearchScreenState();
}

class _ArchiveSearchScreenState extends State<ArchiveSearchScreen> {
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Timer? _debounce;
  String? _categoryId;
  DateTimeRange? _period;

  final List<ArchiveSearchResult> _results = [];
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasSearched = false;

  static const _pageSize = 30;
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Une requête par frappe saturerait le serveur pour rien : on attend que
  /// la saisie se stabilise.
  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _run);
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore) return;
    if (_results.length >= _total) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _run(append: true);
    }
  }

  Future<void> _run({bool append = false}) async {
    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _error = null;
      }
    });

    try {
      final page = await SupabaseService.instance.searchArchives(
        query: _queryCtrl.text,
        categoryId: _categoryId,
        from: _period?.start,
        to: _period?.end,
        limit: _pageSize,
        offset: append ? _results.length : 0,
      );
      if (!mounted) return;
      setState(() {
        if (!append) _results.clear();
        _results.addAll(page.results);
        _total = page.totalCount;
        _isLoading = false;
        _isLoadingMore = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'La recherche a échoué : $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDateRange: _period,
      locale: const Locale('fr', 'FR'),
    );
    if (range == null) return;
    setState(() => _period = range);
    _run();
  }

  void _clearFilters() {
    setState(() {
      _categoryId = null;
      _period = null;
      _queryCtrl.clear();
    });
    _run();
  }

  bool get _hasFilters =>
      _categoryId != null || _period != null || _queryCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(title: const Text('Recherche avancée')),
      body: Column(
        children: [
          _buildFilters(isDark),
          Divider(height: 1, color: isDark ? kDarkBorder : kBorderColor),
          Expanded(child: _buildResults(isDark)),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    final categories = widget.appState.categories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _queryCtrl,
            autofocus: true,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher dans les titres, résumés et mots-clés…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _queryCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _queryCtrl.clear();
                        _run();
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.folder_outlined, size: 18),
                  ),
                  hint: const Text('Toutes catégories'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes catégories'),
                    ),
                    for (final c in categories)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _categoryId = v);
                    _run();
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  _period == null
                      ? 'Période'
                      : '${_dateFormat.format(_period!.start)} – '
                          '${_dateFormat.format(_period!.end)}',
                ),
                onPressed: _pickPeriod,
              ),
              if (_hasFilters) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Réinitialiser',
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 20),
                  onPressed: _clearFilters,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(Icons.error_outline_rounded, kDanger,
          'Erreur', _error!, isDark);
    }
    if (_results.isEmpty && _hasSearched) {
      return _message(
        Icons.search_off_rounded,
        kTextMuted,
        'Aucun résultat',
        _hasFilters
            ? 'Essayez d\'élargir la période ou de retirer un filtre.'
            : 'Aucune archive n\'a encore été déposée.',
        isDark,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$_total résultat${_total > 1 ? 's' : ''}'
              '${_results.length < _total ? ' — ${_results.length} affichés' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? kDarkTextMuted : kTextMuted,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _results.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _results.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildResultCard(_results[index], isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ArchiveSearchResult result, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ),
              Text(
                _dateFormat.format(result.archiveDate),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
              ),
            ],
          ),
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              result.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(Icons.person_outline_rounded, result.employeeName, isDark),
              if (result.category.isNotEmpty)
                _chip(Icons.folder_outlined, result.category, isDark),
              if (result.documentCount > 0)
                _chip(Icons.attach_file_rounded,
                    '${result.documentCount} pièce'
                    '${result.documentCount > 1 ? 's' : ''}', isDark),
              for (final k in result.keywords.take(4))
                Text(
                  '#$k',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: isDark ? kPrimaryLight : kPrimaryColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: isDark ? kDarkTextMuted : kTextMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? kDarkTextSecondary : kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _message(IconData icon, Color color, String title, String body,
      bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color),
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
                    height: 1.5,
                    color: isDark ? kDarkTextSecondary : kTextSecondary)),
          ],
        ),
      ),
    );
  }
}
