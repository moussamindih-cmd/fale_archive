import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PALETTE ULTRA-PREMIUM (Linear / Vercel / Stripe SaaS Style)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Couleurs Principales & Marque ───────────────────────────────────────────
const Color kPrimaryColor = Color(0xFF4F46E5);        // Indigo Vibrant 600
const Color kPrimaryLight = Color(0xFF6366F1);        // Indigo 500
const Color kPrimaryDark = Color(0xFF3730A3);         // Indigo 800
const Color kAccentColor = Color(0xFF06B6D4);         // Cyan 500
const Color kAccentLight = Color(0xFF22D3EE);         // Cyan 400

// ─── Statuts & Sémantique ───────────────────────────────────────────────────
const Color kSuccess = Color(0xFF10B981);             // Emeraude 500
const Color kSuccessBg = Color(0xFFECFDF5);           // Emeraude 50
const Color kSuccessDarkBg = Color(0xFF064E3B);       // Emeraude 900

const Color kWarning = Color(0xFFF59E0B);             // Ambre 500
const Color kWarningBg = Color(0xFFFFFBEB);           // Ambre 50
const Color kWarningDarkBg = Color(0xFF78350F);       // Ambre 900

const Color kDanger = Color(0xFFEF4444);              // Rouge 500
const Color kDangerBg = Color(0xFFFEF2F2);            // Rouge 50
const Color kDangerDarkBg = Color(0xFF7F1D1D);        // Rouge 900

const Color kInfo = Color(0xFF3B82F6);                // Bleu 500
const Color kInfoBg = Color(0xFFEFF6FF);              // Bleu 50
const Color kInfoDarkBg = Color(0xFF1E3A8A);          // Bleu 900

// ─── Light Mode Surfaces ────────────────────────────────────────────────────
const Color kBackground = Color(0xFFF8FAFC);          // Slate 50
const Color kSurface = Color(0xFFFFFFFF);             // Pure White
const Color kSurfaceSubtle = Color(0xFFF1F5F9);       // Slate 100
const Color kBorderColor = Color(0xFFE2E8F0);         // Slate 200
const Color kBorderSubtle = Color(0xFFF1F5F9);        // Slate 100
const Color kTextPrimary = Color(0xFF0F172A);         // Slate 900
const Color kTextSecondary = Color(0xFF475569);       // Slate 600
const Color kTextMuted = Color(0xFF94A3B8);           // Slate 400

// ─── Dark Mode Obsidian Surfaces ────────────────────────────────────────────
const Color kDarkBackground = Color(0xFF0A0E1A);      // Obsidian 950
const Color kDarkSurface = Color(0xFF111827);         // Slate 900
const Color kDarkCard = Color(0xFF161F30);            // Slate 850
const Color kDarkSurfaceSubtle = Color(0xFF1E293B);   // Slate 800
const Color kDarkBorder = Color(0xFF1F293D);          // Slate 800 border
const Color kDarkBorderSubtle = Color(0xFF1E293B);    // Slate 800
const Color kDarkTextPrimary = Color(0xFFF8FAFC);     // Slate 50
const Color kDarkTextSecondary = Color(0xFF94A3B8);   // Slate 400
const Color kDarkTextMuted = Color(0xFF64748B);       // Slate 500

// ─── Couleurs par poste métier ────────────────────────────────────────────────
const Map<String, Color> kJobColors = {
  'Secrétaire': Color(0xFF8B5CF6),           // Violet
  'Comptable': Color(0xFF10B981),            // Emeraude
  'Gestionnaire': Color(0xFF0EA5E9),         // Sky Blue
  'Conseiller Principal': Color(0xFF6366F1), // Indigo
  'Conseiller Adjoint': Color(0xFFF59E0B),   // Amber
};

const Map<String, IconData> kJobIcons = {
  'Secrétaire': Icons.mail_outline_rounded,
  'Comptable': Icons.account_balance_wallet_outlined,
  'Gestionnaire': Icons.manage_accounts_outlined,
  'Conseiller Principal': Icons.workspace_premium_outlined,
  'Conseiller Adjoint': Icons.description_outlined,
};

Color jobColor(String jobTitle) => kJobColors[jobTitle] ?? kPrimaryColor;
IconData jobIcon(String jobTitle) => kJobIcons[jobTitle] ?? Icons.work_outline_rounded;

// ─── Couleurs par rôle ───────────────────────────────────────────────────────
const Map<UserRole, Color> kRoleColors = {
  UserRole.admin: Color(0xFFE11D48),                // Rose Rubis 600
  UserRole.directeurAdministratif: Color(0xFF7C3AED), // Violet 600
  UserRole.rh: Color(0xFFD946EF),                   // Fuchsia 600
  UserRole.employe: Color(0xFF4F46E5),              // Indigo 600
};

const Map<UserRole, IconData> kRoleIcons = {
  UserRole.admin: Icons.admin_panel_settings_outlined,
  UserRole.directeurAdministratif: Icons.account_balance_outlined,
  UserRole.rh: Icons.people_alt_outlined,
  UserRole.employe: Icons.badge_outlined,
};

Color roleColor(UserRole role) => kRoleColors[role] ?? kPrimaryColor;
IconData roleIcon(UserRole role) => kRoleIcons[role] ?? Icons.person_outline_rounded;

