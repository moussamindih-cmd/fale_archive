import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/daily_archive.dart';
import '../../models/logistics_item.dart';
import '../../models/candidate.dart';
import '../../services/report_export_service.dart';
import '../../state/app_state.dart';
import '../../state/candidates_state.dart';
import '../../state/logistics_state.dart';
import '../../theme/app_theme.dart';

enum ReportType {
  archives('Archives Journalières', 'Bordereau officiel de versement et conformité documentaire', Icons.folder_open_rounded, Color(0xFF2563EB)),
  logistics('Logistique & Dépenses', 'Synthèse des factures, justificatifs et statuts de validation', Icons.receipt_long_rounded, Color(0xFF8B5CF6)),
  candidates('Vivier Candidats RH', 'Récapitulatif des candidatures, qualifications et étapes de recrutement', Icons.people_alt_rounded, Color(0xFFEC4899));

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const ReportType(this.title, this.description, this.icon, this.color);
}

class ReportsScreen extends StatefulWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;

  const ReportsScreen({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportType _selectedType = ReportType.archives;
  int _selectedPeriodDays = 30;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.appState.currentEmployee?.fullName ?? 'Utilisateur';

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        title: Text(
          'Rapports & Exports GED',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Génération de Rapports Certifiés',
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Exportez et imprimez les récapitulatifs au format PDF ou CSV.',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1 : Choisir le type de rapport
              Text(
                '1. Sélectionnez le type de rapport',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: ReportType.values.map((type) {
                  final selected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = type),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? (isDark ? type.color.withValues(alpha: 0.15) : type.color.withValues(alpha: 0.08))
                              : (isDark ? kDarkCard : kSurface),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? type.color : (isDark ? kDarkBorder : kBorderColor),
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected ? [BoxShadow(color: type.color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))] : (isDark ? null : kSoftShadow),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: type.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(type.icon, color: type.color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type.title,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    type.description,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: selected ? type.color : (isDark ? kDarkTextMuted : kTextMuted),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Section 2 : Période
              Text(
                '2. Période couverte',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPeriodChip('Aujourd\'hui', 1, isDark),
                  _buildPeriodChip('7 derniers jours', 7, isDark),
                  _buildPeriodChip('Ce mois-ci (30 j)', 30, isDark),
                  _buildPeriodChip('Historique complet', 0, isDark),
                ],
              ),
              const SizedBox(height: 32),

              // Section 3 : Actions
              Text(
                '3. Générer le document',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedType.color.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: _isGenerating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print_rounded, size: 20),
                        label: Text(_isGenerating ? 'Génération...' : 'Imprimer / Aperçu PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType.color,
                        ),
                        onPressed: _isGenerating ? null : () => _generatePdf(userName),
                      ),
                    ),
                  ),
                  if (_selectedType != ReportType.candidates) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                      label: const Text('Export CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _exportCsv,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, int days, bool isDark) {
    final selected = _selectedPeriodDays == days;
    final accent = isDark ? kPrimaryLight : kPrimaryColor;

    return InkWell(
      onTap: () => setState(() => _selectedPeriodDays = days),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : (isDark ? kDarkCard : kSurface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accent : (isDark ? kDarkBorder : kBorderColor)),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]
              : (isDark ? null : kSoftShadow),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : (isDark ? kDarkTextPrimary : kTextPrimary),
          ),
        ),
      ),
    );
  }

  DateTime? get _startDate {
    if (_selectedPeriodDays == 0) return null;
    return DateTime.now().subtract(Duration(days: _selectedPeriodDays));
  }

  Future<void> _generatePdf(String userName) async {
    setState(() => _isGenerating = true);
    try {
      final startDate = _startDate;
      final endDate = DateTime.now();

      switch (_selectedType) {
        case ReportType.archives: {
          List<DailyArchive> list = widget.appState.archives;
          if (startDate != null) {
            list = list.where((a) => a.archiveDate.isAfter(startDate)).toList();
          }
          final pdfBytes = await ReportExportService.generateArchivesReportPdf(
            archives: list,
            generatedBy: userName,
            startDate: startDate,
            endDate: endDate,
          );
          await Printing.layoutPdf(
            onLayout: (_) => pdfBytes,
            name: 'Bordereau_Archives_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          );
          break;
        }

        case ReportType.logistics: {
          List<LogisticsItem> list = widget.logisticsState.items;
          if (startDate != null) {
            list = list.where((i) => i.issueDate.isAfter(startDate)).toList();
          }
          final pdfBytes = await ReportExportService.generateLogisticsReportPdf(
            items: list,
            generatedBy: userName,
            startDate: startDate,
            endDate: endDate,
          );
          await Printing.layoutPdf(
            onLayout: (_) => pdfBytes,
            name: 'Rapport_Logistique_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          );
          break;
        }

        case ReportType.candidates: {
          List<Candidate> list = widget.candidatesState.candidates;
          final pdfBytes = await ReportExportService.generateCandidatesReportPdf(
            candidates: list,
            generatedBy: userName,
          );
          await Printing.layoutPdf(
            onLayout: (_) => pdfBytes,
            name: 'Vivier_Candidats_RH_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          );
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _exportCsv() {
    String csvData = '';
    String filename = '';

    if (_selectedType == ReportType.archives) {
      csvData = ReportExportService.generateArchivesCsv(widget.appState.archives);
      filename = 'export_archives.csv';
    } else if (_selectedType == ReportType.logistics) {
      csvData = ReportExportService.generateLogisticsCsv(widget.logisticsState.items);
      filename = 'export_logistique.csv';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export CSV ($filename)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              csvData,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Données CSV prêtes ($filename).'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copier / Confirmer'),
          ),
        ],
      ),
    );
  }
}
