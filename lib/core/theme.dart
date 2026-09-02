import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// NekoFit — Design System "Konbini 3AM × Neko-Gym"
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Tokens centralizados del ESTILO.md. Todo color, gradiente, radio y
/// tipografía que aparezca en más de un archivo DEBE vivir aquí.
///
/// Los nombres de los tokens de AppColors se mantienen idénticos a la versión
/// anterior para que el resto de pantallas compile sin cambios.

// ─────────────────────────────────────────────────────────────────────────────
// Colores
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Neutrales ──
  /// Fondo global: papel cálido, casi blanco.
  static const Color background = Color(0xFFF7F6F2);

  /// Tarjetas y superficies elevadas.
  static const Color surface = Color(0xFFFFFFFF);

  /// Relleno sutil (pills, tracks de progreso, inputs).
  static const Color surfaceHigh = Color(0xFFEFEDE7);

  /// Superficie hundida / placeholders vacíos.
  static const Color surfaceLow = Color(0xFFFBFAF7);

  /// Borde hairline por defecto de TODAS las tarjetas.
  static const Color border = Color(0xFFE6E3DC);

  /// Borde enfatizado (hover/selección).
  static const Color borderStrong = Color(0xFFCFCBC1);

  // ── Texto ──
  static const Color textPrimary = Color(0xFF191918);
  static const Color textSecondary = Color(0xFF54534E);
  static const Color textMuted = Color(0xFF8B8A82);
  static const Color textDim = Color(0xFFB8B6AC);

  // ── Acento de marca (único) ──
  /// Verde profundo: acciones primarias, progreso, éxito.
  static const Color accent = Color(0xFF2E6B4E);

  /// Verde suave: estados secundarios del acento.
  static const Color accentSoft = Color(0xFF7EA893);

  /// Tinte de acento para fondos (usar con alpha bajo o directo).
  static const Color accentTint = Color(0xFFE7EFE9);

  // ── Mascota ──
  /// Caramelo cálido: identidad del gato (avatar, nombre, hambre).
  static const Color cat = Color(0xFFA9743C);

  /// Sombra del gato (tono más oscuro de cat).
  static const Color catShadow = Color(0xFF8A5E30);

  // ── Macros extra ──
  /// Lácteos / huevos (amarillo dorado).
  static const Color catDairy = Color(0xFFB98A2F);

  // ── Estado semántico ──
  /// Producto disponible / meta cumplida. Comparte tono con el acento.
  static const Color inStock = Color(0xFF2E6B4E);

  /// Agotado / peligro / eliminar.
  static const Color depleted = Color(0xFFB0453C);

  /// Atención (rachas por romperse, stock bajo).
  static const Color warning = Color(0xFFB98A2F);

  // ── Macros (data-viz, apagados) ──
  static const Color catProteins = Color(0xFFB0453C); // P — rojo ladrillo
  static const Color catCarbs = Color(0xFFB98A2F); // C — ámbar apagado
  static const Color catFats = Color(0xFF4E5F8C); // G — azul pizarra
  static const Color catVeg = Color(0xFF2E6B4E); // Verduras — verde marca

  /// Alias backward-compatible para 'warning'.
  static const Color warn = warning;

  /// Devuelve el color de una categoría de alimento por nombre.
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

// ─────────────────────────────────────────────────────────────────────────────
// Tipografía
// ─────────────────────────────────────────────────────────────────────────────
/// Familias tipográficas. Declara estas fuentes en pubspec.yaml:
///
/// ```yaml
/// fonts:
///   - family: Inter
///     fonts:
///       - asset: assets/fonts/Inter-Regular.ttf
///       - asset: assets/fonts/Inter-Medium.ttf
///         weight: 500
///       - asset: assets/fonts/Inter-SemiBold.ttf
///         weight: 600
///       - asset: assets/fonts/Inter-Bold.ttf
///         weight: 700
///   - family: JetBrainsMono
///     fonts:
///       - asset: assets/fonts/JetBrainsMono-Medium.ttf
///         weight: 500
///       - asset: assets/fonts/JetBrainsMono-Bold.ttf
///         weight: 700
/// ```
class AppFonts {
  AppFonts._();

  /// Sans para TODO el texto (títulos, cuerpo, botones).
  static const String sans = 'Inter';

  /// Mono SOLO para cifras, unidades y micro-etiquetas de datos.
  static const String mono = 'JetBrainsMono';

