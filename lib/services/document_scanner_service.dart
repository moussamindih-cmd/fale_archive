import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/attached_file.dart';

/// Service transverse de scan et d'import de documents physiques.
/// Utilisable depuis : soumission d'archive, fiche candidat, fiche logistique.
///
/// Sur mobile (Android/iOS) : idéalement connecté à cunning_document_scanner.
/// Sur web/desktop : fallback vers file_picker (sélection d'images/PDF).
class DocumentScannerService {
  static final DocumentScannerService _instance =
      DocumentScannerService._internal();
  factory DocumentScannerService() => _instance;
  DocumentScannerService._internal();

  /// Lance le flux de scan / import et retourne les fichiers obtenus
  /// (déjà filtrés : les fichiers refusés par [AttachedFile.validationError]
  /// sont exclus et signalés via une SnackBar).
  ///
  /// [context] : BuildContext pour afficher les dialogues.
  /// [allowMultiple] : si true, l'utilisateur peut importer plusieurs fichiers.
  Future<List<AttachedFile>> scanOrImportDocument(
    BuildContext context, {
    bool allowMultiple = true,
  }) async {
    // Afficher le choix : Scanner / Importer depuis fichiers
    final choice = await _showSourceDialog(context);
    if (choice == null) return [];
    if (!context.mounted) return [];

    final picked = switch (choice) {
      _ScanSource.camera => await _scanWithCamera(
        context,
        allowMultiple: allowMultiple,
      ),
      _ScanSource.filePicker => await _importFromFilePicker(
        allowMultiple: allowMultiple,
      ),
    };

    if (!context.mounted) return picked.where((f) => f.isValid).toList();
    return _validate(context, picked);
  }

  /// Sépare les fichiers valides des rejetés et affiche une SnackBar
  /// listant les rejets (taille ou type non autorisé).
  List<AttachedFile> _validate(BuildContext context, List<AttachedFile> files) {
    final rejected = files.where((f) => !f.isValid).toList();
    if (rejected.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rejected.map((f) => f.validationError).join('\n')),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return files.where((f) => f.isValid).toList();
  }

  /// Tentative de scan caméra.
  /// NOTE: Intégration avec cunning_document_scanner possible ici.
  /// En l'absence du plugin natif, on affiche un dialogue informatif
  /// et on redirige vers le sélecteur de fichiers.
  Future<List<AttachedFile>> _scanWithCamera(
    BuildContext context, {
    bool allowMultiple = true,
  }) async {
    // Pour la version démo, on montre un message et on utilise file_picker
    // En production : remplacer par cunning_document_scanner
    if (context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scanner un document'),
          content: const Text(
            'Le scan caméra nécessite un appareil physique.\n\n'
            'Sur ce simulateur, sélectionnez une image depuis vos fichiers pour simuler un scan.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sélectionner une image'),
            ),
          ],
        ),
      );
      if (proceed != true) return [];
    }
    return _importFromFilePicker(allowMultiple: allowMultiple, imageOnly: true);
  }

  /// Import classique via file_picker
  Future<List<AttachedFile>> _importFromFilePicker({
    bool allowMultiple = true,
    bool imageOnly = false,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: imageOnly ? FileType.image : FileType.custom,
        allowedExtensions: imageOnly ? null : AttachedFile.allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return [];
      return result.files
          .map(
            (f) => AttachedFile(
              name: f.name,
              extension: (f.extension ?? 'bin').toLowerCase(),
              sizeBytes: f.size,
              bytes: f.bytes,
              isScanned: imageOnly,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Dialogue de choix de la source
  Future<_ScanSource?> _showSourceDialog(BuildContext context) async {
    return showModalBottomSheet<_ScanSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ajouter un document',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _sourceOption(
                    context: ctx,
                    icon: Icons.document_scanner_rounded,
                    label: 'Scanner',
                    subtitle: 'Caméra du téléphone',
                    color: const Color(0xFF0D9488),
                    onTap: () => Navigator.pop(ctx, _ScanSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sourceOption(
                    context: ctx,
                    icon: Icons.upload_file_rounded,
                    label: 'Importer',
                    subtitle: 'PDF, Word, Images',
                    color: const Color(0xFF2563EB),
                    onTap: () => Navigator.pop(ctx, _ScanSource.filePicker),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ScanSource { camera, filePicker }
