import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../state/logistics_state.dart';
import '../../models/logistics_item.dart';
import '../../models/user_role.dart';
import '../../models/fale_permission.dart';
import '../../widgets/document_preview.dart';
import 'logistics_form_screen.dart';

class LogisticsDetailScreen extends StatelessWidget {
  final String itemId;
  final LogisticsState logisticsState;
  final String currentUserName;
  final UserRole currentUserRole;

  const LogisticsDetailScreen({
    super.key,
    required this.itemId,
    required this.logisticsState,
    required this.currentUserName,
    required this.currentUserRole,
  });

  bool get _canValidate => currentUserRole.hasPermission(FalePermission.validateLogistics);
  bool get _canEdit => currentUserRole == UserRole.employe || currentUserRole == UserRole.admin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: logisticsState,
      builder: (context, _) {
        final item = logisticsState.getItemById(itemId);
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Document introuvable.')));
        }
        final statusColor = Color(item.status.colorValue);
        final typeColor = Color(item.documentType.colorValue);

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: Text(item.reference),
            backgroundColor: Colors.white,
            actions: _canEdit
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => LogisticsFormScreen(
                          logisticsState: logisticsState,
                          currentUserId: '',
                          currentUserName: currentUserName,
                          editingItem: item,
                        ),
                      )),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      onPressed: () => _confirmDelete(context, item),
                    ),
                  ]
                : null,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte principale ──────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(item.documentType.label,
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: typeColor)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(item.status.label,
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(item.reference,
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _infoRow(Icons.business_outlined, 'Fournisseur', item.supplier),
                        if (item.amount != null)
                          _infoRow(Icons.payments_outlined, 'Montant', item.formattedAmount),
                        _infoRow(Icons.calendar_today_outlined, 'Date d\'émission',
                          DateFormat('dd MMMM yyyy', 'fr_FR').format(item.issueDate)),
                        _infoRow(Icons.person_outlined, 'Enregistré par', item.registeredByName),
                        if (item.validatedByName.isNotEmpty)
                          _infoRow(
                            item.status == LogisticsStatus.valide
                                ? Icons.check_circle_outlined
                                : Icons.cancel_outlined,
                            item.status == LogisticsStatus.valide ? 'Validé par' : 'Rejeté par',
                            item.validatedByName,
                          ),
                        if (item.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Notes :',
                            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(item.notes,
                            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151), height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Boutons Valider / Rejeter (Directeur Administratif / Admin) ──
                if (_canValidate && item.status == LogisticsStatus.enAttente) ...[
                  _buildValidationCard(context, item),
                  const SizedBox(height: 16),
                ],

                // ── Documents attachés ─────────────────────────────────
                if (item.files.isNotEmpty) ...[
                  _buildSection(
                    title: 'Fichiers attachés (${item.files.length})',
                    icon: Icons.attach_file_rounded,
                    child: Column(
                      children: item.files.map((f) => DocumentPreview(file: f)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Historique ─────────────────────────────────────────
                _buildSection(
                  title: 'Historique',
                  icon: Icons.history_rounded,
                  child: Column(
                    children: item.history.reversed.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF7C3AED),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.displayAction,
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                if (entry.details.isNotEmpty)
                                  Text(entry.details,
                                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                                Text(
                                  '${entry.userName} · ${DateFormat('dd/MM/yyyy HH:mm').format(entry.timestamp)}',
                                  style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text('$label : ', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
          Expanded(
            child: Text(value,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationCard(BuildContext context, LogisticsItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_reg_rounded, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 8),
                Text('Validation du document',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text('Ce document est en attente de votre validation.',
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF92400E))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                    label: Text('Rejeter', style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showRejectDialog(context, item),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text('Valider', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      logisticsState.validateItem(id: item.id, validatorName: currentUserName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Document validé avec succès.'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, LogisticsItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text('Le document "${item.reference}" sera archivé.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              logisticsState.softDeleteItem(id: item.id, actionUserName: currentUserName);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, LogisticsItem item) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter ce document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Motif du rejet (optionnel) :'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Précisez la raison du rejet...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              logisticsState.rejectItem(id: item.id, validatorName: currentUserName, reason: ctrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Document rejeté.'),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            child: const Text('Confirmer le rejet'),
          ),
        ],
      ),
    );
  }
}
