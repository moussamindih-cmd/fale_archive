import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/daily_archive.dart';
import '../models/document_version.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/document_preview.dart';

/// Historique des révisions des pièces d'une archive (§5.1.6).
///
/// Les versions sont en ajout seul côté base : cet écran ne propose donc
/// aucune suppression — ce serait mentir sur ce que le système permet.
class DocumentVersionsScreen extends StatefulWidget {
  final DailyArchive archive;

  const DocumentVersionsScreen({super.key, required this.archive});

  @override
  State<DocumentVersionsScreen> createState() => _DocumentVersionsScreenState();
}

class _DocumentVersionsScreenState extends State<DocumentVersionsScreen> {
  List<DocumentVersion> _versions = [];
  bool _isLoading = true;
  String? _error;

  static final _dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final versions = await SupabaseService.instance
          .fetchDocumentVersions(widget.archive.id);
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger l\'historique : $e';
        _isLoading = false;
      });
    }
  }

  /// Regroupe par nom de fichier : l'utilisateur raisonne « ce document et
  /// ses versions », pas « une liste plate de révisions ».
  Map<String, List<DocumentVersion>> get _byFile {
    final grouped = <String, List<DocumentVersion>>{};
    for (final version in _versions) {
      grouped.putIfAbsent(version.fileName, () => []).add(version);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        title: const Text('Historique des versions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.archive.reference} — ${widget.archive.title}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _centeredMessage(
        icon: Icons.error_outline_rounded,
        color: kDanger,
        title: 'Erreur de chargement',
        message: _error!,
        isDark: isDark,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Réessayer'),
        ),
      );
    }
    if (_versions.isEmpty) {
      return _centeredMessage(
        icon: Icons.history_toggle_off_rounded,
        color: kTextMuted,
        title: 'Aucune révision enregistrée',
        message: 'Les pièces déposées avant la mise en place du '
            'versionnement n\'ont pas d\'historique. Toute modification '
            'ultérieure en créera un.',
        isDark: isDark,
      );
    }

    final grouped = _byFile;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final fileName = grouped.keys.elementAt(index);
        return _buildFileGroup(fileName, grouped[fileName]!, isDark);
      },
    );
  }

  Widget _buildFileGroup(
    String fileName,
    List<DocumentVersion> versions,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 18,
                    color: isDark ? kDarkTextSecondary : kTextSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${versions.length} version${versions.length > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? kDarkTextMuted : kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? kDarkBorder : kBorderColor),
          for (var i = 0; i < versions.length; i++)
            _buildVersionRow(versions[i], isCurrent: i == 0, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildVersionRow(
    DocumentVersion version, {
    required bool isCurrent,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCurrent
                  ? kSuccess.withValues(alpha: 0.15)
                  : (isDark ? kDarkSurfaceSubtle : kSurfaceSubtle),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              version.label,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? kSuccess
                    : (isDark ? kDarkTextSecondary : kTextSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Version courante',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kSuccess,
                          ),
                        ),
                      ),
                    Text(
                      _dateFormat.format(version.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
                if (version.createdByName != null)
                  Text(
                    'Par ${version.createdByName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                if (version.comment != null && version.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      version.comment!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                DocumentPreview(
                  file: version.toAttachedFile(),
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _centeredMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required bool isDark,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action],
          ],
        ),
      ),
    );
  }
}
