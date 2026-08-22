import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/logistics_state.dart';
import '../../models/logistics_item.dart';
import '../../models/attached_file.dart';
import '../../widgets/document_preview.dart';
import '../../widgets/centered_form_body.dart';
import '../../widgets/glass_form_card.dart';
import '../../widgets/mesh_background.dart';
import '../../services/document_scanner_service.dart';
import '../../theme/app_theme.dart';

class LogisticsFormScreen extends StatefulWidget {
  final LogisticsState logisticsState;
  final String currentUserId;
  final String currentUserName;
  final LogisticsItem? editingItem;

  const LogisticsFormScreen({
    super.key,
    required this.logisticsState,
    required this.currentUserId,
    required this.currentUserName,
    this.editingItem,
  });

  @override
  State<LogisticsFormScreen> createState() => _LogisticsFormScreenState();
}

class _LogisticsFormScreenState extends State<LogisticsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _refCtrl;
  late TextEditingController _supplierCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  LogisticsDocType _docType = LogisticsDocType.facture;
  DateTime _issueDate = DateTime.now();
  final List<AttachedFile> _files = [];
  bool _isLoading = false;

  bool get _isEditing => widget.editingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editingItem;
    _refCtrl = TextEditingController(text: item?.reference ?? '');
    _supplierCtrl = TextEditingController(text: item?.supplier ?? '');
    _amountCtrl = TextEditingController(
      text: item?.amount?.toStringAsFixed(0) ?? '',
    );
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    if (item != null) {
      _docType = item.documentType;
      _issueDate = item.issueDate;
      _files.addAll(item.files.where((f) => !f.isRemoved));
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _supplierCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _issueDate = picked);
  }

  Future<void> _addFiles() async {
    final files = await DocumentScannerService().scanOrImportDocument(context);
    if (files.isNotEmpty) setState(() => _files.addAll(files));
  }

  /// Retire un fichier. S'il est déjà persisté (storagePath renseigné), il
  /// part en corbeille (récupérable) au lieu d'être perdu immédiatement.
  Future<void> _removeFile(int index) async {
    final file = _files[index];
    setState(() => _files.removeAt(index));
    if (file.storagePath == null || widget.editingItem == null) return;
    await widget.logisticsState.removeDocument(
      itemId: widget.editingItem!.id,
      storagePath: file.storagePath!,
      actionUserName: widget.currentUserName,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${file.name}" déplacé vers la corbeille.'),
          backgroundColor: const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final amount = double.tryParse(_amountCtrl.text.replaceAll(' ', ''));

    String? error;
    if (_isEditing) {
      await widget.logisticsState.updateItem(
        id: widget.editingItem!.id,
        documentType: _docType,
        reference: _refCtrl.text,
        amount: amount,
        supplier: _supplierCtrl.text,
        issueDate: _issueDate,
        notes: _notesCtrl.text,
        files: List.from(_files),
        actionUserName: widget.currentUserName,
      );
    } else {
      error = await widget.logisticsState.addItem(
        documentType: _docType,
        reference: _refCtrl.text,
        amount: amount,
        supplier: _supplierCtrl.text,
        issueDate: _issueDate,
        notes: _notesCtrl.text,
        files: List.from(_files),
        registeredById: widget.currentUserId,
        registeredByName: widget.currentUserName,
      );
    }

    if (!mounted) return;
    if (error != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Document mis à jour !'
              : 'Document logistique enregistré !',
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier le document' : 'Nouveau document logistique',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedMeshBackground(
        child: SafeArea(
          child: CenteredFormBody(
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: glassInputDecorationTheme(isDark),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type de document
                    _label('Type de document *', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LogisticsDocType.values.map((t) {
                        final selected = _docType == t;
                        final color = Color(t.colorValue);
                        return GestureDetector(
                          onTap: () => setState(() => _docType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.white.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : Colors.white.withValues(
                                        alpha: isDark ? 0.1 : 0.7,
                                      ),
                              ),
                            ),
                            child: Text(
                              t.label,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : (isDark
                                          ? kDarkTextPrimary
                                          : const Color(0xFF374151)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    GlassFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Référence / Numéro *', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _refCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ex: FAC-2026-0001',
                              prefixIcon: Icon(Icons.tag_rounded, size: 20),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Référence requise'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          _label('Fournisseur / Partie prenante *', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _supplierCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nom du fournisseur',
                              prefixIcon: Icon(
                                Icons.business_outlined,
                                size: 20,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Fournisseur requis'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          _label('Montant (FCFA)', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Ex: 1250000',
                              prefixIcon: Icon(
                                Icons.payments_outlined,
                                size: 20,
                              ),
                              suffixText: 'FCFA',
                            ),
                          ),
                          const SizedBox(height: 14),

                          _label('Date d\'émission *', isDark),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.1 : 0.7,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: isDark
                                        ? kDarkTextSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${_issueDate.day.toString().padLeft(2, '0')}/${_issueDate.month.toString().padLeft(2, '0')}/${_issueDate.year}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: isDark
                                          ? kDarkTextPrimary
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _label('Notes complémentaires', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Observations, contexte...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fichiers
                    GlassFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _label('Fichiers joints', isDark),
                              if (_files.isNotEmpty)
                                Text(
                                  '${_files.length} fichier(s)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._files.asMap().entries.map(
                            (e) => DocumentPreview(
                              file: e.value,
                              onRemove: () => _removeFile(e.key),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addFiles,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Scanner / Importer un document'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFF7C3AED)),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _isEditing
                            ? 'Enregistrer les modifications'
                            : 'Enregistrer le document',
                      ),
                      onPressed: _isLoading ? null : _handleSubmit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.outfit(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: isDark ? kDarkTextPrimary : const Color(0xFF374151),
    ),
  );
}
