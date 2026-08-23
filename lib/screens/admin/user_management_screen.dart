import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/app_state.dart';
import '../../models/employee.dart';
import '../../models/job_titles.dart';
import '../../models/signup_rules.dart';
import 'allowed_emails_screen.dart';
import '../../models/subscription.dart';
import '../../models/user_role.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  final AppState appState;

  const UserManagementScreen({super.key, required this.appState});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _searchText = '';
  UserRole? _filterRole;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Employee> get _filtered {
    return widget.appState.allEmployees.where((e) {
      if (_filterRole != null && e.role != _filterRole) return false;
      if (_searchText.isNotEmpty) {
        final kw = _searchText.toLowerCase();
        final match = e.fullName.toLowerCase().contains(kw) || e.email.toLowerCase().contains(kw);
        if (!match) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.role.index.compareTo(b.role.index));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final filtered = _filtered;
        final admin = widget.appState.currentEmployee!;
        
        final subInfo = widget.appState.subscriptionInfo;
        final maxUsers = subInfo?.activePlan?.maxUsers ?? 1;
        final currentUsers = widget.appState.allEmployees.length; // ou les actifs seulement
        final isQuotaReached = currentUsers >= maxUsers && maxUsers != 9999;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: const Text('Gestion des utilisateurs'),
            backgroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(icon: Icon(Icons.groups_outlined), text: 'Membres'),
                Tab(
                  icon: Icon(Icons.mark_email_read_outlined),
                  text: 'Autorisations',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _membersTab(
                context,
                admin,
                filtered,
                subInfo,
                maxUsers,
                currentUsers,
                isQuotaReached,
              ),
              AllowedEmailsScreen(appState: widget.appState, admin: admin),
            ],
          ),
        );
      },
    );
  }

  Widget _membersTab(
    BuildContext context,
    Employee admin,
    List<Employee> filtered,
    SubscriptionInfo? subInfo,
    int maxUsers,
    int currentUsers,
    bool isQuotaReached,
  ) {
    return Column(
            children: [
              // Quota indicator
              if (subInfo != null && maxUsers != 9999)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Utilisation du quota :', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                      Text('$currentUsers / $maxUsers', 
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, 
                          color: isQuotaReached ? const Color(0xFFEF4444) : const Color(0xFF10B981)
                        )
                      ),
                    ],
                  ),
                ),
              // Recherche
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchText = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou email...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () { _searchCtrl.clear(); setState(() => _searchText = ''); })
                        : null,
                  ),
                ),
              ),

              // Filtres rôle
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _roleChip('Tous', null),
                      const SizedBox(width: 6),
                      ...UserRole.values.map((r) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _roleChip(r.shortLabel, r),
                      )),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text('${filtered.length} utilisateur(s)',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),

              // Liste
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('Aucun utilisateur trouvé.',
                        style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8))))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildUserCard(context, filtered[i], admin),
                      ),
              ),
            ],
    );
  }

  Widget _roleChip(String label, UserRole? role) {
    final active = _filterRole == role;
    final color = role != null ? roleColor(role) : const Color(0xFF64748B);
    return GestureDetector(
      onTap: () => setState(() => _filterRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? color : const Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Employee emp, Employee admin) {
    final color = employeeColor(emp.jobTitle, emp.role);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emp.initials,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emp.fullName,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      if (!emp.isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                          child: Text('Désactivé', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                        ),
                    ],
                  ),
                  Text(emp.email,
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(emp.role.shortLabel,
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ),
                      if (emp.jobTitle.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('· ${emp.jobTitle}',
                          style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _showEditUserDialog(context, admin, emp);
                    break;
                  case 'role':
                    _showRoleDialog(context, emp, admin);
                    break;
                  case 'toggle':
                    widget.appState.toggleEmployeeStatus(id: emp.id, actionUserName: admin.fullName);
                    break;
                  case 'delete':
                    _confirmDelete(context, emp, admin);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Modifier'), dense: true)),
                const PopupMenuItem(value: 'role', child: ListTile(leading: Icon(Icons.shield_outlined), title: Text('Changer le rôle'), dense: true)),
                PopupMenuItem(value: 'toggle', child: ListTile(
                  leading: Icon(emp.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded),
                  title: Text(emp.isActive ? 'Désactiver' : 'Réactiver'), dense: true)),
                const PopupMenuItem(value: 'delete', child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  title: Text('Supprimer', style: TextStyle(color: Color(0xFFEF4444))), dense: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context, Employee emp, Employee admin) {
    UserRole selectedRole = emp.role;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Changer le rôle de ${emp.fullName}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: RadioGroup<UserRole>(
            groupValue: selectedRole,
            onChanged: (v) {
              if (v != null) {
                setDialogState(() => selectedRole = v);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: UserRole.values.map((r) {
                final color = roleColor(r);
                return RadioListTile<UserRole>(
                  value: r,
                  title: Text(r.label),
                  subtitle: selectedRole == r
                      ? Text('Sélectionné', style: TextStyle(color: color, fontSize: 11))
                      : null,
                  activeColor: color,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                widget.appState.changeEmployeeRole(id: emp.id, newRole: selectedRole, actionUserName: admin.fullName);
                Navigator.pop(ctx);
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Édition d'un membre existant.
  ///
  /// La branche de création a été retirée : elle appelait `register()`, donc
  /// `auth.signUp` sur le client courant — Supabase remplaçait alors la session
  /// de l'administrateur par celle du compte qu'il venait de créer — et posait
  /// le mot de passe '123456' par défaut. Les comptes naissent désormais de
  /// l'auto-inscription, autorisée depuis l'onglet « Autorisations ».
  void _showEditUserDialog(BuildContext context, Employee admin, Employee editing) {
    final nameCtrl = TextEditingController(text: editing.fullName);
    final emailCtrl = TextEditingController(text: editing.email);
    String? selectedJob = editing.jobTitle.isEmpty ? null : editing.jobTitle;
    UserRole selectedRole = editing.role;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier l\'utilisateur'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom complet *', prefixIcon: Icon(Icons.person_outlined, size: 20)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                    validator: (v) => isValidEmail(v ?? '') ? null : 'Email invalide',
                  ),
                  const SizedBox(height: 14),
                  Text('Rôle :', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.shield_outlined, size: 20)),
                    // `superAdmin` est exclu : il traverse les organisations et
                    // `guard_employee_privileges()` refuse de toute façon de le
                    // laisser attribuer par un simple administrateur.
                    items: UserRole.values
                        .where((r) => r != UserRole.superAdmin)
                        .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    onChanged: (r) => setDialogState(() => selectedRole = r!),
                  ),
                  if (selectedRole == UserRole.employe) ...[
                    const SizedBox(height: 14),
                    Text('Poste :', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedJob,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.work_outline, size: 20)),
                      hint: const Text('Sélectionner...'),
                      items: kJobTitles.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                      onChanged: (j) => setDialogState(() => selectedJob = j),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final navigator = Navigator.of(ctx);
                await widget.appState.updateEmployee(
                  id: editing.id,
                  fullName: nameCtrl.text,
                  email: emailCtrl.text,
                  jobTitle: selectedRole == UserRole.employe ? (selectedJob ?? '') : '',
                  role: selectedRole,
                  actionUserName: admin.fullName,
                );
                navigator.pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Employee emp, Employee admin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text('Le compte de "${emp.fullName}" sera désactivé.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              widget.appState.deleteEmployee(id: emp.id, actionUserName: admin.fullName);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
