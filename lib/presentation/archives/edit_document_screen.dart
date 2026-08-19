import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class EditDocumentScreen extends StatefulWidget {
  final DocumentItem document;
  final AppStateProvider appState;

  const EditDocumentScreen({
    super.key,
    required this.document,
    required this.appState,
  });

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  late TextEditingController _titleController;
  late TextEditingController _refController;
  late TextEditingController _descController;
  late ConfidentialityLevel _confidentiality;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.title);
    _refController = TextEditingController(text: widget.document.reference);
    _descController = TextEditingController(text: widget.document.description);
    _confidentiality = widget.document.confidentiality;
  }

  void _handleSave() {
    final updated = widget.document.copyWith(
      title: _titleController.text.trim(),
      reference: _refController.text.trim(),
      description: _descController.text.trim(),
      confidentiality: _confidentiality,
    );
    widget.appState.updateDocument(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document mis à jour !')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier les métadonnées')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Édition du document ${widget.document.reference}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Titre du document',
                  controller: _titleController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Référence',
                  controller: _refController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Description',
                  controller: _descController,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Confidentialité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<ConfidentialityLevel>(
                  initialValue: _confidentiality,
                  items: ConfidentialityLevel.values
                      .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl.label)))
                      .toList(),
                  onChanged: (val) => setState(() => _confidentiality = val!),
                ),
                const SizedBox(height: 24),
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
                      label: 'Enregistrer les modifications',
                      onPressed: _handleSave,
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
