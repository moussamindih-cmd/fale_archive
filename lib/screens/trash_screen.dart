import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/attached_file.dart';
import '../models/candidate.dart';
import '../models/logistics_item.dart';
import '../state/app_state.dart';
import '../state/candidates_state.dart';
import '../state/logistics_state.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corbeille unifiée : archives, candidats et documents logistiques
/// supprimés récemment, restaurables pendant 7 jours.
class TrashScreen extends StatefulWidget {
  final AppState appState;
  final CandidatesState? candidatesState;
  final LogisticsState? logisticsState;

  const TrashScreen({
    super.key,
    required this.appState,
    this.candidatesState,
    this.logisticsState,
  });

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get _hasDocumentsTab =>
      widget.candidatesState != null || widget.logisticsState != null;

  List<Object> get _tabs => [
    widget.appState,
    if (widget.candidatesState != null) widget.candidatesState!,
    if (widget.logisticsState != null) widget.logisticsState!,
    if (_hasDocumentsTab) 'documents',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showTabs = _tabs.length > 1;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        title: Text(
          'Corbeille',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
        backgroundColor: isDark ? kDarkBackground : kBackground,
        iconTheme: IconThemeData(
          color: isDark ? kDarkTextPrimary : kTextPrimary,
        ),
        bottom: showTabs
            ? TabBar(
                controller: _tabController,
                labelColor: kPrimaryColor,
                unselectedLabelColor: isDark ? kDarkTextMuted : kTextMuted,
                indicatorColor: kPrimaryColor,
                labelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: [
                  const Tab(text: 'Archives'),
                  if (widget.candidatesState != null)
                    const Tab(text: 'Candidats'),
                  if (widget.logisticsState != null)
                    const Tab(text: 'Logistique'),
                  if (_hasDocumentsTab) const Tab(text: 'Documents'),
                ],
              )
            : null,
      ),
      body: showTabs
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildArchivesTab(isDark),
                if (widget.candidatesState != null) _buildCandidatesTab(isDark),
                if (widget.logisticsState != null) _buildLogisticsTab(isDark),
                if (_hasDocumentsTab) _buildDocumentsTab(isDark),
              ],
            )
          : _buildArchivesTab(isDark),
    );
  }

  // ─── Onglet Archives ────────────────────────────────────────────────────

  Widget _buildArchivesTab(bool isDark) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final archives = widget.appState.deletedArchives;
        return _buildList(
          isDark: isDark,
          emptyLabel: 'Aucune archive dans la corbeille',
          count: archives.length,
          itemBuilder: (index) {
            final archive = archives[index];
            return _TrashCard(
              title: archive.title,
              subtitle: 'Supprimé par : ${archive.employeeName}',
              daysLeft: archive.daysUntilDeletion,
              isDark: isDark,
              onRestore: () => _confirm(
                title: 'Restaurer l\'archive ?',
                message:
                    'L\'archive "${archive.title}" sera restaurée et à nouveau visible dans l\'historique.',
                confirmLabel: 'Restaurer',
                confirmColor: const Color(0xFF10B981),
                action: () => widget.appState.restoreArchive(archive.id),
                successMessage: 'Archive restaurée avec succès.',
              ),
              onDeleteForever: () => _confirmHardDelete(
                message:
                    'Cette action est irréversible. L\'archive "${archive.title}" sera détruite.',
                action: () =>
                    widget.appState.permanentlyDeleteArchive(archive.id),
                successMessage: 'Archive supprimée définitivement.',
              ),
            );
          },
        );
      },
    );
  }

  // ─── Onglet Candidats ───────────────────────────────────────────────────

  Widget _buildCandidatesTab(bool isDark) {
    final state = widget.candidatesState!;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final candidates = state.deletedCandidates;
        return _buildList(
          isDark: isDark,
          emptyLabel: 'Aucun candidat dans la corbeille',
          count: candidates.length,
          itemBuilder: (index) {
            final c = candidates[index];
            return _TrashCard(
              title: c.fullName,
              subtitle: c.targetPosition,
              daysLeft: c.daysUntilDeletion,
              isDark: isDark,
              onRestore: () => _confirm(
                title: 'Restaurer le dossier ?',
                message:
                    'Le dossier de "${c.fullName}" sera restauré et à nouveau visible dans la liste active.',
                confirmLabel: 'Restaurer',
                confirmColor: const Color(0xFF10B981),
                action: () => state.restoreCandidate(
                  id: c.id,
                  actionUserName: _currentUserName,
                ),
                successMessage: 'Candidat restauré avec succès.',
              ),
              onDeleteForever: () => _confirmHardDelete(
                message:
                    'Cette action est irréversible. Le dossier de "${c.fullName}" sera détruit, y compris ses documents joints.',
                action: () => state.permanentlyDeleteCandidate(c.id),
                successMessage: 'Candidat supprimé définitivement.',
              ),
            );
          },
        );
      },
    );
  }

  // ─── Onglet Logistique ──────────────────────────────────────────────────

  Widget _buildLogisticsTab(bool isDark) {
    final state = widget.logisticsState!;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final items = state.deletedItems;
        return _buildList(
          isDark: isDark,
          emptyLabel: 'Aucun document dans la corbeille',
          count: items.length,
          itemBuilder: (index) {
            final item = items[index];
            return _TrashCard(
              title: item.reference,
              subtitle: item.supplier,
              daysLeft: item.daysUntilDeletion,
              isDark: isDark,
              onRestore: () => _confirm(
                title: 'Restaurer le document ?',
                message:
                    'Le document "${item.reference}" sera restauré et à nouveau visible dans la liste active.',
                confirmLabel: 'Restaurer',
                confirmColor: const Color(0xFF10B981),
                action: () => state.restoreItem(
                  id: item.id,
                  actionUserName: _currentUserName,
                ),
                successMessage: 'Document restauré avec succès.',
              ),
              onDeleteForever: () => _confirmHardDelete(
                message:
                    'Cette action est irréversible. Le document "${item.reference}" sera détruit, y compris ses fichiers joints.',
                action: () => state.permanentlyDeleteItem(item.id),
                successMessage: 'Document supprimé définitivement.',
              ),
            );
          },
        );
      },
    );
  }

  // ─── Onglet Documents (fichiers retirés de dossiers candidats/logistique) ─

  Widget _buildDocumentsTab(bool isDark) {
    final listenables = <Listenable>[
      if (widget.candidatesState != null) widget.candidatesState!,
      if (widget.logisticsState != null) widget.logisticsState!,
    ];
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final candidateDocs =
            widget.candidatesState?.removedDocuments ?? const [];
        final logisticsDocs =
            widget.logisticsState?.removedDocuments ?? const [];
        final total = candidateDocs.length + logisticsDocs.length;
        return _buildList(
          isDark: isDark,
          emptyLabel: 'Aucun document dans la corbeille',
          count: total,
          itemBuilder: (index) {
            if (index < candidateDocs.length) {
              final entry = candidateDocs[index];
              return _buildCandidateDocumentCard(entry, isDark);
            }
            final entry = logisticsDocs[index - candidateDocs.length];
            return _buildLogisticsDocumentCard(entry, isDark);
          },
        );
      },
    );
  }

  Widget _buildCandidateDocumentCard(
    ({Candidate candidate, AttachedFile file}) entry,
    bool isDark,
  ) {
    final state = widget.candidatesState!;
    final path = entry.file.storagePath!;
    return _TrashCard(
      title: entry.file.name,
      subtitle: 'Dossier candidat : ${entry.candidate.fullName}',
      badgeText:
          'Retiré le ${_removedDateFormat.format(entry.file.removedAt!)}',
      isDark: isDark,
      onRestore: () => _confirm(
        title: 'Restaurer le document ?',
        message:
            '"${entry.file.name}" sera à nouveau visible dans le dossier de ${entry.candidate.fullName}.',
        confirmLabel: 'Restaurer',
        confirmColor: const Color(0xFF10B981),
        action: () => state.restoreDocument(
          candidateId: entry.candidate.id,
          storagePath: path,
          actionUserName: _currentUserName,
        ),
        successMessage: 'Document restauré avec succès.',
      ),
      onDeleteForever: () => _confirmHardDelete(
        message:
            'Cette action est irréversible. "${entry.file.name}" sera définitivement effacé.',
        action: () => state.permanentlyDeleteDocument(
          candidateId: entry.candidate.id,
          storagePath: path,
        ),
        successMessage: 'Document supprimé définitivement.',
      ),
    );
  }

  Widget _buildLogisticsDocumentCard(
    ({LogisticsItem item, AttachedFile file}) entry,
    bool isDark,
  ) {
    final state = widget.logisticsState!;
    final path = entry.file.storagePath!;
    return _TrashCard(
      title: entry.file.name,
      subtitle: 'Document logistique : ${entry.item.reference}',
      badgeText:
          'Retiré le ${_removedDateFormat.format(entry.file.removedAt!)}',
      isDark: isDark,
      onRestore: () => _confirm(
        title: 'Restaurer le document ?',
        message:
            '"${entry.file.name}" sera à nouveau visible sur le document ${entry.item.reference}.',
        confirmLabel: 'Restaurer',
        confirmColor: const Color(0xFF10B981),
        action: () => state.restoreDocument(
          itemId: entry.item.id,
          storagePath: path,
          actionUserName: _currentUserName,
        ),
        successMessage: 'Document restauré avec succès.',
      ),
      onDeleteForever: () => _confirmHardDelete(
        message:
            'Cette action est irréversible. "${entry.file.name}" sera définitivement effacé.',
        action: () => state.permanentlyDeleteDocument(
          itemId: entry.item.id,
          storagePath: path,
        ),
        successMessage: 'Document supprimé définitivement.',
      ),
    );
  }

  static final _removedDateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

  String get _currentUserName =>
      widget.appState.currentEmployee?.fullName ?? '';

  // ─── UI partagée ────────────────────────────────────────────────────────

  Widget _buildList({
    required bool isDark,
    required String emptyLabel,
    required int count,
    required Widget Function(int index) itemBuilder,
  }) {
    if (count == 0) return _buildEmptyState(isDark, emptyLabel);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return itemBuilder(index)
            .animate()
            .fade(duration: 300.ms, delay: (index * 50).ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline_rounded,
            size: 64,
            color: isDark ? kDarkTextMuted : kTextMuted,
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    }
  }

  Future<void> _confirmHardDelete({
    required String message,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    await _confirm(
      title: 'Suppression définitive',
      message: message,
      confirmLabel: 'Supprimer définitivement',
      confirmColor: kDanger,
      action: action,
      successMessage: successMessage,
    );
  }
}

/// Carte réutilisable pour un élément de la corbeille (archive, candidat ou
/// document logistique).
class _TrashCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? daysLeft; // null : pas de compte à rebours (utiliser badgeText)
  final String? badgeText; // libellé de badge personnalisé si daysLeft est null
  final bool isDark;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashCard({
    required this.title,
    required this.subtitle,
    this.daysLeft,
    this.badgeText,
    required this.isDark,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    final days = daysLeft;
    final isCritical = days != null && days <= 2;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                    ),
                  ),
                ],
                if (days != null || badgeText != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isCritical ? kDanger : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      days != null
                          ? (days > 0
                                ? 'Suppression définitive dans $days jour(s)'
                                : 'Suppression définitive imminente')
                          : badgeText!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCritical ? kDanger : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.restore_rounded),
                color: const Color(0xFF10B981),
                tooltip: 'Restaurer',
                onPressed: onRestore,
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                color: kDanger,
                tooltip: 'Supprimer définitivement',
                onPressed: onDeleteForever,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
