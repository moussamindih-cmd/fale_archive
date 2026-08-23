import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Système typographique à trois voix.
///
/// - **Fraunces** (serif) — registre officiel : en-têtes de bordereaux,
///   titres de rapports, mentions légales de conservation.
/// - **Inter** (sans-serif) — interface et corps de texte.
/// - **IBM Plex Mono** (monospace) — références d'archive, cotes, métadonnées :
///   tout ce qui doit se lire caractère par caractère sans ambiguïté.
///
/// Les couleurs par défaut proviennent des jetons de [app_theme.dart] afin que
/// la typographie suive la palette Indigo/Cyan de l'application.
class AppTextStyles {
  const AppTextStyles._();

  // --- 1. Registre officiel (Fraunces) ---------------------------------

  static TextStyle serifHeader({
    Color? color,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kTextPrimary,
      letterSpacing: -0.3,
    );
  }

  static TextStyle serifTitle({
    Color? color,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kTextPrimary,
    );
  }

  // --- 2. Interface et corps (Inter) -----------------------------------

  static TextStyle sansBody({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    double height = 1.5,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kTextPrimary,
      height: height,
    );
  }

  static TextStyle sansLabel({
    Color? color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kTextSecondary,
    );
  }

  static TextStyle sansButton({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
    );
  }

  // --- 3. Références et métadonnées (IBM Plex Mono) --------------------

  static TextStyle monoMeta({
    Color? color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kAccentColor,
      letterSpacing: 0.2,
    );
  }

  /// Cote d'archive (`SEC-21082026`), référence d'offre, numéro de facture.
  static TextStyle monoRef({
    Color? color,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kPrimaryColor,
      letterSpacing: 0.5,
    );
  }

  static TextStyle monoTag({
    Color? color,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? kTextSecondary,
    );
  }
}
