import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class AddDocumentScreen extends StatefulWidget {
  final AppStateProvider appState;

  const AddDocumentScreen({super.key, required this.appState});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _titleController = TextEditingController();
  final _refController = TextEditingController(text: 'ARCH-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _descController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _locationController = TextEditingController(text: 'BAT-A > S1 > ARM-01 > R1 > B-01');

  String? _selectedCategory;
  String? _selectedDepartment;
  ConfidentialityLevel _confidentiality = ConfidentialityLevel.internal;
  int _retentionYears = 10;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _attachedFileName;

  @override
  void initState() {
    super.initState();
    if (widget.appState.categories.isNotEmpty) {
      _selectedCategory = widget.appState.categories[0].id;
    }
    if (widget.appState.departments.isNotEmpty) {
      _selectedDepartment = widget.appState.departments[0].id;
    }
  }

  void _simulateFileUpload() {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _attachedFileName = "Document_Numerise_2026.pdf";
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_uploadProgress >= 1.0) {
        setState(() => _isUploading = false);
        return false;
      }
      setState(() => _uploadProgress += 0.2);
      return true;
    });
  }

  void _handleSubmit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un titre de document')),
      );
      return;
    }

    final catObj = widget.appState.categories.firstWhere(
      (c) => c.id == _selectedCategory,
      orElse: () => widget.appState.categories[0],
    );
    final deptObj = widget.appState.departments.firstWhere(
      (d) => d.id == _selectedDepartment,
      orElse: () => widget.appState.departments[0],
    );

    final newDoc = DocumentItem(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      organizationId: widget.appState.currentOrg.id,
      folderId: widget.appState.folders[0].id,
      folderName: widget.appState.folders[0].name,
      categoryId: catObj.id,
      categoryName: catObj.name,
      documentTypeId: 'type_contrat',
      documentTypeName: 'Contrat',
      departmentId: deptObj.id,
      departmentName: deptObj.name,
      createdBy: widget.appState.currentUser.id,
      createdByName: widget.appState.currentUser.fullName,
      title: _titleController.text.trim(),
      reference: _refController.text.trim(),
      description: _descController.text.trim(),
      fileName: _attachedFileName ?? 'Document_Numerise.pdf',
      fileUrl: 'https://fale-archives.storage/docs/sample.pdf',
      fileSizeMB: 3.5,
      mimeType: 'application/pdf',
      confidentiality: _confidentiality,
      retentionStatus: RetentionStatus.active,
      retentionPeriodYears: _retentionYears,
      documentDate: DateTime.now(),
      expirationDate: DateTime.now().add(Duration(days: 365 * _retentionYears)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      keywords: _keywordsController.text.split(',').map((e) => e.trim()).toList(),
      physicalLocationRef: _locationController.text.trim(),
    );

    widget.appState.addDocument(newDoc);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archive ajoutée avec succès !')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une nouvelle archive'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formulaire d versement d archive numérisée',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Remplissez les métadonnées pour assurer l indexation et la traçabilité.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(height: 32),

                // Drag & Drop File Selector Zone
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        _attachedFileName ?? 'Glissez-déposez votre fichier ici (PDF, DOCX, XLSX, PNG...)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Formats acceptés: PDF, DOC, XLS, PNG, TIFF (Max: 50MB)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Parcourir les fichiers ou Scanner',
                        icon: Icons.folder_open,
                        variant: AppButtonVariant.outlined,
                        onPressed: _simulateFileUpload,
                      ),
                      if (_isUploading || _uploadProgress > 0) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload en cours... ${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Main Metadata Input Grid
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Titre du document *',
                        hint: 'Ex: Contrat Prestataire Informatique 2026',
                        controller: _titleController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        label: 'Référence unique *',
                        controller: _refController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category & Department Selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            items: widget.appState.categories
                                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Département', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDepartment,
                            items: widget.appState.departments
                                .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedDepartment = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Confidentiality & Retention Period
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Niveau de confidentialité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<ConfidentialityLevel>(
                            initialValue: _confidentiality,
                            items: ConfidentialityLevel.values
                                .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl.label)))
                                .toList(),
                            onChanged: (val) => setState(() => _confidentiality = val!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        label: 'Durée de conservation (en années)',
                        hint: '10',
                        controller: TextEditingController(text: '$_retentionYears'),
                        onChanged: (val) => _retentionYears = int.tryParse(val) ?? 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Description & Résumé',
                  hint: 'Précisez l objet principal du document...',
                  controller: _descController,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Mots-clés (séparés par des virgules)',
                  hint: 'Contrat, Finance, Informatique, FALE TECH',
                  controller: _keywordsController,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Emplacement physique (GAE)',
                  hint: 'Bâtiment > Salle > Armoire > Rayon > Boîte',
                  controller: _locationController,
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 32),

                // Submit buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Annuler',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: 'Enregistrer l archive',
                      icon: Icons.check,
                      onPressed: _handleSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
