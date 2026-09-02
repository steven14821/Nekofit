import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme mode
// ─────────────────────────────────────────────────────────────────────────────
enum NekoThemeMode { dark, light }

// ─────────────────────────────────────────────────────────────────────────────
// NekoPalette — unifies AmberPalette (dark) and LightPalette (light)
//
// Every field has a dark and light value. Screens reference NekoPalette.of
// (or the shorthand extension) instead of AmberPalette / AppColors directly.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class NekoPalette {
  // ── Surfaces ──
  static const _darkBg = Color(0xFF101014);
  static const _lightBg = Color(0xFFF7F6F2);

  static const _darkBgDeep = Color(0xFF0A0A0D);
  static const _lightBgDeep = Color(0xFFEFEDE7);

  static const _darkSurface = Color(0xFF1A1A20);
  static const _lightSurface = Color(0xFFFFFFFF);

  static const _darkSurfaceHigh = Color(0xFF1D1A16);
  static const _lightSurfaceHigh = Color(0xFFEFEDE7);

  static const _darkSurfaceLine = Color(0x24F0B429);
  static const _lightSurfaceLine = Color(0xFFE6E3DC);

  // ── Brand ──
  static const _darkAmber = Color(0xFFF0B429);
  static const _lightAmber = Color(0xFF2E6B4E);

  static const _darkAmberSoft = Color(0xFFFFD166);
  static const _lightAmberSoft = Color(0xFF7EA893);

  static const _darkEmber = Color(0xFFFF6B3D);
  static const _lightEmber = Color(0xFFB0453C);

  static const _darkCat = Color(0xFFFFB37A);
  static const _lightCat = Color(0xFFA9743C);

  static const _darkCatShadow = Color(0xFFB98A2F);
  static const _lightCatShadow = Color(0xFF8A5E30);

  // ── Semantic ──
  static const _darkOk = Color(0xFF7BD88F);
  static const _lightOk = Color(0xFF2E6B4E);

  static const _darkWarn = Color(0xFFFFB020);
  static const _lightWarn = Color(0xFFB98A2F);

  static const _darkDanger = Color(0xFFFF5B5B);
  static const _lightDanger = Color(0xFFB0453C);

  // ── Text ──
  static const _darkText = Color(0xFFF4EFE6);
  static const _lightText = Color(0xFF191918);

  static const _darkTextDim = Color(0xFFA49B8D);
  static const _lightTextDim = Color(0xFF54534E);

  static const _darkTextFaint = Color(0xFF6B6459);
  static const _lightTextFaint = Color(0xFF545046);

  // ── Macros ──
  static const _darkProtein = Color(0xFFFF6B3D);
  static const _lightProtein = Color(0xFFB0453C);

  static const _darkCarbs = Color(0xFFF0B429);
  static const _lightCarbs = Color(0xFFB98A2F);

  static const _darkFat = Color(0xFF6EC8FF);
  static const _lightFat = Color(0xFF4E5F8C);

  // ── Divider ──
  static const _darkDivider = Color(0x1AFFFFFF);
  static const _lightDivider = Color(0xFFE6E3DC);

  // ── Public getters ──
  static Color bg(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkBg : _lightBg;
  static Color bgDeep(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkBgDeep : _lightBgDeep;
  static Color surface(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkSurface : _lightSurface;
  static Color surfaceHigh(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkSurfaceHigh : _lightSurfaceHigh;
  static Color surfaceLine(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkSurfaceLine : _lightSurfaceLine;

  static Color amber(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkAmber : _lightAmber;
  static Color amberSoft(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkAmberSoft : _lightAmberSoft;
  static Color ember(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkEmber : _lightEmber;
  static Color cat(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkCat : _lightCat;

  static Color ok(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkOk : _lightOk;
  static Color warn(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkWarn : _lightWarn;
  static Color danger(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkDanger : _lightDanger;
  static Color catShadow(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkCatShadow : _lightCatShadow;

  static Color text(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkText : _lightText;
  static Color textDim(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkTextDim : _lightTextDim;
  static Color textFaint(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkTextFaint : _lightTextFaint;

  static Color protein(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkProtein : _lightProtein;
  static Color carbs(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkCarbs : _lightCarbs;
  static Color fat(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkFat : _lightFat;

  static Color divider(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkDivider : _lightDivider;

  /// Returns a surface color that contrasts with [bg] for cards/containers.
  static Color cardBg(NekoThemeMode m) => m == NekoThemeMode.dark ? _darkSurface : _lightSurface;

  /// Border color for cards (subtle hairline).
  static Color border(NekoThemeMode m) => m == NekoThemeMode.dark
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFE6E3DC);
}

// ─────────────────────────────────────────────────────────────────────────────
// NekoColors — resolved palette for the current theme mode.
// Accessed via NekoPalette.of(context) or the `nk` extension.
// ─────────────────────────────────────────────────────────────────────────────
class NekoColors {
  final NekoThemeMode mode;

  const NekoColors(this.mode);

  Color get bg => NekoPalette.bg(mode);
  Color get bgDeep => NekoPalette.bgDeep(mode);
  Color get surface => NekoPalette.surface(mode);
  Color get surfaceHigh => NekoPalette.surfaceHigh(mode);
  Color get surfaceLine => NekoPalette.surfaceLine(mode);

  Color get amber => NekoPalette.amber(mode);
  Color get amberSoft => NekoPalette.amberSoft(mode);
  Color get ember => NekoPalette.ember(mode);
  Color get cat => NekoPalette.cat(mode);
  Color get catShadow => NekoPalette.catShadow(mode);

  Color get ok => NekoPalette.ok(mode);
  Color get warn => NekoPalette.warn(mode);
  Color get danger => NekoPalette.danger(mode);

  Color get text => NekoPalette.text(mode);
  Color get textDim => NekoPalette.textDim(mode);
  Color get textFaint => NekoPalette.textFaint(mode);

  Color get protein => NekoPalette.protein(mode);
  Color get carbs => NekoPalette.carbs(mode);
  Color get fat => NekoPalette.fat(mode);

  Color get divider => NekoPalette.divider(mode);
  Color get cardBg => NekoPalette.cardBg(mode);
  Color get border => NekoPalette.border(mode);
}

// ─────────────────────────────────────────────────────────────────────────────
// ThemeProvider — InheritedWidget that provides the resolved NekoColors.
// Persists the preference to Firestore users/{uid}.themeMode.
// ─────────────────────────────────────────────────────────────────────────────
class ThemeProvider extends StatefulWidget {
  final Widget child;

  const ThemeProvider({super.key, required this.child});

  static NekoColors colorsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedTheme>();
    assert(scope != null, 'ThemeProvider not in widget tree');
    return scope!.state.colors;
  }

  static NekoThemeMode modeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedTheme>();
    assert(scope != null, 'ThemeProvider not in widget tree');
    return scope!.state.mode;
  }

  static void setThemeMode(BuildContext context, NekoThemeMode mode) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedTheme>();
    assert(scope != null, 'ThemeProvider not in widget tree');
    scope!.state.setMode(mode);
  }

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<ThemeProvider> {
  NekoThemeMode _mode = NekoThemeMode.dark;

  NekoThemeMode get mode => _mode;
  NekoColors get colors => NekoColors(_mode);

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final uid = _currentUid();
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final raw = doc.data()?['themeMode'] as String?;
      if (raw == 'light' && mounted) {
        setState(() => _mode = NekoThemeMode.light);
      }
    } catch (_) {}
  }

  Future<void> setMode(NekoThemeMode newMode) async {
    if (_mode == newMode) return;
    setState(() => _mode = newMode);
    // La barra de estado sigue al tema: iconos claros en oscuro, oscuros en claro.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: newMode == NekoThemeMode.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: newMode == NekoThemeMode.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ));
    // Persist — best-effort.
    try {
      final uid = _currentUid();
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'themeMode': newMode.name});
      }
    } catch (_) {}
  }

  String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return _InheritedTheme(
      state: this,
      mode: _mode,
      child: widget.child,
    );
  }
}

class _InheritedTheme extends InheritedWidget {
  final _ThemeProviderState state;

  /// Valor del modo en el momento de construir este widget. Se compara en
  /// [updateShouldNotify]: si solo guardáramos `state`, sería el MISMO objeto
  /// antes y después del `setState`, `state._mode == old.state._mode` siempre
  /// y ningún dependiente se reconstruiría al cambiar el tema.
  final NekoThemeMode mode;

  const _InheritedTheme({
    required this.state,
    required this.mode,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedTheme old) => mode != old.mode;
}

// ─────────────────────────────────────────────────────────────────────────────
// Context extension — shorthand for accessing NekoColors from any widget.
// Usage: context.nk.bg, context.nk.amber, etc.
// ─────────────────────────────────────────────────────────────────────────────
extension NekoContextExtension on BuildContext {
  NekoColors get nk => ThemeProvider.colorsOf(this);
  NekoThemeMode get themeMode => ThemeProvider.modeOf(this);
}
