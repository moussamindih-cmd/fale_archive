import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/attached_file.dart';
import '../models/daily_archive.dart';
import '../theme/app_theme.dart';
import '../screens/archive_viewer.dart';
import '../services/supabase_service.dart';
import '../services/archive_label_service.dart';

/// Widget réutilisable pour afficher un aperçu de document attaché.
class DocumentPreview extends StatelessWidget {
  final AttachedFile file;
  final VoidCallback? onRemove;
  final bool compact;

  const DocumentPreview({
    super.key,
    required this.file,
    this.onRemove,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconData = iconForExt(file.extension);
    final color = colorForExt(file.extension);

    if (compact) {
      return GestureDetector(
        onTap: () => _openViewer(context),
        child: _buildCompactChip(iconData, color, isDark),
      );
    }
    return _buildFullCard(context, iconData, color, isDark);
  }

  /// Ouvre l'aperçu du fichier, en téléchargeant ses octets à la demande
  /// s'il n'a pas encore été chargé en mémoire (cas d'un fichier persisté
  /// côté serveur, rechargé sans ses données brutes).
  Future<void> _openViewer(BuildContext context) async {
    var toShow = file;
    if (toShow.bytes == null && toShow.storagePath != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final bytes = await SupabaseService.instance.downloadDocument(
        toShow.storagePath!,
      );
      if (!context.mounted) return;
      Navigator.pop(context); // Ferme l'indicateur de chargement
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger le document.')),
        );
        return;
      }
      toShow = toShow.copyWith(bytes: bytes);
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveViewer(file: toShow, heroTag: toShow.name),
      ),
    );
  }

  Widget _buildCompactChip(IconData iconData, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
          ),
          if (file.isScanned) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.document_scanner_rounded,
              size: 10,
              color: Color(0xFF0D9488),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullCard(
    BuildContext context,
    IconData iconData,
    Color color,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceSubtle : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openViewer(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: color, size: 20),
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
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.fileType,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
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
                          if (file.isScanned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0D9488,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.document_scanner_rounded,
                                    size: 10,
                                    color: Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Scanné',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                    tooltip: 'Supprimer',
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData iconForExt(String ext) {
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

  static Color colorForExt(String ext) {
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
}

/// Feuille modale de détail et d'aperçu pour une archive quotidienne
class DocumentPreviewSheet extends StatelessWidget {
  final DailyArchive arc;

  const DocumentPreviewSheet({super.key, required this.arc});

  static void show(BuildContext context, {required DailyArchive arc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentPreviewSheet(arc: arc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = jobColor(arc.jobTitle);
    final dateStr = DateFormat('dd MMMM yyyy', 'fr_FR').format(arc.archiveDate);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? kDarkBorder : kBorderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(jobIcon(arc.jobTitle), color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arc.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      Text(
                        '${arc.employeeName} • $dateStr',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? kDarkBorder : kBorderColor),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (arc.summary.isNotEmpty) ...[
                    Text(
                      'Résumé & Observations',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? kDarkCard : kSurfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? kDarkBorder : kBorderColor,
                        ),
                      ),
                      child: Text(
                        arc.summary,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (arc.physicalLocation.isNotEmpty) ...[
                    Text(
                      'Emplacement Physique',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          arc.physicalLocation,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    'Code QR de l\'archive',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCard : kSurfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? kDarkBorder : kBorderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: ArchiveLabelService.qrPayloadFor(arc.id),
                            size: 72,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                arc.reference,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? kDarkTextPrimary
                                      : kTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'À coller sur le rangement physique pour retrouver ce dossier en un scan.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark ? kDarkTextMuted : kTextMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    ArchiveLabelService.printLabel(arc),
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 16,
                                ),
                                label: const Text('Imprimer l\'étiquette'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  textStyle: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Pièces jointes (${arc.files.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (arc.files.isEmpty)
                    Text(
                      'Aucun fichier joint à cette archive.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    )
                  else
                    ...arc.files.map((file) => DocumentPreview(file: file)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
