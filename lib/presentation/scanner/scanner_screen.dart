import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/offline_queue_service.dart';
import '../../data/models/document.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class ScannerScreen extends StatefulWidget {
  final AppStateProvider appState;

  const ScannerScreen({super.key, required this.appState});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  int _scannedPagesCount = 1;
  String _selectedFilter = 'Amélioration OCR';
  bool _isCapturing = false;

  void _capturePage() {
    setState(() => _isCapturing = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final offlineService = OfflineQueueService();
      if (!offlineService.isOnline) {
        // Enregistre le scan dans la file d'attente hors-ligne
        final dummyDoc = DocumentItem(
          id: 'off_scan_${DateTime.now().millisecondsSinceEpoch}',
          organizationId: widget.appState.currentOrg.id,
          folderId: 'folder_general',
          folderName: 'Général',
          categoryId: 'cat_scans',
          categoryName: 'Scans Hors-Ligne',
          documentTypeId: 'type_pdf',
          documentTypeName: 'PDF Scanné',
          departmentId: widget.appState.currentUser.departmentId,
          departmentName: widget.appState.currentUser.departmentName,
          createdBy: widget.appState.currentUser.id,
          createdByName: widget.appState.currentUser.fullName,
          title: 'Scan hors-ligne de $_scannedPagesCount page(s)',
          reference: 'SCAN-OFFLINE-$_scannedPagesCount',
          description: 'Document numérisé en mode déconnecté',
          fileName: 'scan_offline_${DateTime.now().millisecondsSinceEpoch}.pdf',
          fileUrl: 'https://storage.fale-archives.sn/scans/offline.pdf',
          fileSizeMB: 1.2,
          mimeType: 'application/pdf',
          confidentiality: ConfidentialityLevel.internal,
          retentionStatus: RetentionStatus.active,
          retentionPeriodYears: 5,
          documentDate: DateTime.now(),
          expirationDate: DateTime.now().add(const Duration(days: 365 * 5)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          keywords: const ['scan', 'offline', 'mobile'],
          physicalLocationRef: 'Bâtiment A > Bureau 101',
        );
        offlineService.enqueueScan(dummyDoc);
      }

      setState(() {
        _isCapturing = false;
        _scannedPagesCount++;
      });

      final msg = offlineService.isOnline
          ? 'Page $_scannedPagesCount capturée et recadrée !'
          : 'Page $_scannedPagesCount stockée dans la file hors-ligne (Attente de réseau)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: offlineService.isOnline ? AppColors.accentEmerald : AppColors.accentAmber,
        ),
      );
    });
  }

  void _toggleNetwork() {
    final offlineService = OfflineQueueService();
    final newStatus = !offlineService.isOnline;
    offlineService.setOnlineStatus(newStatus, onSyncCompleted: (count) {
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Connexion rétablie ! $count document(s) scanné(s) synchronisé(s) avec la GED.'),
            backgroundColor: AppColors.accentEmerald,
          ),
        );
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final offlineService = OfflineQueueService();
    final isOnline = offlineService.isOnline;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scanner de documents multi-pages',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Numérisez vos documents papier via la caméra ou le scanner réseau.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  // Toggle Mode Hors-Ligne
                  ActionChip(
                    avatar: Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 16,
                      color: isOnline ? AppColors.accentEmerald : AppColors.accentCrimson,
                    ),
                    label: Text(
                      isOnline ? 'En ligne' : 'Hors-ligne (${offlineService.pendingCount} en attente)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? AppColors.accentEmerald : AppColors.accentCrimson,
                      ),
                    ),
                    onPressed: _toggleNetwork,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Finaliser le PDF ($_scannedPagesCount pages)',
                    icon: Icons.check,
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.addDocument);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Offline Queue Banner
          if (!isOnline) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.accentAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode déconnecté actif. Vos numérisations sont sauvegardées localement. Synchronisation automatique au retour du réseau.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main Viewfinder Simulation
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera grid lines & Document crop outline frame
                  Container(
                    width: 380,
                    height: 520,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isOnline ? AppColors.primaryLight : AppColors.accentAmber,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner Guides
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Icon(Icons.crop_free, color: isOnline ? AppColors.primaryLight : AppColors.accentAmber, size: 32),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.crop_free, color: isOnline ? AppColors.primaryLight : AppColors.accentAmber, size: 32),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Icon(Icons.crop_free, color: isOnline ? AppColors.primaryLight : AppColors.accentAmber, size: 32),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Icon(Icons.crop_free, color: isOnline ? AppColors.primaryLight : AppColors.accentAmber, size: 32),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.document_scanner, size: 64, color: Colors.white38),
                              const SizedBox(height: 16),
                              const Text(
                                'Alignez le document papier dans le cadre',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isOnline ? AppColors.primary : AppColors.accentAmber).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOnline
                                      ? 'Détection automatique des bords active'
                                      : 'Stockage local d attente actif',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Controls Bar Overlay
                  Positioned(
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.flash_auto, color: Colors.white),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: _capturePage,
                            child: Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isOnline ? AppColors.primary : AppColors.accentAmber,
                                  shape: BoxShape.circle,
                                ),
                                child: _isCapturing
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Icon(Icons.camera, color: Colors.white, size: 30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filters Bar Selection
          Row(
            children: [
              const Text('Filtre image: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              for (var f in ['Amélioration OCR', 'Noir & Blanc', 'Nuances de Gris', 'Original']) ...[
                ChoiceChip(
                  label: Text(f),
                  selected: _selectedFilter == f,
                  onSelected: (val) => setState(() => _selectedFilter = f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
