import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Mode Provider ─────────────────────────────────────────────────────

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('dark_mode', !isDark);
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = mode;
    await prefs.setBool('dark_mode', mode == ThemeMode.dark);
  }
}

// ─── App Color Tokens ────────────────────────────────────────────────────────

class SColors {
  // Brand colors (same in both themes)
  static const Color primary = Color(0xFF2A9D8F);
  static const Color primaryLight = Color(0xFF3DB8A9);
  static const Color primaryDeep = Color(0xFF1B5E4A);
  static const Color coral = Color(0xFFE76F51);
  static const Color coralDeep = Color(0xFF8B3A0F);
  static const Color gold = Color(0xFFE9C46A);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFF6B5A1E);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);

  // Signature gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, coral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient tealGoldGradient = LinearGradient(
    colors: [primary, gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero gradients per service
  static const LinearGradient heroFood = LinearGradient(
    colors: [coralDeep, Color(0xFF2A1508)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient heroPahapit = LinearGradient(
    colors: [primaryDeep, Color(0xFF0A2018)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient heroHabal = LinearGradient(
    colors: [goldDeep, Color(0xFF1A1508)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─── Semantic color extension ────────────────────────────────────────────────

@immutable
class SugoColors extends ThemeExtension<SugoColors> {
  final Color bg;
  final Color cardBg;
  final Color inputBg;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color iconDefault;
  final Color iconActive;
  final Color navBarBg;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color badgeBg;

  const SugoColors({
    required this.bg,
    required this.cardBg,
    required this.inputBg,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconDefault,
    required this.iconActive,
    required this.navBarBg,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.badgeBg,
  });

  // Light theme colors (matching Figma)
  static const light = SugoColors(
    bg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    inputBg: Color(0xFFF5F5F5),
    border: Color(0xFFEEEEEE),
    divider: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF1A1D1E),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    iconDefault: Color(0xFF9CA3AF),
    iconActive: Color(0xFF2A9D8F),
    navBarBg: Color(0xFFFFFFFF),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
    badgeBg: Color(0xFFE8F5E9),
  );

  // Dark theme colors
  static const dark = SugoColors(
    bg: Color(0xFF1A1C20),
    cardBg: Color(0xFF23252A),
    inputBg: Color(0xFF23252A),
    border: Color(0xFF2D2F34),
    divider: Color(0xFF2D2F34),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textTertiary: Color(0x8AFFFFFF),
    iconDefault: Color(0x8AFFFFFF),
    iconActive: Color(0xFF2A9D8F),
    navBarBg: Color(0xFF23252A),
    shimmerBase: Color(0xFF23252A),
    shimmerHighlight: Color(0xFF2D2F34),
    badgeBg: Color(0xFF1B3A2D),
  );

  @override
  SugoColors copyWith({
    Color? bg,
    Color? cardBg,
    Color? inputBg,
    Color? border,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? iconDefault,
    Color? iconActive,
    Color? navBarBg,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? badgeBg,
  }) {
    return SugoColors(
      bg: bg ?? this.bg,
      cardBg: cardBg ?? this.cardBg,
      inputBg: inputBg ?? this.inputBg,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      iconDefault: iconDefault ?? this.iconDefault,
      iconActive: iconActive ?? this.iconActive,
      navBarBg: navBarBg ?? this.navBarBg,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      badgeBg: badgeBg ?? this.badgeBg,
    );
  }

  @override
  SugoColors lerp(ThemeExtension<SugoColors>? other, double t) {
    if (other is! SugoColors) return this;
    return SugoColors(
      bg: Color.lerp(bg, other.bg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconActive: Color.lerp(iconActive, other.iconActive, t)!,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      badgeBg: Color.lerp(badgeBg, other.badgeBg, t)!,
    );
  }
}

// ─── Helper extension on BuildContext ────────────────────────────────────────

extension SugoThemeX on BuildContext {
  SugoColors get sc => Theme.of(this).extension<SugoColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── Theme Data ──────────────────────────────────────────────────────────────

class SugoTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return _build(base, Brightness.light, SugoColors.light);
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return _build(base, Brightness.dark, SugoColors.dark);
  }

  static ThemeData _build(ThemeData base, Brightness brightness, SugoColors c) {
    final isLight = brightness == Brightness.light;

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: SColors.primary,
        onPrimary: Colors.white,
        secondary: SColors.coral,
        onSecondary: Colors.white,
        error: SColors.error,
        onError: Colors.white,
        surface: c.cardBg,
        onSurface: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
          letterSpacing: -0.1,
        ),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: isLight ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isLight
              ? BorderSide.none
              : BorderSide(color: c.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.navBarBg,
        selectedItemColor: SColors.primary,
        unselectedItemColor: c.iconDefault,
        type: BottomNavigationBarType.fixed,
        elevation: isLight ? 8 : 0,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SColors.error),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: c.textTertiary,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: c.textSecondary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        // Display — 32/w800 / -0.8px (hero slides, landing)
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
          letterSpacing: -0.8,
          height: 1.14,
        ),
        // headlineLarge — 28/w800 / -0.6px
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
          letterSpacing: -0.6,
          height: 1.18,
        ),
        // headlineMedium — 24/w700 / -0.4px
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          letterSpacing: -0.4,
          height: 1.22,
        ),
        // headlineSmall — 20/w700 / -0.2px
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
          letterSpacing: -0.2,
          height: 1.28,
        ),
        // titleLarge — 18/w600 / -0.1px
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
          letterSpacing: -0.1,
          height: 1.35,
        ),
        // titleMedium — 16/w600
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
          height: 1.4,
        ),
        // bodyLarge — 16/w400 / 1.55 lh
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: c.textPrimary,
          height: 1.55,
        ),
        // bodyMedium — 14/w400 / 1.6 lh
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: c.textSecondary,
          height: 1.6,
        ),
        // bodySmall — 12/w400 / 1.5 lh
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: c.textTertiary,
          height: 1.5,
        ),
        // labelLarge — 14/w600
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
          height: 1.4,
        ),
        // labelSmall — 10/w700 / 0.6 tracking — status badges / overlines
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c.textSecondary,
          letterSpacing: 0.6,
          height: 1.4,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
