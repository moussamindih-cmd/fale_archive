import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../models/attached_file.dart';

class InAppDocumentViewer extends StatefulWidget {
  final AttachedFile file;
  const InAppDocumentViewer({super.key, required this.file});

  /// Méthode statique pour ouvrir facilement le visualiseur
  static void show(BuildContext context, AttachedFile file) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => InAppDocumentViewer(file: file),
    );
  }

  @override
  State<InAppDocumentViewer> createState() => _InAppDocumentViewerState();
}

class _InAppDocumentViewerState extends State<InAppDocumentViewer> {
  final TransformationController _transformController = TransformationController();
  double _scale = 1.0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() => _scale = 1.0);
  }

  void _zoomIn() {
    setState(() {
      _scale = (_scale + 0.5).clamp(1.0, 4.0);
      _transformController.value = Matrix4.diagonal3Values(_scale, _scale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale - 0.5).clamp(1.0, 4.0);
      _transformController.value = Matrix4.diagonal3Values(_scale, _scale, 1.0);
    });
  }

  Future<void> _printOrShare() async {
    if (widget.file.bytes != null && widget.file.bytes!.isNotEmpty) {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(widget.file.bytes!),
        filename: widget.file.name,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impression/partage du fichier "${widget.file.name}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${file.extension.toUpperCase()} • ${file.formattedSize}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (file.isImage) ...[
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded),
                      onPressed: _zoomIn,
                      tooltip: 'Zoom avant',
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded),
                      onPressed: _zoomOut,
                      tooltip: 'Zoom arrière',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _resetZoom,
                      tooltip: 'Réinitialiser',
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: _printOrShare,
                    tooltip: 'Partager / Imprimer',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),

            // Viewer Content
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  child: Center(
                    child: _buildContent(file, isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AttachedFile file, bool isDark) {
    if (file.isImage && file.bytes != null && file.bytes!.isNotEmpty) {
      return InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.8,
        maxScale: 4.0,
        child: Image.memory(
          Uint8List.fromList(file.bytes!),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackCard(file, isDark),
        ),
      );
    }

    if (file.isImage) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_rounded, size: 72, color: Color(0xFF2563EB)),
            const SizedBox(height: 16),
            Text(
              'Aperçu de l\'image scannée',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              file.name,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return _buildFallbackCard(file, isDark);
  }

  Widget _buildFallbackCard(AttachedFile file, bool isDark) {
    final isPdf = file.isPdf;
    final color = isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(32),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              size: 48,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            file.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Document ${file.extension.toUpperCase()} • ${file.formattedSize}',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ouvrir / Exporter'),
            onPressed: _printOrShare,
          ),
        ],
      ),
    );
  }
}
