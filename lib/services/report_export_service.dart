import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/daily_archive.dart';
import '../models/logistics_item.dart';
import '../models/candidate.dart';

class ReportExportService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  static final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  /// Génère un rapport PDF officiel pour les archives journalières
  static Future<Uint8List> generateArchivesReportPdf({
    required List<DailyArchive> archives,
    required String generatedBy,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader('BORDEREAU RÉCAPITULATIF DES ARCHIVES JOURNALIÈRES'),
        footer: (context) => _buildFooter(context, generatedBy),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildMetaBlock([
            ('Date d\'émission', _dateFormat.format(DateTime.now())),
            ('Généré par', generatedBy),
            ('Période couverte', startDate != null && endDate != null
                ? '${_dateOnlyFormat.format(startDate)} au ${_dateOnlyFormat.format(endDate)}'
                : 'Toutes les archives (${archives.length} enregistrements)'),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Employé', 'Poste / Catégorie', 'Titre', 'Docs'],
            data: archives.map((a) => [
              _dateFormat.format(a.createdAt),
              a.employeeName,
              a.jobTitle,
              a.title,
              '${a.documentCount} doc(s)',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A8A)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildSummaryBox([
            'Total des versements : ${archives.length}',
            'Total des documents numérisés : ${archives.fold<int>(0, (sum, a) => sum + a.documentCount)}',
          ]),
        ],
      ),
    );

    return pdf.save();
  }

  /// Génère un rapport PDF pour le module logistique & dépenses
  static Future<Uint8List> generateLogisticsReportPdf({
    required List<LogisticsItem> items,
    required String generatedBy,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final totalAmount = items.fold<double>(0.0, (sum, item) => sum + (item.amount ?? 0.0));
    final validCount = items.where((i) => i.status == LogisticsStatus.valide).length;
    final pendingCount = items.where((i) => i.status == LogisticsStatus.enAttente).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader('ÉTAT DE SYNTHÈSE LOGISTIQUE & FACTURES'),
        footer: (context) => _buildFooter(context, generatedBy),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildMetaBlock([
            ('Date d\'émission', _dateFormat.format(DateTime.now())),
            ('Généré par', generatedBy),
            ('Période couverte', startDate != null && endDate != null
                ? '${_dateOnlyFormat.format(startDate)} au ${_dateOnlyFormat.format(endDate)}'
                : 'Global (${items.length} pièces)'),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Type', 'Référence', 'Fournisseur / Bénéficiaire', 'Montant (FCFA)', 'Statut', 'Date'],
            data: items.map((i) => [
              i.documentType.label,
              i.reference,
              i.supplier,
              i.amount != null ? '${_currencyFormat.format(i.amount)} F' : '—',
              i.status.label,
              _dateOnlyFormat.format(i.issueDate),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7C3AED)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildSummaryBox([
            'Montant total cumulé : ${_currencyFormat.format(totalAmount)} FCFA',
            'Pièces validées : $validCount | En attente : $pendingCount | Rejetées : ${items.length - validCount - pendingCount}',
          ]),
        ],
      ),
    );

    return pdf.save();
  }

  /// Génère un rapport PDF pour le vivier de candidats RH
  static Future<Uint8List> generateCandidatesReportPdf({
    required List<Candidate> candidates,
    required String generatedBy,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader('FICHE RÉCAPITULATIVE DU VIVIER DE CANDIDATS RH'),
        footer: (context) => _buildFooter(context, generatedBy),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildMetaBlock([
            ('Date d\'émission', _dateFormat.format(DateTime.now())),
            ('Généré par', generatedBy),
            ('Effectif vivier', '${candidates.length} candidat(s)'),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Nom & Prénom', 'Poste visé', 'Contact', 'Email', 'Statut', 'Date dépot'],
            data: candidates.map((c) => [
              c.fullName,
              c.targetPosition,
              c.phone,
              c.email,
              c.status.label,
              _dateOnlyFormat.format(c.createdAt),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEC4899)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildSummaryBox([
            'Retenus : ${candidates.where((c) => c.status == CandidateStatus.retenu).length}',
            'En entretien : ${candidates.where((c) => c.status == CandidateStatus.enEntretien).length}',
            'En attente d\'évaluation : ${candidates.where((c) => c.status == CandidateStatus.enAttente).length}',
          ]),
        ],
      ),
    );

    return pdf.save();
  }

  /// Aperçu et impression directe / partage
  static Future<void> previewOrPrintPdf(
    Uint8List pdfBytes, {
    required String docName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: docName,
    );
  }

  /// Génération CSV pour la logistique
  static String generateLogisticsCsv(List<LogisticsItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('Type;Reference;Fournisseur;Montant_FCFA;Statut;Date_Emission;Enregistre_Par;Validateur');
    for (final i in items) {
      buffer.writeln(
        '${i.documentType.label};"${i.reference}";"${i.supplier}";${i.amount ?? 0};${i.status.label};${DateFormat('yyyy-MM-dd').format(i.issueDate)};"${i.registeredByName}";"${i.validatedByName}"',
      );
    }
    return buffer.toString();
  }

  /// Génération CSV pour les archives
  static String generateArchivesCsv(List<DailyArchive> archives) {
    final buffer = StringBuffer();
    buffer.writeln('ID;Date_Creation;Employe;Poste;Titre;Resume;Nb_Documents');
    for (final a in archives) {
      buffer.writeln(
        '"${a.id}";${DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt)};"${a.employeeName}";"${a.jobTitle}";"${a.title.replaceAll('"', '""')}";"${a.summary.replaceAll('"', '""')}";${a.documentCount}',
      );
    }
    return buffer.toString();
  }

  // --- Composants de mise en page PDF ---

  static pw.Widget _buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF1E3A8A), width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('FALE ARCHIVES v2', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: const PdfColor.fromInt(0xFF1E3A8A))),
              pw.Text('Système de Gestion Électronique de Documents & Traçabilité', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: const PdfColor.fromInt(0xFF0F172A))),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, String user) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Document certifié conforme — FALE Archives', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaBlock(List<(String, String)> entries) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: entries.map((e) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(e.$1, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(e.$2, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
          ],
        )).toList(),
      ),
    );
  }

  static pw.Widget _buildSummaryBox(List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEFF6FF),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines.map((l) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text('• $l', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E40AF))),
        )).toList(),
      ),
    );
  }
}
