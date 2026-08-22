import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_state.dart';
import '../models/daily_archive.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TrashScreen extends StatefulWidget {
  final AppState appState;

  const TrashScreen({super.key, required this.appState});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final archives = widget.appState.deletedArchives;

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
          ),
          body: archives.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: archives.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildTrashCard(archives[index], isDark)
                        .animate()
                        .fade(duration: 300.ms, delay: (index * 50).ms)
                        .slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOut);
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
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
            'La corbeille est vide',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(DailyArchive archive, bool isDark) {
    final daysLeft = archive.daysUntilDeletion;
    final isCritical = daysLeft <= 2;

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
                  archive.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supprimé par : ${archive.employeeName}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCritical ? kDanger : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Suppression définitive dans $daysLeft jour(s)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCritical ? kDanger : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
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
                onPressed: () => _confirmRestore(archive),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                color: kDanger,
                tooltip: 'Supprimer définitivement',
                onPressed: () => _confirmHardDelete(archive),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(DailyArchive archive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restaurer l\'archive ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text('L\'archive "${archive.title}" sera restaurée et à nouveau visible dans l\'historique.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.appState.restoreArchive(archive.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive restaurée avec succès.')));
      }
    }
  }

  Future<void> _confirmHardDelete(DailyArchive archive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Suppression définitive', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: kDanger)),
        content: Text('Cette action est irréversible. L\'archive "${archive.title}" sera détruite.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.appState.permanentlyDeleteArchive(archive.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive supprimée définitivement.')));
      }
    }
  }
}
