import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/allowed_email.dart';
import '../../models/employee.dart';
import '../../models/job_titles.dart';
import '../../models/signup_rules.dart';
import '../../models/user_role.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Liste des adresses autorisées à créer un compte dans l'organisation.
///
/// C'est ici que l'administrateur enregistre les emails de ses employés. Une
/// adresse absente de cette liste ne donne aucun compte : la fonction Edge
/// `signup-employee` la refuse avant toute création.
class AllowedEmailsScreen extends StatefulWidget {
  const AllowedEmailsScreen({
    super.key,
    required this.appState,
    required this.admin,
  });

  final AppState appState;
  final Employee admin;

  @override
  State<AllowedEmailsScreen> createState() => _AllowedEmailsScreenState();
}

class _AllowedEmailsScreenState extends State<AllowedEmailsScreen> {
  bool _loading = true;
  AllowedEmailStatus? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.appState.loadAllowedEmails();
    if (mounted) setState(() => _loading = false);
  }

  List<AllowedEmail> get _visible {
    final all = widget.appState.allowedEmails;
    if (_filter == null) return all;
    return all.where((e) => e.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _intro(isDark),
                  const SizedBox(height: 16),
                  _actions(),
                  const SizedBox(height: 16),
                  _filters(isDark),
                  const SizedBox(height: 12),
                  if (_visible.isEmpty)
                    _empty(isDark)
                  else
                    ..._visible.map((e) => _tile(e, isDark)),
                ],
              ),
            ),
    );
  }

  // ─── Fragments ─────────────────────────────────────────────────────────

  Widget _intro(bool isDark) {
    final pending = widget.appState.pendingAllowedEmails.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined,
              color: kPrimaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seules ces adresses peuvent créer un compte',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Enregistrez l'adresse professionnelle de chaque employé avec "
                  "son rôle et son poste. L'employé s'inscrit ensuite lui-même ; "
                  "toute adresse absente de cette liste est refusée."
                  "${pending > 0 ? '\n\n$pending adresse(s) en attente d\'inscription.' : ''}",
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Ajouter'),
            onPressed: () => _showAddDialog(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: const Text('Ajouter en masse'),
            onPressed: () => _showBulkDialog(),
          ),
        ),
      ],
    );
  }

  Widget _filters(bool isDark) {
    Widget chip(String label, AllowedEmailStatus? status) {
      final selected = _filter == status;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _filter = status),
          labelStyle: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? kDarkTextSecondary : kTextSecondary),
          ),
          selectedColor: kPrimaryColor,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Toutes', null),
          chip('En attente', AllowedEmailStatus.pending),
          chip('Inscrits', AllowedEmailStatus.registered),
          chip('Révoqués', AllowedEmailStatus.revoked),
        ],
      ),
    );
  }

  Widget _empty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.mark_email_unread_outlined,
              size: 44, color: isDark ? kDarkTextSecondary : kTextSecondary),
          const SizedBox(height: 12),
          Text(
            _filter == null
                ? 'Aucune adresse enregistrée'
                : 'Aucune adresse dans cet état',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(AllowedEmailStatus status) {
    switch (status) {
      case AllowedEmailStatus.pending:
        return const Color(0xFFF59E0B);
      case AllowedEmailStatus.registered:
        return const Color(0xFF10B981);
      case AllowedEmailStatus.revoked:
        return kDanger;
    }
  }

  Widget _tile(AllowedEmail entry, bool isDark) {
    final statusColor = _statusColor(entry.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.role.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.role.icon, size: 20, color: entry.role.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.email,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.fullName == null
                      ? entry.displayRole
                      : '${entry.fullName} · ${entry.displayRole}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.status.label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                size: 20, color: isDark ? kDarkTextSecondary : kTextSecondary),
            onSelected: (value) => _onAction(value, entry),
            itemBuilder: (_) => [
              if (entry.status == AllowedEmailStatus.pending) ...[
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuItem(value: 'revoke', child: Text('Révoquer')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
              if (entry.status == AllowedEmailStatus.revoked) ...[
                const PopupMenuItem(value: 'restore', child: Text('Rétablir')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
              if (entry.status == AllowedEmailStatus.registered)
                const PopupMenuItem(
                  value: 'registered_info',
                  child: Text('Compte déjà créé'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────────

  Future<void> _onAction(String value, AllowedEmail entry) async {
    switch (value) {
      case 'edit':
        _showAddDialog(editing: entry);
      case 'revoke':
        await widget.appState.revokeAllowedEmail(
          id: entry.id,
          actionUserName: widget.admin.fullName,
        );
        if (mounted) setState(() {});
      case 'restore':
        await widget.appState.restoreAllowedEmail(
          id: entry.id,
          actionUserName: widget.admin.fullName,
        );
        if (mounted) setState(() {});
      case 'delete':
        final error = await widget.appState.deleteAllowedEmail(
          id: entry.id,
          actionUserName: widget.admin.fullName,
        );
        if (!mounted) return;
        if (error != null) {
          _snack(error, isError: true);
        } else {
          setState(() {});
        }
      case 'registered_info':
        _snack(
          "Cette adresse a déjà servi à créer un compte. Gérez-le depuis "
          "l'onglet Membres.",
        );
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? kDanger : null,
      ),
    );
  }

  /// Rôles attribuables. `superAdmin` en est absent : il traverse les
  /// organisations et reste réservé à la plateforme — la contrainte
  /// `allowed_emails_role_check` le refuse d'ailleurs en base.
  static final List<UserRole> _assignableRoles = UserRole.values
      .where((r) => r != UserRole.superAdmin)
      .toList(growable: false);

  Future<void> _showAddDialog({AllowedEmail? editing}) async {
    final emailCtrl = TextEditingController(text: editing?.email ?? '');
    final nameCtrl = TextEditingController(text: editing?.fullName ?? '');
    var role = editing?.role ?? UserRole.employe;
    String? job = editing?.jobTitle.isEmpty ?? true ? null : editing!.jobTitle;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editing == null
              ? 'Autoriser une adresse'
              : "Modifier l'autorisation"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    // L'adresse est la clé de l'autorisation : la changer
                    // reviendrait à en créer une autre.
                    enabled: editing == null,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email professionnel *',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                    ),
                    validator: (v) =>
                        isValidEmail(v ?? '') ? null : 'Email invalide',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet (facultatif)',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Rôle *',
                      prefixIcon: Icon(Icons.shield_outlined, size: 20),
                    ),
                    items: _assignableRoles
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    onChanged: (r) => setDialogState(() => role = r!),
                  ),
                  if (role == UserRole.employe) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: job,
                      decoration: const InputDecoration(
                        labelText: 'Poste *',
                        prefixIcon: Icon(Icons.work_outline, size: 20),
                      ),
                      hint: const Text('Sélectionner...'),
                      items: kJobTitles
                          .map((j) =>
                              DropdownMenuItem(value: j, child: Text(j)))
                          .toList(),
                      onChanged: (j) => setDialogState(() => job = j),
                      validator: (v) => (role == UserRole.employe && v == null)
                          ? 'Poste requis'
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final navigator = Navigator.of(ctx);

                if (editing != null) {
                  await widget.appState.updateAllowedEmailEntry(
                    id: editing.id,
                    fullName: nameCtrl.text,
                    role: role,
                    jobTitle: role == UserRole.employe ? (job ?? '') : '',
                    actionUserName: widget.admin.fullName,
                  );
                  navigator.pop();
                  if (mounted) setState(() {});
                  return;
                }

                final error = await widget.appState.addAllowedEmail(
                  email: emailCtrl.text,
                  fullName: nameCtrl.text,
                  role: role,
                  jobTitle: role == UserRole.employe ? (job ?? '') : '',
                  actionUserName: widget.admin.fullName,
                );
                if (error != null) {
                  _snack(error, isError: true);
                  return;
                }
                navigator.pop();
                if (mounted) setState(() {});
              },
              child: Text(editing == null ? 'Autoriser' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
    nameCtrl.dispose();
  }

  Future<void> _showBulkDialog() async {
    final textCtrl = TextEditingController();
    var role = UserRole.employe;
    String? job;
    var busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter en masse'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Une adresse par ligne (les virgules et les points-virgules '
                  'font aussi office de séparateur). Le rôle et le poste '
                  "choisis s'appliquent à tout le lot.",
                  style: GoogleFonts.outfit(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textCtrl,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'amadou.sow@entreprise.com\n'
                        'fatou.diop@entreprise.com',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Rôle appliqué au lot *',
                    prefixIcon: Icon(Icons.shield_outlined, size: 20),
                  ),
                  items: _assignableRoles
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r.label)))
                      .toList(),
                  onChanged: (r) => setDialogState(() => role = r!),
                ),
                if (role == UserRole.employe) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: job,
                    decoration: const InputDecoration(
                      labelText: 'Poste appliqué au lot *',
                      prefixIcon: Icon(Icons.work_outline, size: 20),
                    ),
                    hint: const Text('Sélectionner...'),
                    items: kJobTitles
                        .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                        .toList(),
                    onChanged: (j) => setDialogState(() => job = j),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final emails = _parseEmails(textCtrl.text);
                      if (emails.isEmpty) {
                        _snack('Aucune adresse saisie.', isError: true);
                        return;
                      }
                      if (role == UserRole.employe && job == null) {
                        _snack('Choisissez un poste pour le lot.',
                            isError: true);
                        return;
                      }

                      setDialogState(() => busy = true);
                      final navigator = Navigator.of(ctx);
                      final failures =
                          await widget.appState.addAllowedEmails(
                        emails: emails,
                        role: role,
                        jobTitle: role == UserRole.employe ? (job ?? '') : '',
                        actionUserName: widget.admin.fullName,
                      );
                      navigator.pop();
                      if (!mounted) return;
                      setState(() {});

                      final added = emails.length - failures.length;
                      if (failures.isEmpty) {
                        _snack('$added adresse(s) autorisée(s).');
                      } else {
                        _showBulkReport(added, failures);
                      }
                    },
              child: Text(busy ? 'Ajout...' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );

    textCtrl.dispose();
  }

  /// Découpe la saisie libre. Un collage depuis un tableur arrive séparé par
  /// des retours à la ligne, un copier-coller d'un champ « À : » par des
  /// virgules ou des points-virgules — les trois sont acceptés.
  static List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[\s,;]+'))
        .map(normalizeEmail)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  void _showBulkReport(int added, Map<String, String> failures) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résultat de l\'ajout'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$added adresse(s) autorisée(s).',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('${failures.length} refusée(s) :',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...failures.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· ${e.key} — ${e.value}',
                    style: GoogleFonts.outfit(fontSize: 12.5, height: 1.35),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
