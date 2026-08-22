import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/action_history_entry.dart';
import '../theme/app_theme.dart';

/// Historique d'un dossier (candidat ou document logistique) : actions
/// système en frise chronologique, commentaires d'équipe en bulles de
/// discussion, avec un champ pour en ajouter de nouveaux.
class CommentsTimeline extends StatefulWidget {
  final List<ActionHistoryEntry> entries;
  final Color accentColor;
  final Future<void> Function(String text) onSendComment;

  const CommentsTimeline({
    super.key,
    required this.entries,
    required this.accentColor,
    required this.onSendComment,
  });

  @override
  State<CommentsTimeline> createState() => _CommentsTimelineState();
}

class _CommentsTimelineState extends State<CommentsTimeline> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    await widget.onSendComment(text);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.entries.isEmpty)
          Text(
            'Aucune activité enregistrée.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          )
        else
          Column(
            children: widget.entries.reversed
                .map((entry) => _buildEntry(entry, isDark))
                .toList(),
          ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ajouter un commentaire pour l\'équipe…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? kDarkBorder : kBorderColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? kDarkBorder : kBorderColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: widget.accentColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: widget.accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: 'Envoyer',
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntry(ActionHistoryEntry entry, bool isDark) {
    if (entry.isComment) return _buildCommentBubble(entry, isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: widget.accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayAction,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                if (entry.details.isNotEmpty)
                  Text(
                    entry.details,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                    ),
                  ),
                Text(
                  '${entry.userName} · ${DateFormat('dd/MM/yyyy HH:mm').format(entry.timestamp)}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(ActionHistoryEntry entry, bool isDark) {
    final initials = entry.userName.trim().isEmpty
        ? '?'
        : entry.userName
              .trim()
              .split(RegExp(r'\s+'))
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: widget.accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(
                  alpha: isDark ? 0.1 : 0.06,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.userName,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM HH:mm').format(entry.timestamp),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.details,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
