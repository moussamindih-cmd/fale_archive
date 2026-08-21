import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/action_history_entry.dart';
import '../models/daily_archive.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KIT DE COMPOSANTS DASHBOARD
// Briques partagées par les tableaux de bord Admin / Directeur / RH / Employé.
// ═══════════════════════════════════════════════════════════════════════════════

/// Seuil au-delà duquel les tableaux affichent leurs colonnes.
/// En dessous, ils basculent en cartes empilées.
const double kTableBreakpoint = 700;

/// Seuil au-delà duquel les blocs bas se placent côte à côte.
const double kSplitBreakpoint = 900;

// ─── Couleurs & icônes par type d'action ─────────────────────────────────────
const Map<String, Color> kActionColors = {
  'CREATE': kSuccess,
  'ARCHIVE_SUBMIT': kSuccess,
  'REGISTER': kSuccess,
  'UPDATE': kInfo,
  'STATUS_CHANGE': kInfo,
  'SCAN': kAccentColor,
  'VALIDATE': kSuccess,
  'REJECT': kDanger,
  'DELETE': kDanger,
  'ROLE_CHANGE': kWarning,
  'LOGIN': kPrimaryColor,
  'LOGOUT': kTextMuted,
};

const Map<String, IconData> kActionIcons = {
  'CREATE': Icons.add_circle_outline_rounded,
  'ARCHIVE_SUBMIT': Icons.inventory_2_outlined,
  'REGISTER': Icons.person_add_alt_outlined,
  'UPDATE': Icons.edit_outlined,
  'STATUS_CHANGE': Icons.swap_horiz_rounded,
  'SCAN': Icons.document_scanner_outlined,
  'VALIDATE': Icons.check_circle_outline_rounded,
  'REJECT': Icons.cancel_outlined,
  'DELETE': Icons.delete_outline_rounded,
  'ROLE_CHANGE': Icons.admin_panel_settings_outlined,
  'LOGIN': Icons.login_rounded,
  'LOGOUT': Icons.logout_rounded,
};

Color actionColor(String action) => kActionColors[action] ?? kPrimaryColor;
IconData actionIcon(String action) =>
    kActionIcons[action] ?? Icons.history_rounded;

/// Initiales d'un nom complet, pour les avatars de la timeline.
String initialsOf(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// Date lisible : « À l'instant », « Il y a 12 min », « Hier, 09:12 »…
String relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    return 'Aujourd\'hui, ${DateFormat('HH:mm').format(date)}';
  }
  if (diff.inDays == 1) return 'Hier, ${DateFormat('HH:mm').format(date)}';
  if (diff.inDays < 7) {
    final day = DateFormat('EEEE', 'fr_FR').format(date);
    return '${day[0].toUpperCase()}${day.substring(1)}, ${DateFormat('HH:mm').format(date)}';
  }
  return DateFormat('dd/MM/yyyy').format(date);
}

// ─── Briques animées ─────────────────────────────────────────────────────────

/// Nombre qui s'incrémente depuis 0 à l'affichage, puis anime chaque
/// changement de valeur.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(
        '$prefix${animated.round()}$suffix',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Badge de variation par rapport à une période de référence :
/// « +12 ↗ » en vert, « -3 ↘ » en rouge, « = » quand rien ne bouge.
class TrendBadge extends StatelessWidget {
  final int current;
  final int previous;

  /// Décrit la base de comparaison, affichée en infobulle.
  final String comparisonLabel;

