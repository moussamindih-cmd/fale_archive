import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/application.dart';
import '../../models/hr_metrics.dart';
import '../../services/download/file_saver.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Pilotage RH et archivage (§5.4.1 et §5.4.2).
///
/// Tous les chiffres viennent de vues SQL : rien n'est agrégé côté client,
/// donc rien ne dépend de ce qui a été chargé en mémoire.
class HrMetricsScreen extends StatefulWidget {
  const HrMetricsScreen({super.key});

  @override
  State<HrMetricsScreen> createState() => _HrMetricsScreenState();
}

class _HrMetricsScreenState extends State<HrMetricsScreen> {
  DashboardSummary? _summary;
  List<FunnelStep> _funnel = [];
  List<SourceMetric> _sources = [];
  List<TimeToHireMetric> _timeToHire = [];
  List<ArchiveVolumeMetric> _volume = [];
  RetentionCompliance _compliance = const RetentionCompliance.empty();

  bool _isLoading = true;
  String? _error;

  static final _monthFormat = DateFormat('MMMM yyyy', 'fr_FR');
  static final _stampFormat = DateFormat('yyyyMMdd-HHmm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = SupabaseService.instance;
      final results = await Future.wait([
        service.fetchDashboardSummary(),
        service.fetchFunnel(),
        service.fetchSourceMetrics(),
        service.fetchTimeToHire(),
        service.fetchArchiveVolume(),
        service.fetchRetentionCompliance(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as DashboardSummary;
        _funnel = results[1] as List<FunnelStep>;
        _sources = results[2] as List<SourceMetric>;
        _timeToHire = results[3] as List<TimeToHireMetric>;
        _volume = results[4] as List<ArchiveVolumeMetric>;
        _compliance = results[5] as RetentionCompliance;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Chargement des indicateurs impossible : $e';
        _isLoading = false;
      });
    }
  }

  /// Export CSV des indicateurs, avec BOM UTF-8 pour Excel francophone.
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final buffer = StringBuffer('\u{FEFF}');

    buffer.writeln('INDICATEURS DE RECRUTEMENT');
    buffer.writeln('Étape;Atteintes;Conversion (%)');
    for (final step in _funnel) {
      buffer.writeln('${_csv(step.stageLabel)};${step.reachedCount};'
          '${step.conversionRatePct?.toStringAsFixed(1) ?? ''}');
    }

    buffer.writeln();
    buffer.writeln('SOURCES DE CANDIDATURE');
    buffer.writeln('Source;Total;Recrutés;En cours;Taux de réussite (%)');
    for (final source in _sources) {
      buffer.writeln('${_csv(_sourceLabel(source.source))};${source.total};'
          '${source.hired};${source.inProgress};'
          '${source.successRatePct?.toStringAsFixed(1) ?? ''}');
    }

    buffer.writeln();
    buffer.writeln('DÉLAI DE RECRUTEMENT');
    buffer.writeln('Offre;Mois;Recrutements;Délai moyen (j);Min;Max');
    for (final metric in _timeToHire) {
      buffer.writeln('${_csv(metric.label)};'
          '${metric.month == null ? '' : _monthFormat.format(metric.month!)};'
          '${metric.hires};${metric.avgDays};${metric.minDays};${metric.maxDays}');
    }

    buffer.writeln();
    buffer.writeln('CONFORMITÉ DE CONSERVATION');
    buffer.writeln('Total;Conformes;Échéance proche;Échues;Sans règle;'
        'Gel conservatoire;Taux (%)');
    buffer.writeln('${_compliance.total};${_compliance.compliant};'
        '${_compliance.expiringSoon};${_compliance.expired};'
        '${_compliance.unclassified};${_compliance.legalHold};'
        '${_compliance.complianceRatePct?.toStringAsFixed(1) ?? ''}');

