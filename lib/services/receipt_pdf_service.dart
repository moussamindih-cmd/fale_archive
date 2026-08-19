import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/subscription.dart';

class ReceiptPdfService {
  static Future<Uint8List> generateReceiptPdf({
    required SubscriptionTransaction transaction,
    required String organizationName,
    String? organizationAddress,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.outfitRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');
    final invoiceNumber = 'INV-${transaction.createdAt.year}${transaction.createdAt.month.toString().padLeft(2, '0')}-${transaction.id.substring(0, 8).toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── En-tête officiel ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FALE ARCHIVES',
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0F172A'))),
                      pw.SizedBox(height: 4),
                      pw.Text('Plateforme SaaS de GED & GAE Multi-Tenant',
                          style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                      pw.Text('N\'Djaména, République du Tchad',
                          style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#2563EB'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Text('REÇU DE PAIEMENT',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1.5),
              pw.SizedBox(height: 16),

              // ── Informations Client & Transaction ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FACTURE DESTINÉE À :',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#64748B'))),
                      pw.SizedBox(height: 6),
                      pw.Text(organizationName,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (organizationAddress != null)
                        pw.Text(organizationAddress, style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('N° Téléphone : +235 ${transaction.phoneNumber}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Réf. Facture : $invoiceNumber',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Date : ${dateFormat.format(transaction.createdAt)}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Opérateur : ${transaction.operator.label}',
                          style: const pw.TextStyle(fontSize: 10)),
                      if (transaction.transactionReference != null)
                        pw.Text('Réf. CinetPay : ${transaction.transactionReference}',
                            style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // ── Tableau des prestations ──
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text('DÉSIGNATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text('PÉRIODE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text('MONTANT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Abonnement FALE ARCHIVES - Formule ${transaction.planName}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            pw.SizedBox(height: 4),
                            pw.Text('Accès complet aux modules GED/GAE conformément à la formule souscrite.',
                                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          transaction.expiresAt != null
                              ? '30 jours (Expire le ${DateFormat('dd/MM/yyyy').format(transaction.expiresAt!)})'
                              : '30 jours',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          '${transaction.amount.toStringAsFixed(0)} ${transaction.currency}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // ── Total ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F1F5F9'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL PAYÉ :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('${transaction.amount.toStringAsFixed(0)} ${transaction.currency}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#2563EB'))),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── Bas de page & Badge de paiement ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Statut : PAIEMENT CONFIRMÉ & VALIDÉ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColor.fromHex('#10B981'))),
                      pw.SizedBox(height: 2),
                      pw.Text('Ce document fait office de quittance et de facture officielle.',
                          style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8'))),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'FALE-ARCHIVES-VERIF:$invoiceNumber:${transaction.amount}:${transaction.operator.name}',
                    width: 50,
                    height: 50,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printOrShareReceipt({
    required SubscriptionTransaction transaction,
    required String organizationName,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      transaction: transaction,
      organizationName: organizationName,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'recu_abonnement_${transaction.id.substring(0, 8)}.pdf',
    );
  }
}