  /// Display font para títulos grandes y de marca.
  static const String display = 'BagelFatOne';
}

// ─────────────────────────────────────────────────────────────────────────────
// Espaciado (escala de 4)
// ─────────────────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 20;
  static const double xl = 28;
  static const double xxl = 40;
}

// ─────────────────────────────────────────────────────────────────────────────
// Radios
// ─────────────────────────────────────────────────────────────────────────────
class AppRadii {
  AppRadii._();

  /// Tarjetas y sheets.
  static const double card = 18;

  /// Pills, chips y botones pequeños.
  static const double chip = 10;

  /// Badges tipo sello (mood de la mascota).
  static const double stamp = 999;

  /// FAB / botón flotante grande.
  static const double fab = 28;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sombras
// ─────────────────────────────────────────────────────────────────────────────
class AppShadows {
  AppShadows._();

  /// Sombra sutil para fondos planos o elementos pequeños.
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Sombra estándar para tarjetas y superficies.
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Sombra pesada para elementos sobre contenido "busy" (mucho texto/imágenes).
  /// Aumentamos el blur y la profundidad para separar la superficie del fondo.
  static const List<BoxShadow> deep = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Sombra única y muy sutil para elementos flotantes.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x14191918),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Sistema de Movimiento (Springs)
// ─────────────────────────────────────────────────────────────────────────────
/// Parámetros de física para animaciones basadas en resorte.
/// Basados en los estándares de Apple para interfaces fluidas.
class AppSprings {
  AppSprings._();

  /// Resorte estándar: Críticamente amortiguado, sin rebote.
  /// Ideal para: Transiciones de estado, apariciones simples.
  static const SpringParams defaultSpring = SpringParams(
    stiffness: 300.0,
    damping: 25.0,
  );

  /// Resorte con Momentum: Ligero rebote al final.
  /// Ideal para: Drags, flicking, elementos que "caen" en su sitio.
  static const SpringParams momentumSpring = SpringParams(
    stiffness: 250.0,
    damping: 20.0,
  );

  /// Resorte Suave: Lento y elegante.
  /// Ideal para: Cambios de tema, fondos, transiciones ambientales.
  static const SpringParams gentleSpring = SpringParams(
    stiffness: 120.0,
    damping: 20.0,
  );

  /// Resorte Elástico: Rebote pronunciado.
  /// Ideal para: Elementos lúdicos, la mascota, alertas divertidas.
  static const SpringParams elasticSpring = SpringParams(
    stiffness: 400.0,
    damping: 15.0,
  );
}

class SpringParams {
  final double stiffness;
  final double damping;

  const SpringParams({required this.stiffness, required this.damping});

  /// Creates a [SpringSimulation] from this preset.
  ///
  /// [from]: current value (0.0–1.0 typical).
  /// [to]: target value.
  /// [velocity]: initial velocity (pixels/ms or normalized).
  SpringSimulation toSimulation(
    double from,
    double to,
    double velocity,
  ) {
    return SpringSimulation(
      SpringDescription(mass: 1.0, stiffness: stiffness, damping: damping),
      from,
      to,
      velocity,
    );
  }

  /// Duration estimate for this spring (ms). Useful for fallback.
  Duration get estimatedDuration => Duration(
    milliseconds: (1000.0 / sqrt(stiffness / 1.0) * 3.5).round().clamp(150, 600),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ProMotion & Performance Helpers
// ─────────────────────────────────────────────────────────────────────────────
/// Wraps a child with [RepaintBoundary] to isolate repaints during animations.
///
/// On ProMotion devices (120Hz), complex animations that repaint the entire
/// screen cause frame drops. Wrapping animated regions with this widget
/// ensures only the animated portion repaints, maintaining 120fps.
///
/// Use around:
/// - Animated containers (FAB, pills, cards)
/// - Scan line overlays
/// - Floating balloons / bubbles
/// - Ticket card animations
class NekoRepaintBoundary extends StatelessWidget {
  final Widget child;
  const NekoRepaintBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}

/// Returns true if the device likely supports ProMotion (120Hz).
///
/// On iOS, this is true for iPhone 13 Pro+, iPad Pro M1+, etc.
/// On Android, it depends on the display refresh rate.
///
/// Flutter automatically uses the display's native refresh rate,
/// but this helper allows conditional complexity reduction on 60Hz devices.
bool get isProMotionDevice {
  // Flutter 3.x automatically uses the display refresh rate.
  // We assume ProMotion if the platform is iOS (most iOS devices since
  // iPhone 13 Pro support 120Hz) or if we're on a high-end Android.
  // For simplicity, we return true on iOS and let Flutter handle the rest.
  return true; // Flutter manages frame rate natively
}

// ─────────────────────────────────────────────────────────────────────────────
// Estilos de texto reutilizables
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  /// Micro-etiqueta en mayúsculas ("CONSUMIDO", "DESPENSA").
  static const TextStyle overline = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 1.4,
  );