    try {
      final destination = await saveFile(
        bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
        fileName: 'indicateurs-${_stampFormat.format(DateTime.now())}.csv',
        mimeType: 'text/csv;charset=utf-8',
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Indicateurs exportés : $destination'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Échec de l\'export : $e'),
        backgroundColor: kDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  static String _csv(String value) {
    if (value.isEmpty) return '';
    final needsQuoting = value.contains(RegExp(r'[;"\n\r]'));
    final escaped = value.replaceAll('"', '""');
    return needsQuoting ? '"$escaped"' : escaped;
  }

  static String _sourceLabel(String code) =>
      ApplicationSource.fromCode(code).label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        title: const Text('Pilotage RH'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _load,
          ),
          IconButton(
            tooltip: 'Exporter les indicateurs',
            icon: const Icon(Icons.download_rounded),
            onPressed: _isLoading ? null : _export,
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: kDanger),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _summaryStrip(isDark),
          const SizedBox(height: 16),
          _funnelCard(isDark),
          const SizedBox(height: 16),
          _sourcesCard(isDark),
          const SizedBox(height: 16),
          _timeToHireCard(isDark),
          const SizedBox(height: 16),
          _complianceCard(isDark),
          const SizedBox(height: 16),
          _volumeCard(isDark),
        ],
      ),
    );
  }

  Widget _summaryStrip(bool isDark) {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpi('Candidatures en cours', s.openApplications.toString(), kInfo, isDark),
        _kpi('Recrutements cette année', s.hiresThisYear.toString(), kSuccess,
            isDark),
        _kpi(
          'Délai moyen',
          // Nul signifie « aucun recrutement abouti ». Afficher « 0 jour »
          // laisserait croire à un recrutement instantané.
          s.avgTimeToHire == null ? '—' : '${s.avgTimeToHire!.round()} j',
          kPrimaryColor,
          isDark,
        ),
        _kpi('Offres publiées', s.publishedOffers.toString(), kAccentColor,
            isDark),
        _kpi('Entretiens à venir', s.upcomingInterviews.toString(), kWarning,
            isDark),
        _kpi('Archives ce mois', s.archivesThisMonth.toString(), kInfo, isDark),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color, bool isDark) {
    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? kDarkTextSecondary : kTextSecondary)),
        ],
      ),
    );
  }

  Widget _funnelCard(bool isDark) {
    final steps = _funnel.where((s) => !s.isTerminal).toList();
    final terminal = _funnel.where((s) => s.isTerminal).toList();
    final maxCount = _funnel.fold<int>(
        1, (m, s) => s.reachedCount > m ? s.reachedCount : m);

    return _card(
      isDark,
      'Entonnoir de recrutement',
      'Candidatures ayant atteint chaque étape, d\'après l\'historique — '
          'et non celles qui s\'y trouvent aujourd\'hui.',
      Column(
        children: [
          for (final step in steps) _funnelRow(step, maxCount, isDark),
          if (terminal.isNotEmpty) ...[
            const Divider(height: 24),
            for (final step in terminal) _funnelRow(step, maxCount, isDark),
          ],
        ],
      ),
    );
  }

  Widget _funnelRow(FunnelStep step, int maxCount, bool isDark) {
    final ratio = maxCount == 0 ? 0.0 : step.reachedCount / maxCount;
    final color = step.isWon
        ? kSuccess
        : (step.isTerminal ? kDanger : kPrimaryColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(step.stageLabel,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? kDarkTextPrimary : kTextPrimary)),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        step.reachedCount.toString(),
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              step.conversionRatePct == null
                  ? '—'
                  : '${step.conversionRatePct!.toStringAsFixed(0)} %',
              textAlign: TextAlign.right,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourcesCard(bool isDark) {
    if (_sources.isEmpty) {
      return _card(isDark, 'Sources de candidature', null,
          _empty('Aucune candidature enregistrée.', isDark));
    }
    return _card(
      isDark,
      'Sources de candidature',
      'Le taux de réussite ne porte que sur les candidatures closes.',
      Column(
        children: [
          for (final source in _sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_sourceLabel(source.source),
                        style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  _tag('${source.total} reçues', kInfo),
                  const SizedBox(width: 6),
                  _tag('${source.hired} recrutés', kSuccess),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 54,
                    child: Text(
                      source.successRatePct == null
                          ? '—'
                          : '${source.successRatePct!.toStringAsFixed(0)} %',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.ibmPlexMono(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeToHireCard(bool isDark) {
    if (_timeToHire.isEmpty) {
      return _card(isDark, 'Délai de recrutement', null,
          _empty('Aucun recrutement abouti pour l\'instant.', isDark));
    }
    return _card(
      isDark,
      'Délai de recrutement',
      'De la réception de la candidature à l\'entrée en étape de succès.',
      Column(
        children: [
          for (final metric in _timeToHire)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metric.label,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        if (metric.month != null)
                          Text(_monthFormat.format(metric.month!),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? kDarkTextMuted : kTextMuted)),
                      ],
                    ),
                  ),
                  _tag('${metric.hires} recrut.', kSuccess),
                  const SizedBox(width: 8),
                  Text('${metric.avgDays.toStringAsFixed(0)} j',
                      style: GoogleFonts.ibmPlexMono(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: Text('${metric.minDays}–${metric.maxDays} j',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            color: isDark ? kDarkTextMuted : kTextMuted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _complianceCard(bool isDark) {
    final c = _compliance;
    if (c.total == 0) {
      return _card(isDark, 'Conformité de conservation', null,
          _empty('Aucune archive enregistrée.', isDark));
    }
    final rate = c.complianceRatePct ?? 0;
    final color = rate >= 90 ? kSuccess : (rate >= 70 ? kWarning : kDanger);

    return _card(
      isDark,
      'Conformité de conservation',
      'Une archive échue laissée en l\'état est comptée non conforme : '
          'c\'est ce que l\'indicateur doit faire remonter.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${rate.toStringAsFixed(1)} %',
                  style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 10,
                    color: color,
                    backgroundColor:
                        isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _tag('${c.compliant} conformes', kSuccess),
            if (c.expiringSoon > 0)
              _tag('${c.expiringSoon} échéance proche', kInfo),
            if (c.expired > 0) _tag('${c.expired} échues', kDanger),
            if (c.unclassified > 0)
              _tag('${c.unclassified} sans règle', kWarning),
            if (c.legalHold > 0) _tag('${c.legalHold} gel', kAccentColor),
            if (c.purged > 0) _tag('${c.purged} purgées', kTextMuted),
          ]),
          if (c.needsAttention > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${c.needsAttention} archive${c.needsAttention > 1 ? 's' : ''} '
              'demande${c.needsAttention > 1 ? 'nt' : ''} une décision : '
              'échue sans action, ou déposée sans règle de conservation.',
              style: GoogleFonts.inter(fontSize: 12, color: kWarning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _volumeCard(bool isDark) {
    if (_volume.isEmpty) {
      return _card(isDark, 'Volume archivé', null,
          _empty('Aucune archive enregistrée.', isDark));
    }
    return _card(
      isDark,
      'Volume archivé',
      null,
      Column(
        children: [
          for (final metric in _volume.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(_monthFormat.format(metric.month),
                        style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(metric.categoryLabel ?? '(sans catégorie)',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? kDarkTextSecondary
                                : kTextSecondary)),
                  ),
                  _tag('${metric.archiveCount} arch.', kInfo),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: Text(metric.readableSize,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.ibmPlexMono(fontSize: 11)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Fragments partagés ───────────────────────────────────────────────────

  Widget _card(bool isDark, String title, String? subtitle, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? kDarkTextPrimary : kTextPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.4,
                    color: isDark ? kDarkTextMuted : kTextMuted)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _empty(String message, bool isDark) => Text(message,
      style: GoogleFonts.inter(
          fontSize: 12, color: isDark ? kDarkTextMuted : kTextMuted));
}
