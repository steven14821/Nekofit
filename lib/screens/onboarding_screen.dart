import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/neko_cat_mascot.dart';
import 'profile_setup_screen.dart';

/// Onboarding de valor: 3 cards swipeables que cuentan qué va a ganar el
/// usuario antes de pedirle sus datos (retención). Aparece una sola vez por
/// usuario (flag `seenOnboarding` en `users/{uid}`) entre AuthWrapper y
/// ProfileSetupScreen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _starting = false;

  static const int _lastPage = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);

    // Marcar el onboarding como visto (best-effort: si falla, el usuario
    // simplemente lo volverá a ver la próxima vez que abra la app).
    final firebase = ref.read(firebaseServiceProvider);
    final uid = firebase.currentUser?.uid;
    if (uid != null) {
      try {
        await firebase.db
            .collection('users')
            .doc(uid)
            .set({'seenOnboarding': true}, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  void _next() {
    if (_page >= _lastPage) {
      _start();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              // Header: marca + omitir
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Icon(Icons.pets_rounded, color: nk.cat, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      'NekoFit',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: nk.text,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _starting ? null : _start,
                      style: TextButton.styleFrom(
                        foregroundColor: nk.textDim,
                      ),
                      child: Text(
                        l10n.onboardingSkip,
                        style: _mono(nk,
                            size: 11,
                            weight: FontWeight.w700,
                            letterSpacing: 1,
                            color: nk.textDim),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Título
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.onboardingTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: nk.text,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingSubtitle,
                style: _sans(nk, size: 13, color: nk.textDim),
                textAlign: TextAlign.center,
              ),

              // Cards swipeables
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 3,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, index) => _OnboardingCard(
                    index: index,
                  ),
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? nk.amber : nk.textDim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _starting ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: nk.amber,
                      foregroundColor: isDark
                          ? const Color(0xFF1A1206)
                          : Colors.white,
                      disabledBackgroundColor:
                          nk.amber.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _starting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: isDark
                                  ? const Color(0xFF1A1206)
                                  : Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _page >= _lastPage
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _page >= _lastPage ? l10n.start : l10n.next,
                                style: _mono(nk,
                                    size: 14,
                                    weight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: isDark
                                        ? const Color(0xFF1A1206)
                                        : Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card del onboarding
// ─────────────────────────────────────────────────────────────────────────────
enum _SlideKind { pantry, ai, pet }

class _OnboardingCard extends StatelessWidget {
  final int index;

  const _OnboardingCard({required this.index});

  static const _slides = [
    (
      kind: _SlideKind.pantry,
      icon: Icons.inventory_2_rounded,
    ),
    (
      kind: _SlideKind.ai,
      icon: Icons.qr_code_scanner_rounded,
    ),
    (
      kind: _SlideKind.pet,
      icon: Icons.pets_rounded,
    ),
  ];

  Color _slideColor(_SlideKind kind, NekoColors nk) {
    switch (kind) {
      case _SlideKind.pantry:
        return nk.ok;
      case _SlideKind.ai:
        return nk.amber;
      case _SlideKind.pet:
        return nk.cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final slide = _slides[index];
    final color = _slideColor(slide.kind, nk);

    final matches = <(String, String)>[
      (l10n.onboardingSlide1Title, l10n.onboardingSlide1Subtitle),
      (l10n.onboardingSlide2Title, l10n.onboardingSlide2Subtitle),
      (l10n.onboardingSlide3Title, l10n.onboardingSlide3Subtitle),
    ];
    final texts = matches[index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: nk.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.30 : 0.45),
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono grande con fondo tintado
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.40),
                  width: 1,
                ),
              ),
              child: Icon(slide.icon, size: 44, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              texts.$1,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                height: 1.25,
                color: nk.text,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              texts.$2,
              textAlign: TextAlign.center,
              style: _sans(nk, size: 13.5, height: 1.45, color: nk.textDim),
            ),
            const SizedBox(height: 20),
            // Mascota como sello de la promesa
            NekoCatMascot(mood: CatMood.idle, size: 72, showLabel: false),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers tipográficos
// ═════════════════════════════════════════════════════════════════════════════

TextStyle _mono(
  NekoColors nk, {
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double letterSpacing = 0,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.textFaint,
      letterSpacing: letterSpacing,
    );

TextStyle _sans(
  NekoColors nk, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.text,
      height: height,
    );
