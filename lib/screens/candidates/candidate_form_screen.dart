import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/candidates_state.dart';
import '../../models/candidate.dart';
import '../../models/attached_file.dart';
import '../../widgets/document_preview.dart';
import '../../widgets/centered_form_body.dart';
import '../../widgets/glass_form_card.dart';
import '../../widgets/mesh_background.dart';
import '../../services/document_scanner_service.dart';
import '../../theme/app_theme.dart';

class CandidateFormScreen extends StatefulWidget {
  final CandidatesState candidatesState;
  final String currentUserName;
  final Candidate? editingCandidate; // null = création

  const CandidateFormScreen({
    super.key,
    required this.candidatesState,
    required this.currentUserName,
    this.editingCandidate,
  });

  @override
  State<CandidateFormScreen> createState() => _CandidateFormScreenState();
}

class _CandidateFormScreenState extends State<CandidateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;
  String? _selectedPosition;
  final List<AttachedFile> _documents = [];
  bool _isLoading = false;

  static const _positions = [
    'Secrétaire',
    'Comptable',
    'Gestionnaire',
    'Conseiller Principal',
    'Conseiller Adjoint',
  ];

  bool get _isEditing => widget.editingCandidate != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editingCandidate;
    _nameCtrl = TextEditingController(text: c?.fullName ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _notesCtrl = TextEditingController(text: c?.rhNotes ?? '');
    _selectedPosition = c?.targetPosition;
    if (c != null) _documents.addAll(c.documents);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _addDocuments() async {
    final files = await DocumentScannerService().scanOrImportDocument(context);
    if (files.isNotEmpty) {
      setState(() => _documents.addAll(files));
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar(
          'Veuillez sélectionner le poste visé.',
          const Color(0xFFF59E0B),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (_isEditing) {
      widget.candidatesState.updateCandidate(
        id: widget.editingCandidate!.id,
        fullName: _nameCtrl.text,
        targetPosition: _selectedPosition,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        rhNotes: _notesCtrl.text,
        documents: List.from(_documents),
        actionUserName: widget.currentUserName,
      );
    } else {
      widget.candidatesState.addCandidate(
        fullName: _nameCtrl.text,
        targetPosition: _selectedPosition!,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        rhNotes: _notesCtrl.text,
        documents: List.from(_documents),
        actionUserName: widget.currentUserName,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar(
        _isEditing
            ? 'Dossier candidat mis à jour !'
            : 'Candidat ajouté avec succès !',
        const Color(0xFF10B981),
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
        title: Text(_isEditing ? 'Modifier le dossier' : 'Nouveau candidat'),
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
                    // Poste visé
                    _label('Poste visé *', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _positions.map((p) {
                        final selected = _selectedPosition == p;
                        const color = Color(0xFFEC4899);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPosition = p),
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
                              p,
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
                          _label('Nom complet *', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Prénom Nom',
                              prefixIcon: Icon(Icons.person_outlined, size: 20),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nom requis'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          _label('Email', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'candidat@email.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _label('Téléphone', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '+221 77 000 00 00',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _label('Notes RH', isDark),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText:
                                  'Compétences, observations, disponibilités...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Documents
                    GlassFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _label('Documents (CV, pièces...)', isDark),
                              if (_documents.isNotEmpty)
                                Text(
                                  '${_documents.length} fichier(s)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFFEC4899),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._documents.asMap().entries.map(
                            (e) => DocumentPreview(
                              file: e.value,
                              onRemove: () =>
                                  setState(() => _documents.removeAt(e.key)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addDocuments,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Scanner / Importer un document'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEC4899),
                              side: const BorderSide(color: Color(0xFFEC4899)),
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
                        backgroundColor: const Color(0xFFEC4899),
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
                            : 'Créer le dossier candidat',
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

  SnackBar _snackBar(String msg, Color color) => SnackBar(
    content: Text(msg),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
  );
}
