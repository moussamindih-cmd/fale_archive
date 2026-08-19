import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/category.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class CategoriesScreen extends StatefulWidget {
  final AppStateProvider appState;

  const CategoriesScreen({super.key, required this.appState});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // Palette de couleurs prédéfinies pour les catégories
  static const List<_ColorOption> _colorOptions = [
    _ColorOption(hex: '2563EB', name: 'Bleu Royal'),
    _ColorOption(hex: '10B981', name: 'Émeraude'),
    _ColorOption(hex: 'F59E0B', name: 'Ambre'),
    _ColorOption(hex: '8B5CF6', name: 'Violet'),
    _ColorOption(hex: '0D9488', name: 'Sarcelle'),
    _ColorOption(hex: 'EF4444', name: 'Cramoisi'),
    _ColorOption(hex: 'EC4899', name: 'Rose'),
    _ColorOption(hex: 'F97316', name: 'Orange'),
    _ColorOption(hex: '06B6D4', name: 'Cyan'),
    _ColorOption(hex: '84CC16', name: 'Vert Lime'),
  ];

  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColorHex = _colorOptions[0].hex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.category_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Nouvelle Catégorie'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créez une nouvelle catégorie pour classifier vos documents.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la catégorie *',
                    hintText: 'Ex: Correspondances Officielles',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Types de documents inclus dans cette catégorie',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Couleur de la catégorie',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorOptions.map((opt) {
                    final color = Color(int.parse('0xFF${opt.hex}'));
                    final isSelected = opt.hex == selectedColorHex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColorHex = opt.hex),
                      child: Tooltip(
                        message: opt.name,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                                : [],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
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
              label: const Text('Créer la catégorie'),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le nom de la catégorie est obligatoire.'),
                      backgroundColor: AppColors.accentCrimson,
                    ),
                  );
                  return;
                }
                final newCat = Category(
                  id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                  organizationId: widget.appState.currentOrg.id,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? 'Catégorie ${nameCtrl.text.trim()}'
                      : descCtrl.text.trim(),
                  colorHex: selectedColorHex,
                  documentCount: 0,
                );
                widget.appState.addCategory(newCat);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Catégorie «${newCat.name}» créée avec succès !'),
                    backgroundColor: AppColors.accentEmerald,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.appState.categories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    'Catégories & Taxonomies',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Classifiez vos documents par domaine d activité.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Nouvelle Catégorie',
                icon: Icons.add,
                onPressed: _showCreateCategoryDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, size: 18, color: AppColors.accentPurple),
                const SizedBox(width: 8),
                Text(
                  '${cats.length} catégorie(s) — ${cats.fold(0, (sum, c) => sum + c.documentCount)} documents indexés au total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category list
          Expanded(
            child: cats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        Text(
                          'Aucune catégorie créée.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cliquez sur « Nouvelle Catégorie » pour commencer.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: cats.length,
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      final color = Color(int.parse('0xFF${cat.colorHex}'));
                      final totalDocs = cats.fold(0, (sum, c) => sum + c.documentCount);
                      final fraction = totalDocs > 0 ? (cat.documentCount / totalDocs) : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.category, color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      cat.description,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: fraction.clamp(0.02, 1.0),
                                        minHeight: 4,
                                        color: color,
                                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${cat.documentCount}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    'documents',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
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

class _ColorOption {
  final String hex;
  final String name;
  const _ColorOption({required this.hex, required this.name});
}