  const TrendBadge({
    super.key,
    required this.current,
    required this.previous,
    this.comparisonLabel = 'vs période précédente',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final delta = current - previous;

    final Color color;
    final IconData icon;
    final String label;
    if (delta > 0) {
      color = kSuccess;
      icon = Icons.trending_up_rounded;
      label = '+$delta';
    } else if (delta < 0) {
      color = kDanger;
      icon = Icons.trending_down_rounded;
      label = '$delta';
    } else {
      color = isDark ? kDarkTextMuted : kTextMuted;
      icon = Icons.trending_flat_rounded;
      label = '=';
    }

    return Tooltip(
      message: comparisonLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Icon(icon, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}

/// Soulève son enfant au survol : légère translation vers le haut,
/// ombre plus marquée et curseur cliquable.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double offset;
  final bool enabled;

  const HoverLift({
    super.key,
    required this.child,
    this.offset = -4,
    this.enabled = true,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: Offset(0, _hovered ? widget.offset / 100 : 0),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          scale: _hovered ? 1.012 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Mini-courbe sans axes, destinée à tenir dans une carte d'indicateur.
class Sparkline extends StatelessWidget {
  final List<int> values;
  final Color color;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            color: color,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;
  final double progress;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue);
    final stepX = size.width / (values.length - 1);

    final line = Path();
    final area = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalized = (values[i] - minValue) / range;
      // Marge de 3 px en haut et en bas pour ne pas rogner le trait.
      final y = size.height - 3 - normalized * (size.height - 6);
      if (i == 0) {
        line.moveTo(x, y);
        area
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        line.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    area
      ..lineTo(size.width, size.height)
      ..close();

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height))
      ..drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      )
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color || old.progress != progress;
}

/// Décalage d'apparition en cascade du i-ème bloc d'un dashboard.
Duration staggerDelay(int index) => Duration(milliseconds: 70 * index);

extension DashboardEntrance on Widget {
  /// Fait entrer le bloc en fondu montant, décalé selon sa position [index]
  /// dans la page — les sections se révèlent l'une après l'autre.
  Widget animated(int index) {
    final delay = staggerDelay(index);
    return animate()
        .fadeIn(
          delay: delay,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: delay,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── Canvas ──────────────────────────────────────────────────────────────────

/// Fond plat du dashboard : contenu centré et borné en largeur, padding adapté.
class DashboardCanvas extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const DashboardCanvas({
    super.key,
    required this.children,
    this.maxWidth = 1280,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? kDarkBackground : kBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth < 600
              ? 16.0
              : constraints.maxWidth < kSplitBreakpoint
              ? 24.0
              : 32.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Deux blocs côte à côte au-delà de [kSplitBreakpoint], empilés en dessous.
class DashboardSplit extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double spacing;

  const DashboardSplit({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 4,
    this.rightFlex = 6,
    this.spacing = 20,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kSplitBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: spacing + 6),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            SizedBox(width: spacing),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

// ─── Carte générique ─────────────────────────────────────────────────────────

/// Conteneur unifié : surface, coins arrondis, bordure douce et ombre subtile.
class DashboardCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Réagit au survol : bordure teintée et ombre portée plus marquée.
  final bool hoverable;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.onTap,
    this.hoverable = true,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lifted = widget.hoverable && _hovered;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: lifted
              ? kPrimaryColor.withValues(alpha: isDark ? 0.5 : 0.35)
              : (isDark ? kDarkBorder : kBorderColor),
        ),
        boxShadow: lifted
            ? kHoverShadow
            : (isDark ? kDarkCardShadow : kSoftShadow),
      ),
      child: widget.child,
    );

    final interactive = widget.onTap == null
        ? card
        : InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.radius),
            child: card,
          );

    if (!widget.hoverable) return interactive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: HoverLift(offset: -3, child: interactive),
    );
  }
}

// ─── Titre de section ────────────────────────────────────────────────────────

/// Titre de section, avec compteur et action optionnels.
class DashboardSectionTitle extends StatelessWidget {
  final String title;
  final String? badge;
  final Widget? action;

