import 'package:flutter/material.dart';
import '../theme/glassmorphism.dart';
import '../theme/app_theme.dart';

/// Panneau vitré premium pour les sections de formulaire, à utiliser sur un
/// fond animé ([AnimatedMeshBackground]) pour un effet glassmorphism visible.
class GlassFormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      blurX: 24,
      blurY: 24,
      borderRadius: 24,
      color: isDark ? const Color(0x33161F30) : const Color(0x99FFFFFF),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.6),
        width: 1.2,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Décoration d'input vitrée cohérente avec [GlassFormCard], à appliquer via
/// `Theme(data: ..., child: Form(...))` sur un écran avec fond animé.
InputDecorationTheme glassInputDecorationTheme(bool isDark) {
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.white.withValues(alpha: 0.7);
  return InputDecorationTheme(
    filled: true,
    fillColor: isDark ? const Color(0x1AFFFFFF) : const Color(0x80FFFFFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? kPrimaryLight : kPrimaryColor,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kDanger, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    labelStyle: TextStyle(
      color: isDark ? kDarkTextSecondary : kTextSecondary,
      fontWeight: FontWeight.w500,
      fontSize: 14,
    ),
    hintStyle: TextStyle(
      color: isDark ? kDarkTextMuted : kTextMuted,
      fontSize: 14,
    ),
    prefixIconColor: isDark ? kDarkTextSecondary : kTextSecondary,
    suffixIconColor: isDark ? kDarkTextSecondary : kTextSecondary,
  );
}