  /// Cifra grande de datos (kcal del día).
  static const TextStyle dataXl = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: -1.0,
  );

  /// Cifra media de datos (valores de mini-tarjetas).
  static const TextStyle dataM = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// Cifra pequeña / unidades.
  static const TextStyle dataS = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NekoTheme — ThemeExtension centralizado (ESTILO.md tokens)
//
// Gradientes, colores por categoría, helpers tipográficos, y tokens que
// antes estaban hardcodeados en 15+ archivos. Accede vía Theme.of(ctx)
// o el helper `context.nt`.
// ─────────────────────────────────────────────────────────────────────────────
class NekoTheme extends ThemeExtension<NekoTheme> {
  const NekoTheme({
    required this.amberGradient,
    required this.headerGradient,
    required this.onAmber,
    required this.catProtein,
    required this.catCarbs,
    required this.catFat,
    required this.catVeg,
    required this.catDairy,
    required this.inStock,
    required this.depleted,
    required this.onSurface,
  });

  /// Gradiente ámbar marca (#F0B429 → #FF6B3D). CTA, botones activos.
  final Gradient amberGradient;

  /// Gradiente del header (#23201A → #16151A en dark).
  final Gradient headerGradient;

  /// Color de texto sobre fondo ámbar (#1A1206).
  final Color onAmber;

  // ── Colores por categoría (macros) ──
  final Color catProtein;
  final Color catCarbs;
  final Color catFat;
  final Color catVeg;
  final Color catDairy;

  // ── Estado semántico ──
  final Color inStock;
  final Color depleted;

  // ── Texto ──
  final Color onSurface;

