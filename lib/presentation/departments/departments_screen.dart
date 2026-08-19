import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/department.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class DepartmentsScreen extends StatefulWidget {
  final AppStateProvider appState;

  const DepartmentsScreen({super.key, required this.appState});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  void _showCreateDepartmentDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.corporate_fare, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Nouveau Département'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Créez un nouveau département dans la structure organisationnelle.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du département *',
                  hintText: 'Ex: Informatique & Systèmes',
                  prefixIcon: Icon(Icons.business_center_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code court *',
                  hintText: 'Ex: IT, RH, FIN',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Rôle et responsabilités du département',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Créer le département'),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nom et code du département sont obligatoires.'),
                    backgroundColor: AppColors.accentCrimson,
                  ),
                );
                return;
              }
              final newDept = Department(
                id: 'dept_${DateTime.now().millisecondsSinceEpoch}',
                organizationId: widget.appState.currentOrg.id,
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim().toUpperCase(),
                description: descCtrl.text.trim().isEmpty
                    ? 'Département ${nameCtrl.text.trim()}'
                    : descCtrl.text.trim(),
                userCount: 0,
                createdAt: DateTime.now(),
              );
              widget.appState.addDepartment(newDept);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Département «${newDept.name}» créé avec succès !'),
                  backgroundColor: AppColors.accentEmerald,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depts = widget.appState.departments;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Color palette for department cards
    final colors = [
      AppColors.primary,
      AppColors.accentTeal,
      AppColors.accentPurple,
      AppColors.accentAmber,
      AppColors.accentEmerald,
      AppColors.accentCrimson,
    ];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestion des Départements',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Structure organisationnelle de votre entreprise.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Nouveau Département',
                icon: Icons.add,
                onPressed: _showCreateDepartmentDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.corporate_fare, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${depts.length} département(s) — ${depts.fold(0, (sum, d) => sum + d.userCount)} membres au total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grid of department cards
          Expanded(
            child: depts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.corporate_fare_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        Text(
                          'Aucun département créé.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cliquez sur « Nouveau Département » pour commencer.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      childAspectRatio: 2.1,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: depts.length,
                    itemBuilder: (context, index) {
                      final d = depts[index];
                      final color = colors[index % colors.length];

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: color.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      d.code,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.borderDark : AppColors.bgLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.people_alt_outlined, size: 12, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${d.userCount} membres',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                d.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                d.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