Color employeeColor(String jobTitle, UserRole role) {
  if (role != UserRole.employe) return roleColor(role);
  return jobColor(jobTitle);
}

IconData employeeIcon(String jobTitle, UserRole role) {
  if (role != UserRole.employe) return roleIcon(role);
  return jobIcon(jobTitle);
}

// ─── Ombres & Effets de Profondeur ───────────────────────────────────────────
final List<BoxShadow> kSoftShadow = [
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
    blurRadius: 20,
    offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

final List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

final List<BoxShadow> kHoverShadow = [
  BoxShadow(
    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
    blurRadius: 30,
    offset: const Offset(0, 12),
  ),
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
  ),
];

final List<BoxShadow> kDarkCardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.4),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

// ─── Gradients Raffinés ──────────────────────────────────────────────────────
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kHeroGradient = LinearGradient(
  colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kEmeraldGradient = LinearGradient(
  colors: [Color(0xFF059669), Color(0xFF10B981)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kAmberGradient = LinearGradient(
  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kRoseGradient = LinearGradient(
  colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Thème Clair Global ──────────────────────────────────────────────────────
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryColor,
    primary: kPrimaryColor,
    secondary: kAccentColor,
    surface: kSurface,
    error: kDanger,
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.outfitTextTheme().copyWith(
    displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -1),
    displayMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.8),
    headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4),
    titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.2),
    titleMedium: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
    bodyLarge: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w400, color: kTextPrimary, height: 1.5),
    bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: kTextSecondary, height: 1.4),
    bodySmall: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: kTextMuted),
    labelLarge: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
  ),
  scaffoldBackgroundColor: kBackground,

  appBarTheme: AppBarTheme(
    backgroundColor: kBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.outfit(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: kTextPrimary,
      letterSpacing: -0.5,
    ),
    iconTheme: const IconThemeData(color: kTextPrimary, size: 22),
  ),

  cardTheme: CardThemeData(
    elevation: 0,
    color: kSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: kBorderColor, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hoverColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kBorderColor, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kBorderColor, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kPrimaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kDanger, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: GoogleFonts.outfit(color: kTextSecondary, fontWeight: FontWeight.w500, fontSize: 14),
    hintStyle: GoogleFonts.outfit(color: kTextMuted, fontSize: 14),
    prefixIconColor: kTextSecondary,
    suffixIconColor: kTextSecondary,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kTextPrimary,
      side: const BorderSide(color: kBorderColor, width: 1.5),
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kPrimaryColor,
      textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: kSurface,
    elevation: 16,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: kBorderColor)),
    titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.3),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: kSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 20,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  ),

  dividerTheme: const DividerThemeData(
    color: kBorderColor,
    thickness: 1,
    space: 24,
  ),

  snackBarTheme: SnackBarThemeData(
    backgroundColor: kTextPrimary,
    contentTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    behavior: SnackBarBehavior.floating,
    elevation: 8,
  ),
);

// ─── Thème Sombre Obsidian ───────────────────────────────────────────────────
final ThemeData darkAppTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryLight,
    primary: kPrimaryLight,
    secondary: kAccentLight,
    surface: kDarkSurface,
    error: kDanger,
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
    displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: kDarkTextPrimary, letterSpacing: -1),
    displayMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: kDarkTextPrimary, letterSpacing: -0.8),
    headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: kDarkTextPrimary, letterSpacing: -0.4),
    titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: kDarkTextPrimary, letterSpacing: -0.2),
    titleMedium: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: kDarkTextPrimary),
    bodyLarge: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w400, color: kDarkTextPrimary, height: 1.5),
    bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: kDarkTextSecondary, height: 1.4),
    bodySmall: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: kDarkTextMuted),
    labelLarge: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
  ),
  scaffoldBackgroundColor: kDarkBackground,

  appBarTheme: AppBarTheme(
    backgroundColor: kDarkBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.outfit(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: kDarkTextPrimary,
      letterSpacing: -0.5,
    ),
    iconTheme: const IconThemeData(color: kDarkTextPrimary, size: 22),
  ),

  cardTheme: CardThemeData(
    elevation: 0,
    color: kDarkCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: kDarkBorder, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kDarkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kDarkBorder, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kDarkBorder, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kPrimaryLight, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kDanger, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: GoogleFonts.outfit(color: kDarkTextSecondary, fontWeight: FontWeight.w500, fontSize: 14),
    hintStyle: GoogleFonts.outfit(color: kDarkTextMuted, fontSize: 14),
    prefixIconColor: kDarkTextSecondary,
    suffixIconColor: kDarkTextSecondary,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryLight,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kDarkTextPrimary,
      side: const BorderSide(color: kDarkBorder, width: 1.5),
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kPrimaryLight,
      textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: kDarkSurface,
    elevation: 16,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: kDarkBorder)),
    titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: kDarkTextPrimary, letterSpacing: -0.3),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: kDarkSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 20,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  ),

  dividerTheme: const DividerThemeData(
    color: kDarkBorder,
    thickness: 1,
    space: 24,
  ),

  snackBarTheme: SnackBarThemeData(
    backgroundColor: kDarkSurfaceSubtle,
    contentTextStyle: GoogleFonts.outfit(color: kDarkTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kDarkBorder)),
    behavior: SnackBarBehavior.floating,
    elevation: 8,
  ),
);
