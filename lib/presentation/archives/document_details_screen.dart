import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../data/models/document.dart';
import '../../data/datasources/mock_data.dart';
import '../app_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/app_button.dart';
import '../widgets/qr_code_widget.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final DocumentItem document;
  final AppStateProvider appState;

  const DocumentDetailsScreen({
    super.key,
    required this.document,
    required this.appState,
  });

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  void _createNewVersion() {
    showDialog(
      context: context,
      builder: (ctx) {
        final commentCtrl = TextEditingController();
        return AlertDialog(
          title: Text('Verser une nouvelle version (v${widget.document.version + 1})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sélectionnez le nouveau fichier révisé à remplacer.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Sélectionner le fichier révisé'),
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes de révision / Changements',
                  hintText: 'Ex: Correction des clauses financières',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final updated = widget.document.copyWith(version: widget.document.version + 1);
                widget.appState.updateDocument(updated);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nouvelle version v${updated.version} enregistrée !')),
                );
              },
              child: const Text('Verser la version'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche Document - ${doc.reference}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partager',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Télécharger',
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Main Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: AppColors.accentCrimson, size: 40),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Référence: ${doc.reference} • Fichier: ${doc.fileName} (${doc.fileSizeMB} MB)',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              StatusBadge.fromRetention(doc.retentionStatus),
                              const SizedBox(width: 10),
                              StatusBadge.fromConfidentiality(doc.confidentiality),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Version Actuelle v${doc.version}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: 'Consulter & Aperçu',
                      icon: Icons.visibility,
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.documentViewer, arguments: doc);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Grid Details & QR Code / Versioning
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Metadata Specs
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Métadonnées Complètes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          _buildDetailRow('Description', doc.description),
                          _buildDetailRow('Catégorie', doc.categoryName),
                          _buildDetailRow('Département', doc.departmentName),
                          _buildDetailRow('Dossier Parent', doc.folderName),
                          _buildDetailRow('Auteur / Numériseur', doc.createdByName),
                          _buildDetailRow('Date du Document', '${doc.documentDate.day}/${doc.documentDate.month}/${doc.documentDate.year}'),
                          _buildDetailRow('Durée de conservation', '${doc.retentionPeriodYears} ans (Expire le ${doc.expirationDate.day}/${doc.expirationDate.month}/${doc.expirationDate.year})'),
                          _buildDetailRow('Mots-clés indexés', doc.keywords.join(', ')),
                          const Divider(height: 24),
                          const Text(
                            'Emplacement Physique (GAE)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: AppColors.accentTeal, size: 18),
                              const SizedBox(width: 8),
                              Text(doc.physicalLocationRef, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column: QR Code Tag & Version Log
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // QR Code Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              const Text(
                                'QR Code d Identification',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              QrCodeWidget(data: doc.reference, size: 130),
                              const SizedBox(height: 8),
                              Text(
                                doc.reference,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Versioning Log Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Historique des versions',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                    tooltip: 'Verser une nouvelle version',
                                    onPressed: _createNewVersion,
                                  ),
                                ],
                              ),
                              const Divider(),
                              for (var ver in MockData.demoVersions) ...[
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Version ${ver.versionNumber} • ${ver.fileName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  subtitle: Text(
                                    'Par ${ver.createdBy} • ${ver.comment}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Restauration de la version v${ver.versionNumber} effectuée !')),
                                      );
                                    },
                                    child: const Text('Restaurer', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                                const Divider(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
