import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/daily_archive.dart';

/// Pont entre une archive physique (carton, classeur...) et son dossier
/// numérique : génère un code QR pointant vers l'archive et une étiquette
/// imprimable à coller sur le rangement physique.
class ArchiveLabelService {
  static const _scheme = 'falearchive://archive/';

  /// Contenu encodé dans le QR code d'une archive.
  static String qrPayloadFor(String archiveId) => '$_scheme$archiveId';

  /// Extrait l'identifiant d'archive d'un contenu scanné ou saisi
  /// manuellement (accepte le payload complet ou l'identifiant brut).
  static String parseArchiveId(String scanned) {
    final trimmed = scanned.trim();
    return trimmed.startsWith(_scheme)
        ? trimmed.substring(_scheme.length)
        : trimmed;
  }

  /// Génère et ouvre l'aperçu d'impression d'une étiquette au format
  /// carte (code QR + référence + titre + emplacement physique).
  static Future<void> printLabel(DailyArchive archive) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          226.77,
          340.16,
          marginAll: 16,
        ), // ~8x12 cm
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'FALE Archives',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.BarcodeWidget(
                data: qrPayloadFor(archive.id),
                barcode: Barcode.qrCode(),
                width: 160,
                height: 160,
                drawText: false,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                archive.reference,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                archive.title,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 11),
              ),
              if (archive.physicalLocation.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  archive.physicalLocation,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