  const DashboardSectionTitle({
    super.key,
    required this.title,
    this.badge,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ─── Indicateurs clés ────────────────────────────────────────────────────────

/// Un indicateur de la bande KPI.
///
/// [previous] active le badge de variation ; [spark] active la mini-courbe.
/// Les deux sont facultatifs : un indicateur sans historique exploitable
/// (l'effectif, par exemple) s'affiche simplement sans badge ni courbe.
class KpiData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final int? previous;
  final String comparisonLabel;
  final List<int>? spark;
  final VoidCallback? onTap;

  const KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.previous,
    this.comparisonLabel = 'vs période précédente',
    this.spark,
    this.onTap,
  });
}

/// Bande d'indicateurs façon maquette : une seule carte, cellules séparées par
/// des filets verticaux au-delà de [kSplitBreakpoint], grille en dessous.
class KpiStrip extends StatelessWidget {
  final List<KpiData> items;

  const KpiStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Une bande unique n'est lisible qu'avec assez de largeur par cellule.
        final asStrip =
            constraints.maxWidth >= kSplitBreakpoint &&
            constraints.maxWidth / items.length >= 200;

        if (asStrip) {
          return DashboardCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(
                      child: _KpiCell(data: items[i], index: i),
                    ),
                    if (i != items.length - 1)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        indent: 4,
                        endIndent: 4,
                        color: isDark ? kDarkBorder : kBorderColor,
                      ),
                  ],
                ],
              ),
            ),
          );
        }

        final columns = constraints.maxWidth < 560 ? 1 : 2;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                child: DashboardCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 16,
                  ),
                  child: _KpiCell(data: items[i], index: i),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cellule d'indicateur : pastille d'icône, compteur animé, variation
/// et mini-courbe lorsqu'un historique est fourni.
class _KpiCell extends StatelessWidget {
  final KpiData data;
  final int index;

  const _KpiCell({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: isDark ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: AnimatedCounter(
                  value: data.value,
                  // Décalage léger pour que les compteurs ne partent pas
                  // tous exactement ensemble.
                  duration: Duration(milliseconds: 800 + index * 90),
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ),
              if (data.previous != null) ...[
                const SizedBox(width: 8),
                TrendBadge(
                  current: data.value,
                  previous: data.previous!,
                  comparisonLabel: data.comparisonLabel,
                ),
              ],
            ],
          ),
          if (data.spark != null && data.spark!.length > 1) ...[
            const SizedBox(height: 10),
            Sparkline(values: data.spark!, color: data.color, height: 26),
          ],
        ],
      ),
    );

    if (data.onTap == null) return content;

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }
}

// ─── Répartition par statut ──────────────────────────────────────────────────

/// Une ligne de répartition : libellé, effectif et couleur.
class BreakdownEntry {
  final String label;
  final int count;
  final Color color;

