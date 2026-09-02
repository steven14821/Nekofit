import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

/// Paleta de NekoFit — estilo "Konbini 3AM × Neko-Gym".
class AppColors {
  AppColors._();

  // --- Fondos ---
  static const Color background = Color(0xFF0F0C20);
  static const Color surface = Color(0xFF1A1730);
  static const Color surfaceHigh = Color(0xFF221D3A);
  static const Color surfaceLow = Color(0xFF161229);

  // --- Acentos secundarios ---
  static const Color accent = Color(0xFF6C63FF);
  static const Color accentSoft = Color(0xFF9E8EFE);

  // --- Gato ---
  static const Color cat = Color(0xFFFFB347);
  static const Color catShadow = Color(0xFFCC8A2E);

  // --- Estados de producto ---
  static const Color inStock = Color(0xFFFF4D8D);
  static const Color depleted = Color(0xFF5EE2FF);

  // --- Categorías / macros ---
  static const Color catProteins = Color(0xFFE63946);
  static const Color catCarbs = Color(0xFFF4A261);
  static const Color catFats = Color(0xFF8AB17D);
  static const Color catVeg = Color(0xFF52B788);
  static const Color catDairy = Color(0xFFF1C453);

  // --- Texto ---
  static const Color textPrimary = Color(0xFFF5F2FF);
  static const Color textSecondary = Color(0xFFB7B0D6);
  static const Color textMuted = Color(0xFF6E6890);
  static const Color textDim = Color(0xFF4A4565);

  static Color ofCategory(String name) {
    switch (name) {
      case 'Proteínas':
        return catProteins;
      case 'Carbohidratos':
        return catCarbs;
      case 'Grasas':
        return catFats;
      case 'Vegetales':
        return catVeg;
      case 'Lácteos/Huevos':
        return catDairy;
      default:
        return accentSoft;
    }
  }
}

class AppRadii {
  AppRadii._();
  // Konbini es geometría dura: esquinas casi rectas, líneas finas. El único
  // radio grande que se conserva es el del sello/hanko (circular por icono).
  static const double card = 6.0;
  static const double chip = 4.0;
  static const double fab = 16.0;
  static const double stamp = 999.0; // circular para hanko
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Familias tipográficas. Las fuentes reales se cargan vía google_fonts en
/// runtime (Inter / Bagel Fat One / JetBrains Mono). Estas constantes se usan
/// como `fontFamily` en `TextStyle`s que no se construyen a través del theme.
class AppFonts {
  AppFonts._();
  static const String sans = 'Inter';
  static const String display = 'BagelFatOne';
  static const String mono = 'JetBrainsMono';
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    // Tipografías: Inter (sans), Bagel Fat One (display), JetBrains Mono (mono).
    // Cargadas vía google_fonts con fallback al sistema si no hay red.
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final display = GoogleFonts.bagelFatOne(textStyle: textTheme.displayLarge);
    final mono = GoogleFonts.jetBrainsMono(textStyle: textTheme.bodyLarge);

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: Colors.transparent,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.cat,
        onSecondary: Color(0xFF1A0F00),
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: Color(0xFFFF5C7A),
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),

      textTheme: textTheme.copyWith(
        displayLarge: mono.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        displayMedium: mono.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
        headlineLarge: display.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
        headlineMedium: display.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textPrimary),
        labelSmall: mono.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: AppColors.accent),
          insets: EdgeInsets.symmetric(horizontal: 18),
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.textDim, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.chip)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceHigh,
      ),

      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