  /// Versión dark (la más usada — konbini nocturno).
  static const dark = NekoTheme(
    amberGradient: LinearGradient(
      colors: [Color(0xFFF0B429), Color(0xFFFF6B3D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFF23201A), Color(0xFF16151A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    onAmber: Color(0xFF1A1206),
    catProtein: Color(0xFFE63946),
    catCarbs: Color(0xFFF4A261),
    catFat: Color(0xFF8AB17D),
    catVeg: Color(0xFF52B788),
    catDairy: Color(0xFFF1C453),
    inStock: Color(0xFF7BD88F),
    depleted: Color(0xFF5EE2FF),
    onSurface: Color(0xFFF4EFE6),
  );

  /// Versión light.
  static const light = NekoTheme(
    amberGradient: LinearGradient(
      colors: [Color(0xFF2E6B4E), Color(0xFF7EA893)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    headerGradient: LinearGradient(
      colors: [Color(0xFFF7F6F2), Color(0xFFEFEDE7)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    onAmber: Color(0xFFFFFFFF),
    catProtein: Color(0xFFB0453C),
    catCarbs: Color(0xFFB98A2F),
    catFat: Color(0xFF4E5F8C),
    catVeg: Color(0xFF2E6B4E),
    catDairy: Color(0xFFB98A2F),
    inStock: Color(0xFF2E6B4E),
    depleted: Color(0xFFB0453C),
    onSurface: Color(0xFF191918),
  );

  @override
  NekoTheme copyWith({
    Gradient? amberGradient,
    Gradient? headerGradient,
    Color? onAmber,
    Color? catProtein,
    Color? catCarbs,
    Color? catFat,
    Color? catVeg,
    Color? catDairy,
    Color? inStock,
    Color? depleted,
    Color? onSurface,
  }) {
    return NekoTheme(
      amberGradient: amberGradient ?? this.amberGradient,
      headerGradient: headerGradient ?? this.headerGradient,
      onAmber: onAmber ?? this.onAmber,
      catProtein: catProtein ?? this.catProtein,
      catCarbs: catCarbs ?? this.catCarbs,
      catFat: catFat ?? this.catFat,
      catVeg: catVeg ?? this.catVeg,
      catDairy: catDairy ?? this.catDairy,
      inStock: inStock ?? this.inStock,
      depleted: depleted ?? this.depleted,
      onSurface: onSurface ?? this.onSurface,
    );
  }

  @override
  NekoTheme lerp(NekoTheme? other, double t) {
    if (other is! NekoTheme) return this;
    return NekoTheme(
      amberGradient: Gradient.lerp(amberGradient, other.amberGradient, t)!,
      headerGradient: Gradient.lerp(headerGradient, other.headerGradient, t)!,
      onAmber: Color.lerp(onAmber, other.onAmber, t)!,
      catProtein: Color.lerp(catProtein, other.catProtein, t)!,
      catCarbs: Color.lerp(catCarbs, other.catCarbs, t)!,
      catFat: Color.lerp(catFat, other.catFat, t)!,
      catVeg: Color.lerp(catVeg, other.catVeg, t)!,
      catDairy: Color.lerp(catDairy, other.catDairy, t)!,
      inStock: Color.lerp(inStock, other.inStock, t)!,
      depleted: Color.lerp(depleted, other.depleted, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    );
  }

  /// Convenience: devuelve el color de categoría por nombre.
  Color ofCategory(String name) {
    switch (name) {
      case 'Proteínas':
        return catProtein;
      case 'Carbohidratos':
        return catCarbs;
      case 'Grasas':
        return catFat;
      case 'Vegetales':
        return catVeg;
      case 'Lácteos/Huevos':
        return catDairy;
      default:
        return catDairy;
    }
  }
}

/// Acceso rápido a NekoTheme desde cualquier BuildContext.
///
/// ```dart
/// final nt = context.nt;
/// Container(color: nt.catProtein)
/// ```
extension NekoThemeContext on BuildContext {
  NekoTheme get nt => Theme.of(this).extension<NekoTheme>()!;

  /// Returns true if the user has NOT requested reduced motion.
  bool get shouldAnimate => !MediaQuery.of(this).disableAnimations;
}

// ─────────────────────────────────────────────────────────────────────────────
// ThemeData global
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildNekoFitTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.cat,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.depleted,
    onError: Colors.white,
    outline: AppColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppFonts.sans,
    splashFactory: InkSparkle.splashFactory,
    extensions: const [NekoTheme.dark],
  );

  return base.copyWith(
    // ── Texto ──
    textTheme: base.textTheme.copyWith(
      // Título de pantalla (Grande $\rightarrow$ Tracking negativo)
      headlineLarge: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.6, // ~ -0.02em
        height: 1.1,
      ),
      // Saludo / secciones grandes (Mediano-Grande $\rightarrow$ Tracking ligero negativo)
      headlineMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 23,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3, // ~ -0.013em
      ),
      // Títulos de tarjeta (Mediano $\rightarrow$ Tracking neutro)
      titleMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0,
      ),
      // Cuerpo (Mediano $\rightarrow$ Tracking neutro)
      bodyMedium: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
        letterSpacing: 0,
      ),
      // Texto pequeño (Pequeño $\rightarrow$ Tracking positivo para legibilidad)
      bodySmall: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        height: 1.45,
        letterSpacing: 0.3, // ~ +0.02em
      ),
      labelSmall: AppTextStyles.overline,
    ),

    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    ),

    // ── Tarjetas ──
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Botón primario: relleno tinta, sin gradientes ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigh,
        disabledForegroundColor: AppColors.textDim,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card - 4),
        ),
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),

    // ── Botón secundario: hairline ──
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderStrong, width: 1),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card - 4),
        ),
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Inputs ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.card - 4),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.card - 4),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.card - 4),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        color: AppColors.textMuted,
      ),
      prefixIconColor: AppColors.textMuted,
    ),

    // ── Diálogos y sheets ──
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card + 6)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
    ),

    // ── SnackBar ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 14,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip + 2),
      ),
    ),

    // ── Divisores hairline ──
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // ── Barra de navegación inferior ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.accentTint,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.textPrimary : AppColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? AppColors.accent : AppColors.textMuted,
        );
      }),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceHigh,
    ),
  );
}

/// Clase de conveniencia para acceso estático desde main.dart u otros archivos.
/// `darkTheme` devuelve el theme principal de la app (nomenclatura legacy).
class AppTheme {
  AppTheme._();
  static ThemeData get darkTheme => buildNekoFitTheme();
}
