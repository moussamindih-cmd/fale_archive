import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../state/app_state.dart';
import '../models/attached_file.dart';
import '../theme/app_theme.dart';
import '../services/document_scanner_service.dart';
import '../widgets/centered_form_body.dart';
import '../widgets/glass_form_card.dart';
import '../widgets/mesh_background.dart';

class SubmitArchiveScreen extends StatefulWidget {
  final AppState appState;
  const SubmitArchiveScreen({super.key, required this.appState});

  @override
  State<SubmitArchiveScreen> createState() => _SubmitArchiveScreenState();
}

class _SubmitArchiveScreenState extends State<SubmitArchiveScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  final _summaryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isPickingFiles = false;

  final List<AttachedFile> _attachedFiles = [];

  static const List<String> _allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'zip',
    'rar',
  ];

  @override
  void initState() {
    super.initState();
    final emp = widget.appState.currentEmployee!;
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _titleCtrl = TextEditingController(text: '${emp.archiveCategory} — $date');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() => _isPickingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            if (!_attachedFiles.any((af) => af.name == f.name)) {
              _attachedFiles.add(
                AttachedFile(
                  name: f.name,
                  extension: f.extension?.toLowerCase() ?? '',
                  sizeBytes: f.size,
                  bytes: f.bytes,
                ),
              );
            }
          }
        });
      }
    } finally {
      setState(() => _isPickingFiles = false);
    }
  }

  void _removeFile(int index) {
    setState(() => _attachedFiles.removeAt(index));
  }

  Future<void> _scanDocuments() async {
    final scanned = await DocumentScannerService().scanOrImportDocument(
      context,
    );
    if (scanned.isNotEmpty) {
      setState(() {
        for (final f in scanned) {
          if (!_attachedFiles.any((af) => af.name == f.name)) {
            _attachedFiles.add(f);
          }
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_attachedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Veuillez joindre au moins un fichier.')),
            ],
          ),
          backgroundColor: kWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    widget.appState.submitArchive(
      title: _titleCtrl.text.trim(),
      summary: _summaryCtrl.text.trim(),
      documentCount: _attachedFiles.length,
      files: List.from(_attachedFiles),
      physicalLocation: _locationCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Archive journalière déposée avec succès (${_attachedFiles.length} doc(s)).',
              ),
            ),
          ],
        ),
        backgroundColor: kSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emp = widget.appState.currentEmployee!;
    final color = jobColor(emp.jobTitle);
    final today = DateFormat(
      'EEEE d MMMM yyyy',
      'fr_FR',
    ).format(DateTime.now());
    final todayCapital =
        today.substring(0, 1).toUpperCase() + today.substring(1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Dépôt d\'Archive Quotidienne',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedMeshBackground(
        child: SafeArea(
          child: CenteredFormBody(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bandeau employé
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            emp.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.fullName,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              emp.jobTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              todayCapital,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        jobIcon(emp.jobTitle),
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 28,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                GlassFormCard(
                  padding: const EdgeInsets.all(24),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: glassInputDecorationTheme(isDark),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Catégorie auto
                          _label('Catégorie automatique', isDark),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  jobIcon(emp.jobTitle),
                                  color: color,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    emp.archiveCategory,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                          _label('Titre de l\'archive *', isDark),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Courriers et actes du jour',
                              prefixIcon: Icon(Icons.title_rounded, size: 20),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Titre requis'
                                : null,
                          ),

                          const SizedBox(height: 18),
                          _label('Résumé / Notes descriptives', isDark),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _summaryCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText:
                                  'Décrivez les documents traités, pièces versées...',
                            ),
                          ),

                          const SizedBox(height: 18),
                          _label('Emplacement physique (Optionnel)', isDark),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _locationCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Salle A > Armoire 3 > Rayon B',
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                size: 20,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Zone de téléversement
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _label('Fichiers & pièces jointes *', isDark),
                              if (_attachedFiles.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_attachedFiles.length} fichier(s)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Zone de dépôt
                          GestureDetector(
                            onTap: _isPickingFiles ? null : _pickFiles,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 28,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: _attachedFiles.isNotEmpty
                                    ? color.withValues(
                                        alpha: isDark ? 0.08 : 0.04,
                                      )
                                    : (isDark
                                          ? kDarkSurfaceSubtle
                                          : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _attachedFiles.isNotEmpty
                                      ? color.withValues(alpha: 0.5)
                                      : (isDark ? kDarkBorder : kBorderColor),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _isPickingFiles
                                      ? SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            color: color,
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 38,
                                          color: color,
                                        ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _isPickingFiles
                                        ? 'Sélection en cours...'
                                        : 'Cliquer pour importer des fichiers',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? kDarkTextPrimary
                                          : kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PDF · Word · Excel · PowerPoint · Images · ZIP',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: isDark
                                          ? kDarkTextMuted
                                          : kTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Liste des fichiers sélectionnés
                          if (_attachedFiles.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ...List.generate(_attachedFiles.length, (i) {
                              final file = _attachedFiles[i];
                              return _buildFileItem(file, i, isDark);
                            }),

                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isPickingFiles
                                        ? null
                                        : _pickFiles,
                                    icon: Icon(
                                      Icons.add_rounded,
                                      color: color,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Ajouter plus',
                                      style: GoogleFonts.outfit(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _scanDocuments,
                                    icon: const Icon(
                                      Icons.document_scanner_rounded,
                                      color: Color(0xFF0D9488),
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Scanner',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF0D9488),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 28),

                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
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
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _isLoading
                                    ? 'Envoi en cours...'
                                    : 'Valider l\'archive (${_attachedFiles.length} doc(s))',
                              ),
                              onPressed: _isLoading ? null : _handleSubmit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(AttachedFile file, int index, bool isDark) {
    final iconData = _fileIcon(file.extension);
    final fileColor = _fileColor(file.extension);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceSubtle : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: fileColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: fileColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        file.fileType,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: fileColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      file.readableSize,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? kDarkTextMuted : kTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? kDarkTextMuted : kTextMuted,
            ),
            tooltip: 'Supprimer',
            onPressed: () => _removeFile(index),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return Icons.image_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
        return const Color(0xFF3B82F6);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF10B981);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFF97316);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return const Color(0xFF8B5CF6);
      case 'txt':
        return const Color(0xFF64748B);
      case 'zip':
      case 'rar':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF475569);
    }
  }

  Widget _label(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.outfit(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: isDark ? kDarkTextPrimary : kTextPrimary,
    ),
  );
}
