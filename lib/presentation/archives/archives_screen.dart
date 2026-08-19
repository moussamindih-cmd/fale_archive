import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../data/models/document.dart';
import '../app_state.dart';
import '../widgets/document_card.dart';
import '../widgets/app_button.dart';
import '../widgets/empty_state.dart';

class ArchivesScreen extends StatefulWidget {
  final AppStateProvider appState;

  const ArchivesScreen({super.key, required this.appState});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  DocumentViewMode _viewMode = DocumentViewMode.list;

  void _showDocumentOptions(DocumentItem doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Réf: ${doc.reference} • v${doc.version}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: AppColors.primary),
                title: const Text('Consulter & Prévisualiser'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(AppRoutes.documentViewer, arguments: doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.accentTeal),
                title: const Text('Fiche détaillée & Versions'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(AppRoutes.documentDetails, arguments: doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.accentAmber),
                title: const Text('Modifier les métadonnées'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(AppRoutes.editDocument, arguments: doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: AppColors.accentPurple),
                title: const Text('Créer un lien de partage sécurisé'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showShareDialog(doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Télécharger le fichier'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Téléchargement de ${doc.fileName} démarré...')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.accentCrimson),
                title: const Text('Supprimer l archive', style: TextStyle(color: AppColors.accentCrimson)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.appState.deleteDocument(doc.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Archive ${doc.reference} supprimée')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareDialog(DocumentItem doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partage Sécurisé de Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Génération d un lien temporaire pour "${doc.title}".'),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Durée de validité (jours)',
                hintText: '7',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(value: true, onChanged: (v) {}),
                const Text('Protéger par mot de passe'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton.icon(
            icon: const Icon(Icons.link),
            label: const Text('Copier le lien sécurisé'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lien sécurisé copié dans le presse-papier !')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.appState.filteredDocuments;
    final categories = widget.appState.categories;
    final selectedCatId = widget.appState.selectedCategoryId;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title & Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Archives numérisées (GED)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Gérez vos documents numérisés, leurs versions et durées de conservation.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  // View mode toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.format_list_bulleted,
                            color: _viewMode == DocumentViewMode.list
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          onPressed: () => setState(() => _viewMode = DocumentViewMode.list),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.grid_view,
                            color: _viewMode == DocumentViewMode.grid
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          onPressed: () => setState(() => _viewMode = DocumentViewMode.grid),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Ajouter une archive',
                    icon: Icons.add,
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.addDocument);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Filter Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Toutes les catégories'),
                  selected: selectedCatId == null,
                  onSelected: (val) {
                    widget.appState.setCategoryFilter(null);
                  },
                ),
                const SizedBox(width: 8),
                for (var cat in categories) ...[
                  FilterChip(
                    label: Text(cat.name),
                    selected: selectedCatId == cat.id,
                    onSelected: (val) {
                      widget.appState.setCategoryFilter(val ? cat.id : null);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Documents Display
          Expanded(
            child: docs.isEmpty
                ? EmptyState(
                    title: 'Aucune archive trouvée',
                    message: 'Essayez de modifier votre recherche ou vos filtres.',
                    buttonLabel: 'Ajouter un nouveau document',
                    onAction: () {
                      Navigator.of(context).pushNamed(AppRoutes.addDocument);
                    },
                  )
                : _viewMode == DocumentViewMode.list
                    ? ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return DocumentCard(
                            document: doc,
                            mode: DocumentViewMode.list,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.documentDetails,
                                arguments: doc,
                              );
                            },
                            onMoreTap: () => _showDocumentOptions(doc),
                          );
                        },
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return DocumentCard(
                            document: doc,
                            mode: DocumentViewMode.grid,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.documentDetails,
                                arguments: doc,
                              );
                            },
                            onMoreTap: () => _showDocumentOptions(doc),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