  const BreakdownEntry({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// Liste de répartition avec barres de progression proportionnelles.
/// Partagée par les pipelines Candidats (RH, Admin) et Logistique (Directeur).
class BreakdownList extends StatelessWidget {
  final List<BreakdownEntry> entries;

  const BreakdownList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = entries.fold<int>(0, (sum, e) => sum + e.count);

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: entries[i].color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entries[i].label,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entries[i].count}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: entries[i].color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? entries[i].count / total : 0.0,
                    minHeight: 6,
                    backgroundColor: entries[i].color.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(entries[i].color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Pastille de statut ──────────────────────────────────────────────────────

/// Pastille colorée de statut (équivalent des pills « PAID » / « OVERDUE »).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Journal d'activité ──────────────────────────────────────────────────────

/// Timeline des dernières actions, avec avatar à initiales et pastille colorée.
class ActivityFeed extends StatelessWidget {
  final List<ActionHistoryEntry> entries;
  final int maxItems;
  final String emptyMessage;

  const ActivityFeed({
    super.key,
    required this.entries,
    this.maxItems = 6,
    this.emptyMessage = 'Aucune activité enregistrée pour le moment.',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (entries.isEmpty) {
      return DashboardCard(
        child: _EmptyBlock(icon: Icons.timeline_rounded, message: emptyMessage),
      );
    }

    final visible = entries.take(maxItems).toList();

    return DashboardCard(
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == visible.length - 1 ? 0 : 16,
              ),
              child: _entryRow(visible[i], isDark),
            ),
        ],
      ),
    );
  }

  Widget _entryRow(ActionHistoryEntry entry, bool isDark) {
    final color = actionColor(entry.action);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar à initiales + pastille du type d'action
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  initialsOf(entry.userName),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCard : kSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      actionIcon(entry.action),
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.displayAction,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    relativeDate(entry.timestamp),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                entry.details.isNotEmpty ? entry.details : entry.displayAction,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                entry.userName,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tableau des archives récentes ───────────────────────────────────────────

/// Tableau des dernières archives : colonnes sur large écran,
/// cartes empilées en dessous de [kTableBreakpoint].
class RecentArchivesTable extends StatelessWidget {
  final List<DailyArchive> archives;
  final int maxItems;
  final ValueChanged<DailyArchive>? onTap;
  final String emptyMessage;

  const RecentArchivesTable({
    super.key,
    required this.archives,
    this.maxItems = 6,
    this.onTap,
    this.emptyMessage = 'Aucune archive enregistrée pour le moment.',
  });

  @override
  Widget build(BuildContext context) {
    if (archives.isEmpty) {
      return DashboardCard(
        child: _EmptyBlock(icon: Icons.inbox_outlined, message: emptyMessage),
      );
    }

    final visible = archives.take(maxItems).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < kTableBreakpoint;

        return DashboardCard(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 20,
            vertical: isCompact ? 14 : 8,
          ),
          child: isCompact
              ? Column(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == visible.length - 1 ? 0 : 12,
                        ),
                        child: _CompactArchiveRow(
                          archive: visible[i],
                          onTap: onTap,
                        ),
                      ),
                  ],
                )
              : Column(
                  children: [
                    const _TableHeader(),
                    for (final archive in visible)
                      _TableRow(archive: archive, onTap: onTap),
                  ],
                ),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = GoogleFonts.outfit(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: isDark ? kDarkTextMuted : kTextMuted,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('RÉFÉRENCE', style: style)),
          Expanded(flex: 4, child: Text('INTITULÉ', style: style)),
          Expanded(flex: 3, child: Text('AUTEUR', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          SizedBox(width: 70, child: Text('PIÈCES', style: style)),
          SizedBox(width: 96, child: Text('STATUT', style: style)),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final DailyArchive archive;
  final ValueChanged<DailyArchive>? onTap;

  const _TableRow({required this.archive, this.onTap});

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final archive = widget.archive;
    final onTap = widget.onTap;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = jobColor(archive.jobTitle);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap(archive),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark ? kDarkSurfaceSubtle : kSurfaceSubtle)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              top: BorderSide(color: isDark ? kDarkBorder : kBorderSubtle),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  archive.reference,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  archive.title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  archive.employeeName,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  DateFormat('dd/MM/yyyy').format(archive.archiveDate),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 70,
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file_rounded,
                      size: 13,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${archive.files.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _archiveStatusPill(archive),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactArchiveRow extends StatelessWidget {
  final DailyArchive archive;
  final ValueChanged<DailyArchive>? onTap;

  const _CompactArchiveRow({required this.archive, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = jobColor(archive.jobTitle);

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(archive),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? kDarkSurfaceSubtle : kSurfaceSubtle,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    archive.reference,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                _archiveStatusPill(archive),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              archive.title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    archive.employeeName,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.attach_file_rounded,
                  size: 13,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${archive.files.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM/yyyy').format(archive.archiveDate),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? kDarkTextMuted : kTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _archiveStatusPill(DailyArchive archive) {
  return archive.isToday
      ? const StatusPill(
          label: 'DU JOUR',
          color: kSuccess,
          icon: Icons.check_circle_rounded,
        )
      : const StatusPill(
          label: 'ARCHIVÉ',
          color: kTextMuted,
          icon: Icons.inventory_2_rounded,
        );
}

// ─── État vide ───────────────────────────────────────────────────────────────

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyBlock({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(icon, size: 38, color: isDark ? kDarkTextMuted : kTextMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
