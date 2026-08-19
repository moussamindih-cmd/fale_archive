import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentItem document;

  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  int _currentPage = 1;
  late int _totalPages;
  double _zoomScale = 1.0;
  double _rotationAngle = 0.0;
  bool _isFullScreen = false;
  bool _isLoadingPage = false;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    // Simulation dynamique du nombre de pages selon la taille et le type du document
    _totalPages = (widget.document.fileSizeMB * 2.5).ceil().clamp(1, 45);
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomScale = (_zoomScale + 0.25).clamp(0.5, 4.0);
      _transformCtrl.value = Matrix4.diagonal3Values(_zoomScale, _zoomScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = (_zoomScale - 0.25).clamp(0.5, 4.0);
      _transformCtrl.value = Matrix4.diagonal3Values(_zoomScale, _zoomScale, 1.0);
    });
  }

  void _rotate() {
    setState(() => _rotationAngle = (_rotationAngle + 90) % 360);
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _isLoadingPage = true;
      _currentPage = page;
    });

    // Simule la libération/chargement mémoire des buffers de page haute définition
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isLoadingPage = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text('Visionneuse GED PDF — ${doc.fileName}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Zoom avant',
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Zoom arrière',
                  onPressed: _zoomOut,
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_right),
                  tooltip: 'Pivoter 90°',
                  onPressed: _rotate,
                ),
                IconButton(
                  icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                  tooltip: 'Plein écran',
                  onPressed: () {
                    setState(() => _isFullScreen = !_isFullScreen);
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          // Toolbar Sub-header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      tooltip: 'Première page',
                      onPressed: _currentPage > 1 ? () => _changePage(1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Page précédente',
                      onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $_currentPage / $_totalPages',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Page suivante',
                      onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      tooltip: 'Dernière page',
                      onPressed: _currentPage < _totalPages ? () => _changePage(_totalPages) : null,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Rendu Vectoriel PDF • ${(_zoomScale * 100).toInt()}% • Rotation ${_rotationAngle.toInt()}°',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentTeal),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Télécharger'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Téléchargement sécurisé de ${doc.fileName} en cours...'),
                            backgroundColor: AppColors.accentEmerald,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Interactive Viewport Canvas
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF090D16) : const Color(0xFFE2E8F0),
              child: Center(
                child: _isLoadingPage
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Rendu haute résolution de la page...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      )
                    : InteractiveViewer(
                        transformationController: _transformCtrl,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Transform.rotate(
                            angle: _rotationAngle * (3.141592653589793 / 180),
                            child: Container(
                              width: 610,
                              constraints: const BoxConstraints(minHeight: 820),
                              padding: const EdgeInsets.all(42),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 18,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Filigrane Securise
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'FALE ARCHIVES GED — COPIE CERTIFIÉE CONFORME',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'PAGE $_currentPage / $_totalPages',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Divider(thickness: 2, color: Colors.blue.shade700),
                                  const SizedBox(height: 20),

                                  // Document Title & Metadata Header
                                  Text(
                                    doc.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.blue.shade50,
                                        label: Text(
                                          'Réf: ${doc.reference}',
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.grey.shade100,
                                        label: Text(
                                          'Confidentialité: ${doc.confidentiality.label}',
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Simulated Vectorial Document Page Body
                                  Text(
                                    'CONTENU OFFICIEL PAGE $_currentPage',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    doc.description,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Extrait numérisé et certifié de la section $_currentPage :\n'
                                    '• Conformité légale d archivage respectée selon les normes ISO 15489.\n'
                                    '• Intégrité numérique garantie par empreinte cryptographique SHA-256.\n'
                                    '• Historique d accès et d audit enregistré sous le contrôle du SecurityManager.',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.6),
                                  ),
                                  const SizedBox(height: 30),

                                  // Simulated Structured Form / Content Page Details
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Métadonnées de versement (Page $_currentPage):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 6),
                                        Text('• Déposant: ${doc.createdByName}', style: const TextStyle(fontSize: 11)),
                                        Text('• Date de création: ${doc.createdAt.day}/${doc.createdAt.month}/${doc.createdAt.year}', style: const TextStyle(fontSize: 11)),
                                        Text('• Version document: v${doc.version}', style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 60),

                                  // Stamp & Digital Signature Footer
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Cachet d Horodatage Légale', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.blue.shade700, width: 2),
                                              borderRadius: BorderRadius.circular(40),
                                            ),
                                            child: Text(
                                              'FALE GED CERTIFIÉ\n${doc.createdAt.year}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Signature Numérique Certifiée', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          const SizedBox(height: 8),
                                          Text(
                                            doc.createdByName,
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            'Clé publique: 0x${doc.id.hashCode.toRadixString(16).toUpperCase()}',
                                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
