import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'dashboard_kit.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GRAPHIQUES DE TABLEAU DE BORD
// Barres interactives, courbe de tendance et sparkline, alimentées par les
// séries temporelles exposées par les states (archivesPerDay, itemsPerDay…).
// ═══════════════════════════════════════════════════════════════════════════════

/// Libellés courts des [days] derniers jours (« lun. », « mar. »…),
/// alignés sur les séries `...PerDay` des states.
List<String> lastDaysLabels(int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(days, (i) {
    final day = today.subtract(Duration(days: days - 1 - i));
    return DateFormat('E', 'fr_FR').format(day);
  });
}

/// Dates des [days] derniers jours, pour les infobulles.
List<DateTime> lastDays(int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(
    days,
    (i) => today.subtract(Duration(days: days - 1 - i)),
  );
}

// ─── Graphique à barres interactif ───────────────────────────────────────────

/// Barres grises au repos, barre sélectionnée en couleur d'accent et infobulle
/// sombre au survol — la sélection suit le pointeur et retombe sur le jour
/// courant. Reprend le comportement du bloc « Monthly Revenue » de la maquette.
class ActivityBarChart extends StatefulWidget {
  final List<int> values;
  final List<String> labels;
  final List<DateTime>? dates;
  final Color accent;
  final String unitSingular;
  final String unitPlural;

  const ActivityBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.dates,
    this.accent = kPrimaryColor,
    this.unitSingular = 'archive',
    this.unitPlural = 'archives',
  });

  @override
  State<ActivityBarChart> createState() => _ActivityBarChartState();
}

class _ActivityBarChartState extends State<ActivityBarChart> {
  /// Index survolé ; null = aucun, la dernière barre reste mise en avant.
  int? _touchedIndex;

  int get _highlighted => _touchedIndex ?? widget.values.length - 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = widget.values.isEmpty
        ? 0
        : widget.values.reduce((a, b) => a > b ? a : b);
    // Marge haute pour que la barre maximale ne touche pas le bord.
    final maxY = (maxValue == 0 ? 1 : maxValue) * 1.35;

    final highlightedValue = widget.values.isEmpty
        ? 0
        : widget.values[_highlighted.clamp(0, widget.values.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Valeur mise en avant, façon « $15,000 » de la maquette
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedCounter(
              value: highlightedValue,
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                highlightedValue > 1 ? widget.unitPlural : widget.unitSingular,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
              ),
            ),
            const Spacer(),
            if (widget.dates != null &&
                _highlighted >= 0 &&
                _highlighted < widget.dates!.length)
              Text(
                DateFormat(
                  'd MMM',
                  'fr_FR',
                ).format(widget.dates![_highlighted]),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 170,
          child: BarChart(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            BarChartData(
              maxY: maxY.toDouble(),
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        event.isInterestedForInteractions &&
                            response?.spot != null
                        ? response!.spot!.touchedBarGroupIndex
                        : null;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      isDark ? kDarkSurfaceSubtle : kTextPrimary,
                  tooltipBorderRadius: BorderRadius.circular(10),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final count = rod.toY.round();
                    return BarTooltipItem(
                      '$count ${count > 1 ? widget.unitPlural : widget.unitSingular}',
                      GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= widget.labels.length) {
                        return const SizedBox.shrink();
                      }
                      final isActive = i == _highlighted;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.labels[i],
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? widget.accent
                                : (isDark ? kDarkTextMuted : kTextMuted),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(widget.values.length, (i) {
                final isActive = i == _highlighted;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: widget.values[i].toDouble(),
                      width: 26,
                      borderRadius: BorderRadius.circular(8),
                      color: isActive
                          ? widget.accent
                          : (isDark ? kDarkSurfaceSubtle : kSurfaceSubtle),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY.toDouble(),
                        color: isDark
                            ? kDarkSurfaceSubtle.withValues(alpha: 0.45)
                            : kSurfaceSubtle.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Courbe de tendance ──────────────────────────────────────────────────────

/// Courbe lissée avec aire dégradée et infobulle au survol.
class TrendLineChart extends StatelessWidget {
  final List<int> values;
  final List<DateTime>? dates;
  final Color accent;
  final double height;

  const TrendLineChart({
    super.key,
    required this.values,
    this.dates,
    this.accent = kPrimaryColor,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: LineChart(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        LineChartData(
          minY: 0,
          maxY: ((maxValue == 0 ? 1 : maxValue) * 1.3).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((maxValue == 0 ? 1 : maxValue) / 2)
                .ceilToDouble(),
            getDrawingHorizontalLine: (_) => FlLine(
              color: isDark ? kDarkBorder : kBorderSubtle,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: values.length <= 10
                    ? 1
                    : (values.length / 6).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (dates == null || i < 0 || i >= dates!.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('d/M').format(dates![i]),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? kDarkTextMuted : kTextMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? kDarkSurfaceSubtle : kTextPrimary,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItems: (spots) => spots.map((s) {
                final label = dates != null && s.spotIndex < dates!.length
                    ? DateFormat('d MMM', 'fr_FR').format(dates![s.spotIndex])
                    : '';
                return LineTooltipItem(
                  '${s.y.round()}${label.isEmpty ? '' : '\n$label'}',
                  GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
              isCurved: true,
              curveSmoothness: 0.3,
              barWidth: 3,
              color: accent,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3.5,
                      color: isDark ? kDarkCard : kSurface,
                      strokeWidth: 2.5,
                      strokeColor: accent,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.28),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
