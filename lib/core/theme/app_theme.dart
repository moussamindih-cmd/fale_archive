import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Primary & Accents
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color navyDeep = Color(0xFF0F172A); // Slate Deep Dark Navy
  static const Color navyMedium = Color(0xFF152238); // Secondary Dark Navy
  static const Color accentTeal = Color(0xFF0D9488); // Teal
  static const Color accentEmerald = Color(0xFF10B981); // Emerald
  static const Color accentAmber = Color(0xFFF59E0B); // Amber
  static const Color accentCrimson = Color(0xFFEF4444); // Crimson
  static const Color accentPurple = Color(0xFF8B5CF6); // Purple (Violet)
  static const Color paperBg = Color(0xFFF8FAFC); // Paper Light Background

  // Surface & Background - Light Mode
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Surface & Background - Dark Mode
  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceDark = Color(0xFF152238);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Status Badges
  static const Color statusActive = Color(0xFF10B981);
  static const Color statusExpiring = Color(0xFFF59E0B);
  static const Color statusExpired = Color(0xFFEF4444);
  static const Color statusPending = Color(0xFF2563EB);
  static const Color statusArchived = Color(0xFF0D9488);
}

/// System Typographique à Trois Voix (Fraunces + Inter + IBM Plex Mono)
class AppTextStyles {
  // 1. Voix Registre Officiel (Fraunces Serif)
  static TextStyle serifHeader({Color? color, double fontSize = 24, FontWeight fontWeight = FontWeight.bold}) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.navyDeep,
      letterSpacing: -0.3,
    );
  }

  static TextStyle serifTitle({Color? color, double fontSize = 18, FontWeight fontWeight = FontWeight.w700}) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.navyDeep,
    );
  }

  // 2. Voix Interface & Corps (Inter Sans-Serif)
  static TextStyle sansBody({Color? color, double fontSize = 14, FontWeight fontWeight = FontWeight.normal, double height = 1.5}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimaryLight,
      height: height,
    );
  }

  static TextStyle sansLabel({Color? color, double fontSize = 12, FontWeight fontWeight = FontWeight.w600}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textSecondaryLight,
    );
  }

  static TextStyle sansButton({Color? color, double fontSize = 14, FontWeight fontWeight = FontWeight.w600}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
    );
  }

  // 3. Voix Fiche d'Archive & Métadonnées (IBM Plex Mono Monospace)
  static TextStyle monoMeta({Color? color, double fontSize = 12, FontWeight fontWeight = FontWeight.w500}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.accentTeal,
      letterSpacing: 0.2,
    );
  }

  static TextStyle monoRef({Color? color, double fontSize = 13, FontWeight fontWeight = FontWeight.bold}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.primary,
      letterSpacing: 0.5,
    );
  }

  static TextStyle monoTag({Color? color, double fontSize = 11, FontWeight fontWeight = FontWeight.w600}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textSecondaryLight,
    );
  }
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.navyDeep,
      surface: AppColors.surfaceLight,
      error: AppColors.accentCrimson,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.navyDeep,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 1,
      titleTextStyle: AppTextStyles.serifTitle(fontSize: 18, color: AppColors.navyDeep),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderLight, width: 1.2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.sansButton(fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: AppTextStyles.sansLabel(color: AppColors.textSecondaryLight, fontSize: 13),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.accentTeal,
      surface: AppColors.surfaceDark,
      error: AppColors.accentCrimson,
      onPrimary: Colors.black,
      onSurface: AppColors.textPrimaryDark,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.textPrimaryDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.serifTitle(fontSize: 18, color: AppColors.textPrimaryDark),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderDark, width: 1.2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTextStyles.sansButton(fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      hintStyle: AppTextStyles.sansLabel(color: AppColors.textSecondaryDark, fontSize: 13),
    ),
  );
}
