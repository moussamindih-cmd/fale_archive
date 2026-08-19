import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/attached_file.dart';
import '../theme/app_theme.dart';
import '../theme/glassmorphism.dart';

class ArchiveViewer extends StatefulWidget {
  final AttachedFile file;
  final String heroTag;

  const ArchiveViewer({super.key, required this.file, required this.heroTag});

  @override
  State<ArchiveViewer> createState() => _ArchiveViewerState();
}

class _ArchiveViewerState extends State<ArchiveViewer> {
  bool _isOcrScanning = false;
  String? _ocrResult;

  void _runOCR() async {
    setState(() => _isOcrScanning = true);
    // Simulate AI scan
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isOcrScanning = false;
        _ocrResult = "Texte extrait par l'IA :\n\n- Facture N° 4029\n- Montant : 450,00 €\n- Date : 19/08/2026\n\nCe document a été analysé avec succès par FALE AI Vision.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.file.isImage;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Viewer
          Positioned.fill(
            child: Hero(
              tag: widget.heroTag,
              child: isImage && widget.file.bytes != null
                  ? PhotoView(
                      imageProvider: MemoryImage(Uint8List.fromList(widget.file.bytes!)),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                      backgroundDecoration: const BoxDecoration(color: Colors.black),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 80, color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Aperçu non disponible pour ${widget.file.name}',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // OCR Scan Overlay
          if (_isOcrScanning)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: kAccentColor),
                      const SizedBox(height: 16),
                      Text(
                        'Analyse IA en cours...',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ).animate().fade().scale(),
                    ],
                  ),
                ),
              ),
            ),

          // OCR Result Drawer
          if (_ocrResult != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: GlassContainer(
                color: const Color(0x66000000),
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: kAccentColor),
                            const SizedBox(width: 8),
                            Text('FALE AI Vision', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _ocrResult = null),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _ocrResult!,
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 1.0, end: 0.0, curve: Curves.easeOutBack),
            ),

          // App Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassContainer(
              color: const Color(0x33000000),
              borderRadius: 0,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.file.name,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isImage && !_isOcrScanning && _ocrResult == null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _runOCR,
                      icon: const Icon(Icons.document_scanner_rounded, size: 16),
                      label: const Text('Scanner (IA)'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
