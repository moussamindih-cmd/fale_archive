import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/folder.dart';
import '../app_state.dart';
import '../widgets/folder_card.dart';
import '../widgets/app_button.dart';

class FoldersScreen extends StatefulWidget {
  final AppStateProvider appState;

  const FoldersScreen({super.key, required this.appState});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  void _createNewFolder() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau dossier d archives'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du dossier',
                hintText: 'Ex: Contrats Clients 2026',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final newF = Folder(
                  id: 'fold_${DateTime.now().millisecondsSinceEpoch}',
                  organizationId: widget.appState.currentOrg.id,
                  name: nameCtrl.text.trim(),
                  departmentId: widget.appState.departments[0].id,
                  documentCount: 0,
                  createdAt: DateTime.now(),
                );
                widget.appState.addFolder(newF);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dossier "${newF.name}" créé avec succès !')),
                );
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootFolders = widget.appState.folders.where((f) => f.parentId == null).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Arborescence des dossiers',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Organisez vos répertoires et sous-dossiers par département.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Nouveau dossier',
                icon: Icons.create_new_folder,
                onPressed: _createNewFolder,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                childAspectRatio: 2.2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: rootFolders.length,
              itemBuilder: (context, index) {
                final folder = rootFolders[index];
                return FolderCard(
                  folder: folder,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FolderDetailsScreen(
                          folder: folder,
                          appState: widget.appState,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FolderDetailsScreen extends StatelessWidget {
  final Folder folder;
  final AppStateProvider appState;

  const FolderDetailsScreen({
    super.key,
    required this.folder,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final subFolders = appState.folders.where((f) => f.parentId == folder.id).toList();
    final docs = appState.documents.where((d) => d.folderId == folder.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Dossier: ${folder.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subFolders.isNotEmpty) ...[
              const Text(
                'Sous-dossiers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  childAspectRatio: 2.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: subFolders.length,
                itemBuilder: (context, index) {
                  return FolderCard(
                    folder: subFolders[index],
                    onTap: () {},
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Documents dans ${folder.name} (${docs.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (var d in docs) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: AppColors.accentCrimson),
                  title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Réf: ${d.reference} • ${d.fileSizeMB} MB'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
