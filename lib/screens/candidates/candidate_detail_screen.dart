import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../state/candidates_state.dart';
import '../../models/candidate.dart';
import '../../widgets/document_preview.dart';
import '../../widgets/comments_timeline.dart';
import 'candidate_form_screen.dart';

class CandidateDetailScreen extends StatefulWidget {
  final String candidateId;
  final CandidatesState candidatesState;
  final String currentUserName;
  final bool canEdit;

  const CandidateDetailScreen({
    super.key,
    required this.candidateId,
    required this.candidatesState,
    required this.currentUserName,
    this.canEdit = true,
  });

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen> {
  String get candidateId => widget.candidateId;
  CandidatesState get candidatesState => widget.candidatesState;
  String get currentUserName => widget.currentUserName;
  bool get canEdit => widget.canEdit;

  @override
  void initState() {
    super.initState();
    candidatesState.loadHistory(candidateId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: candidatesState,
      builder: (context, _) {
        final candidate = candidatesState.getCandidateById(candidateId);
        if (candidate == null) {
          return const Scaffold(
            body: Center(child: Text('Candidat introuvable.')),
          );
        }
        final color = Color(candidate.status.colorValue);

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: Text(candidate.fullName),
            backgroundColor: Colors.white,
            actions: canEdit
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: 'Modifier',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CandidateFormScreen(
                            candidatesState: candidatesState,
                            currentUserName: currentUserName,
                            editingCandidate: candidate,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmDelete(context, candidate),
                    ),
                  ]
                : null,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte identité ─────────────────────────────────────
                _buildIdentityCard(candidate, color),
                const SizedBox(height: 16),

                // ── Changement de statut (RH/Admin) ───────────────────
                if (canEdit) ...[
                  _buildStatusChanger(context, candidate, color),
                  const SizedBox(height: 16),
                ],

                // ── Notes RH ──────────────────────────────────────────
                _buildNotesSection(context, candidate),
                const SizedBox(height: 16),

                // ── Documents attachés ─────────────────────────────────
                if (candidate.documents.any((f) => !f.isRemoved)) ...[
                  _buildSection(
                    title: 'Documents attachés',
                    icon: Icons.attach_file_rounded,
                    child: Column(
                      children: candidate.documents
                          .where((f) => !f.isRemoved)
                          .map((f) => DocumentPreview(file: f))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Historique & commentaires ───────────────────────────
                _buildSection(
                  title: 'Activité & commentaires',
                  icon: Icons.forum_outlined,
                  child: CommentsTimeline(
                    entries: candidatesState.historyFor(candidate.id),
                    accentColor: const Color(0xFF2563EB),
                    onSendComment: (text) => candidatesState.addComment(
                      candidateId: candidate.id,
                      text: text,
                      authorName: currentUserName,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdentityCard(Candidate c, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      c.initials,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.status.label,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _infoRow(
              Icons.work_outline_rounded,
              'Poste visé',
              c.targetPosition,
            ),
            if (c.email.isNotEmpty)
              _infoRow(Icons.email_outlined, 'Email', c.email),
            if (c.phone.isNotEmpty)
              _infoRow(Icons.phone_outlined, 'Téléphone', c.phone),
            _infoRow(
              Icons.calendar_today_outlined,
              'Date de candidature',
              DateFormat('dd MMMM yyyy', 'fr_FR').format(c.applicationDate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChanger(BuildContext context, Candidate c, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changer le statut',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CandidateStatus.values.map((s) {
                final isActive = c.status == s;
                final sColor = Color(s.colorValue);
                return GestureDetector(
                  onTap: isActive
                      ? null
                      : () {
                          candidatesState.changeStatus(
                            id: c.id,
                            newStatus: s,
                            actionUserName: currentUserName,
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? sColor : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? sColor : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      s.label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, Candidate c) {
    return _buildSection(
      title: 'Notes RH',
      icon: Icons.notes_rounded,
      child: c.rhNotes.isEmpty
          ? Text(
              'Aucune note.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            )
          : Text(
              c.rhNotes,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF374151),
                height: 1.5,
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Candidate c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce dossier ?'),
        content: Text(
          'Le dossier de "${c.fullName}" sera archivé et ne sera plus visible dans la liste active.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              candidatesState.softDeleteCandidate(
                id: c.id,
                actionUserName: currentUserName,
              );
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
