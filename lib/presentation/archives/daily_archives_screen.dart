import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/daily_archive.dart';
import '../app_state.dart';
import '../../core/services/offline_queue_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class DailyArchivesScreen extends StatefulWidget {
  final AppStateProvider appState;

  const DailyArchivesScreen({super.key, required this.appState});

  @override
  State<DailyArchivesScreen> createState() => _DailyArchivesScreenState();
}

class _DailyArchivesScreenState extends State<DailyArchivesScreen> {
  String? _selectedJobFilter;
  final DateTime _selectedDate = DateTime.now();

  void _showNewDailyArchiveModal() {
    final currentUser = widget.appState.currentUser;
    final titleCtrl = TextEditingController(
      text: 'Versement quotidien ${currentUser.role.name} du ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
    );
    final summaryCtrl = TextEditingController();
    final docCountCtrl = TextEditingController(text: '5');
    String category = 'Dossiers du jour';

    if (currentUser.role.id == 'role_secretaire') {
      category = 'Courriers & Registre du jour';
    } else if (currentUser.role.id == 'role_comptable') {
      category = 'Pièces Comptables & Caisses';
    } else if (currentUser.role.id == 'role_gestionnaire') {
      category = 'Dossiers Opérationnels du jour';
    } else if (currentUser.role.id == 'role_conseiller_principal') {
      category = 'Avis Techniques & Rapports d Expertise';
    } else if (currentUser.role.id == 'role_conseiller_adjoint') {
      category = 'Synthèses & Notes de Projets';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nouveau Versement Journalier (${currentUser.role.name})'),
        content: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agent: ${currentUser.fullName} (${currentUser.role.name})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Titre du versement journalier *',
                  controller: titleCtrl,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Catégorie des pièces du jour',
                  controller: TextEditingController(text: category),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Résumé synthétique des dossiers traités *',
                  hint: 'Précisez les pièces versées, décisions ou pièces de caisse du jour...',
                  controller: summaryCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Nombre de pièces / fichiers numérisés',
                  controller: docCountCtrl,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Valider l archive du jour'),
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              final item = DailyArchiveItem(
                id: 'd_arch_${DateTime.now().millisecondsSinceEpoch}',
                organizationId: widget.appState.currentOrg.id,
                userId: currentUser.id,
                userName: currentUser.fullName,
                userJobTitle: currentUser.role.name,
                archiveDate: _selectedDate,
                category: category,
                title: titleCtrl.text.trim(),
                reference: 'JOUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                summary: summaryCtrl.text.trim().isEmpty
                    ? 'Versement des pièces de la journée effectué avec succès.'
                    : summaryCtrl.text.trim(),
                documentCount: int.tryParse(docCountCtrl.text) ?? 1,
                status: 'Enregistré',
                createdAt: DateTime.now(),
              );

              final offlineService = OfflineQueueService();
              if (offlineService.isOnline) {
                widget.appState.addDailyArchive(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Versement journalier enregistré et transmis !'),
                    backgroundColor: AppColors.accentEmerald,
                  ),
                );
              } else {
                offlineService.enqueueDailyArchive(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode hors-ligne : Versement sauvegardé localement dans la file d attente !'),
                    backgroundColor: AppColors.accentAmber,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archives = widget.appState.dailyArchives.where((item) {
      if (_selectedJobFilter != null && item.userJobTitle != _selectedJobFilter) {
        return false;
      }
      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = widget.appState.currentUser;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Archives Journalières par Poste',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Registres quotidiens obligatoires : Secrétaire, Comptable, Gestionnaire, Conseiller Principal & Conseiller Adjoint.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Faire mon archive du jour (${currentUser.role.name})',
                icon: Icons.create,
                onPressed: _showNewDailyArchiveModal,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Daily Completion Status Gauge Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified, color: AppColors.accentEmerald, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suivi de versement quotidien du jour',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '5 / 5 postes ont déjà versé leur archive journalière pour aujourd hui.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '100% Complété',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentEmerald, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Job Position Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous les postes'),
                  selected: _selectedJobFilter == null,
                  onSelected: (val) => setState(() => _selectedJobFilter = null),
                ),
                const SizedBox(width: 8),
                for (var job in ['Secrétaire', 'Comptable', 'Gestionnaire', 'Conseiller Principal', 'Conseiller Adjoint']) ...[
                  FilterChip(
                    label: Text(job),
                    selected: _selectedJobFilter == job,
                    onSelected: (val) => setState(() => _selectedJobFilter = val ? job : null),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily archives feed list
          Expanded(
            child: ListView.builder(
              itemCount: archives.length,
              itemBuilder: (context, index) {
                final item = archives[index];
                Color badgeColor = AppColors.primary;
                if (item.userJobTitle == 'Secrétaire') badgeColor = AppColors.accentPurple;
                if (item.userJobTitle == 'Comptable') badgeColor = AppColors.accentEmerald;
                if (item.userJobTitle == 'Gestionnaire') badgeColor = AppColors.accentTeal;
                if (item.userJobTitle == 'Conseiller Principal') badgeColor = AppColors.primary;
                if (item.userJobTitle == 'Conseiller Adjoint') badgeColor = AppColors.accentAmber;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    item.userJobTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  item.userName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentEmerald.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentEmerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Réf: ${item.reference} • Catégorie: ${item.category} • ${item.documentCount} pièces numérisées',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDark : AppColors.bgLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.summary,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
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
