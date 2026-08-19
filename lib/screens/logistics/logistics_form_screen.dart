import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/logistics_state.dart';
import '../../models/logistics_item.dart';
import '../../models/attached_file.dart';
import '../../widgets/document_preview.dart';
import '../../services/document_scanner_service.dart';

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
    _amountCtrl = TextEditingController(text: item?.amount?.toStringAsFixed(0) ?? '');
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    if (item != null) {
      _docType = item.documentType;
      _issueDate = item.issueDate;
      _files.addAll(item.files);
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final amount = double.tryParse(_amountCtrl.text.replaceAll(' ', ''));

    if (_isEditing) {
      widget.logisticsState.updateItem(
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
      widget.logisticsState.addItem(
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
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isEditing ? 'Document mis à jour !' : 'Document logistique enregistré !'),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le document' : 'Nouveau document logistique'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type de document
              _label('Type de document *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: LogisticsDocType.values.map((t) {
                  final selected = _docType == t;
                  final color = Color(t.colorValue);
                  return GestureDetector(
                    onTap: () => setState(() => _docType = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(t.label,
                        style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF374151),
                        )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Référence / Numéro *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _refCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: FAC-2026-0001',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Référence requise' : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Fournisseur / Partie prenante *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _supplierCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Nom du fournisseur',
                          prefixIcon: Icon(Icons.business_outlined, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Fournisseur requis' : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Montant (FCFA)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Ex: 1250000',
                          prefixIcon: Icon(Icons.payments_outlined, size: 20),
                          suffixText: 'FCFA',
                        ),
                      ),
                      const SizedBox(height: 14),

                      _label('Date d\'émission *'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF64748B)),
                              const SizedBox(width: 10),
                              Text(
                                '${_issueDate.day.toString().padLeft(2, '0')}/${_issueDate.month.toString().padLeft(2, '0')}/${_issueDate.year}',
                                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _label('Notes complémentaires'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'Observations, contexte...'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fichiers
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _label('Fichiers joints'),
                          if (_files.isNotEmpty)
                            Text('${_files.length} fichier(s)',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._files.asMap().entries.map((e) => DocumentPreview(
                        file: e.value,
                        onRemove: () => setState(() => _files.removeAt(e.key)),
                      )),
                      OutlinedButton.icon(
                        onPressed: _addFiles,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Scanner / Importer un document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFF7C3AED)),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_isEditing ? 'Enregistrer les modifications' : 'Enregistrer le document'),
                onPressed: _isLoading ? null : _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF374151)));
}
