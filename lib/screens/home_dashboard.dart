import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/neko_palette.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/pet_state.dart';
import '../models/nutrition_plan.dart';
import '../services/firebase_service.dart';
import '../services/health_connect_service.dart';
import '../widgets/neko_cat_mascot.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/streak_flame_badge.dart';
import 'food_scanner_screen.dart';
import 'pantry_screen.dart';
import 'plan_editor_screen.dart';
import 'stats_screen.dart';

/// Pantalla resumen — réplica del diseño HTML "Noche Ámbar".
///
/// Konbini japonés a las 3 AM: carbón cálido, ámbar de máquina expendedora,
/// ticket térmico para la nota del gato y neón suave. Layout idéntico al
/// mock: hero con avatar y chips, anillo de calorías con barras de macros,
/// grid 2×2 de stats, CTAs, y el ticket con la frase de Mochi.
///
/// Los datos son en vivo (perfil, mascota, despensa, comidas, pasos).
/// Cada sección es un widget independiente con sus propios streams.
class HomeDashboard extends ConsumerStatefulWidget {
  /// Callback que la MainNavigation expone para cambiar de tab programáticamente.
  final void Function(int index)? onNavigateTo;

  const HomeDashboard({super.key, this.onNavigateTo});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final uid = _firebase.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: nk.bg,
        body: Center(child: CircularProgressIndicator(color: nk.amber)),
      );
    }

    return Scaffold(
      backgroundColor: nk.bg,
      body: Stack(
        children: [
          // Atmósfera compartida: glows ámbar/ember + kanjis deslizantes + scanlines
          Positioned.fill(child: AmberAtmosphere()),
          // Contenido
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Hero ──
                  _HeroSection(uid: uid),
                  const SizedBox(height: 18),

                  // ── 2. Anillo de calorías + macros ──
                  _KcalSection(uid: uid),
                  const SizedBox(height: 18),

                  // ── 3. Stats rápidas 2×2 ──
                  _StatsSection(uid: uid),
                  const SizedBox(height: 18),

                  // ── 3.5 Plan nutricional (crear / editar) ──
                  _PlanCard(uid: uid),
                  const SizedBox(height: 18),

                  // ── 4. CTAs ──
                  _CtaSection(onNavigateTo: widget.onNavigateTo),
                  const SizedBox(height: 18),

                  // ── 5. Ticket térmico: nota del gato ──
                  _TicketSection(uid: uid),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tipografía del diseño ────────────────────────────────────────────────────
// Display → Space Grotesk, body → DM Sans, datos → JetBrains Mono.
// Se cargan vía google_fonts (mismo patrón que theme1.dart / atmosphere).

TextStyle _display({
  double size = 14,
  FontWeight weight = FontWeight.w700,
  Color color = const Color(0xFFF4EFE6),
  double? letterSpacing,
  double? height,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color color = const Color(0xFF6B6459),
  double letterSpacing = 0,
  double? height,
}) => GoogleFonts.jetBrainsMono(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// Formatea un número con separador de miles en punto: 7412 → "7.412".
String _formatNumber(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ── Frases del gato por mood (sin IA, rotación estática) ─────────────────────
String _getTip(AppLocalizations l10n, String mood) {
  final tips = switch (mood) {
    PetMoods.happy => [
        l10n.catTipHappy1,
        l10n.catTipHappy2,
        l10n.catTipHappy3,
      ],
    PetMoods.full => [l10n.catTipFull1, l10n.catTipFull2, l10n.catTipFull3],
    PetMoods.angry => [
        l10n.catTipAngry1,
        l10n.catTipAngry2,
        l10n.catTipAngry3,
      ],
    _ => [l10n.catTipOk1, l10n.catTipOk2, l10n.catTipOk3],
  };
  final idx = DateTime.now().hour % tips.length;
  return tips[idx];
}

/// Estado del gato → icono + etiqueta + color del chip.
({IconData icon, String label, Color color}) _moodChip(
  AppLocalizations l10n,
  String mood,
  NekoColors nk,
) {
  switch (mood) {
    case PetMoods.happy:
      return (
        icon: Icons.sentiment_very_satisfied,
        label: l10n.moodHappy,
        color: nk.ok,
      );
    case PetMoods.full:
      return (
        icon: Icons.sentiment_satisfied,
        label: l10n.moodFull,
        color: nk.warn,
      );
    case PetMoods.angry:
      return (
        icon: Icons.sentiment_very_dissatisfied,
        label: l10n.moodHungry,
        color: nk.danger,
      );
    default:
      return (
        icon: Icons.sentiment_neutral,
        label: l10n.moodOk,
        color: nk.textDim,
      );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Secciones independientes — cada una con sus propios streams
// ═════════════════════════════════════════════════════════════════════════════

/// Hero: avatar con aura ámbar + saludo + chips (nombre, mood, racha).
class _HeroSection extends ConsumerWidget {
  final String uid;
  const _HeroSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firebaseServiceProvider).db;
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
        return StreamBuilder<PetState>(
          stream: ref.read(petServiceProvider).watchPetState(uid),
          builder: (context, petSnap) {
            return _Hero(profileData: profileData, petState: petSnap.data);
          },
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  final Map<String, dynamic>? profileData;
  final PetState? petState;

  const _Hero({required this.profileData, required this.petState});

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final username = profileData?['username'] as String? ?? l10n.homeDefaultUser;
    final catName = profileData?['catName'] as String? ?? 'Mochi';
    final petType = profileData?['petType'] as String? ?? 'gato';
    final mood = petState?.currentMood ?? PetMoods.ok;
    final streak = (profileData?['currentStreak'] as num?)?.toInt() ?? 0;
    final chip = _moodChip(l10n, mood, nk);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: nk.mode == NekoThemeMode.dark
            ? context.nt.headerGradient
            : null,
        color: nk.mode == NekoThemeMode.dark ? null : nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: nk.mode == NekoThemeMode.dark ? nk.surfaceLine : nk.border,
        ),
      ),
      child: Stack(
        children: [
          // Halo decorativo (solo modo oscuro)
          if (nk.mode == NekoThemeMode.dark)
            Positioned(
              right: -40,
              top: -60,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      nk.amber.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Avatar: círculo profundo con aura
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nk.bgDeep,
                    border: Border.all(
                      color: nk.amber.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: nk.mode == NekoThemeMode.dark
                        ? [
                            BoxShadow(
                              color: nk.amber.withValues(alpha: 0.22),
                              blurRadius: 40,
                              spreadRadius: -10,
                            ),
                          ]
                        : const [],
                  ),
                  child: ClipOval(
                    child: NekoCatMascot(
                      size: 64,
                      showLabel: false,
                      petState: petState,
                      imagePath: petAssetPath(petType),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeHello(username),
                        style: _display(size: 26, height: 1.1, color: nk.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            catName.toUpperCase(),
                            style: _mono(
                              size: 12,
                              weight: FontWeight.w700,
                              color: nk.cat,
                            ),
                          ),
                          _iconChip(chip.icon, chip.label, chip.color),
                          StreakFlameBadge(streak: streak, isCompact: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: _mono(
              size: 10,
              weight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo de calorías + barras de macros (perfil + comidas de hoy).
class _KcalSection extends ConsumerWidget {
  final String uid;
  const _KcalSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firebaseServiceProvider).db;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
        final goals = profileData?['macroGoals'] as Map<String, dynamic>?;
        final kcalGoal = (goals?['calories'] as num?)?.toDouble() ?? 2000.0;
        final proGoal = (goals?['proteins'] as num?)?.toDouble() ?? 0;
        final carbGoal = (goals?['carbs'] as num?)?.toDouble() ?? 0;
        final fatGoal = (goals?['fats'] as num?)?.toDouble() ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('users')
              .doc(uid)
              .collection('meals')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
              )
              .where(
                'createdAt',
                isLessThan: Timestamp.fromDate(
                  dayStart.add(const Duration(days: 1)),
                ),
              )
              .snapshots(),
          builder: (context, mealsSnap) {
            final meals = mealsSnap.data?.docs ?? [];
            double kcal = 0, pro = 0, carbs = 0, fats = 0;
            for (final doc in meals) {
              final data = doc.data() as Map<String, dynamic>;
              kcal += ((data['calories'] as num?) ?? 0).toDouble();
              pro += ((data['proteins'] as num?) ?? 0).toDouble();
              carbs += ((data['carbs'] as num?) ?? 0).toDouble();
              fats += ((data['fats'] as num?) ?? 0).toDouble();
            }

            return _KcalCard(
              kcalToday: kcal,
              kcalGoal: kcalGoal,
              pro: pro,
              proGoal: proGoal,
              carbs: carbs,
              carbGoal: carbGoal,
              fats: fats,
              fatGoal: fatGoal,
            );
          },
        );
      },
    );
  }
}

class _KcalCard extends StatelessWidget {
  final double kcalToday;
  final double kcalGoal;
  final double pro, proGoal, carbs, carbGoal, fats, fatGoal;

  const _KcalCard({
    required this.kcalToday,
    required this.kcalGoal,
    required this.pro,
    required this.proGoal,
    required this.carbs,
    required this.carbGoal,
    required this.fats,
    required this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final pct = kcalGoal > 0 ? (kcalToday / kcalGoal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: nk.cardBg,
        border: Border.all(color: nk.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: nk.mode == NekoThemeMode.dark
            ? const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          // Anillo de kcal con el gato como emblema central
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(112, 112),
                  painter: _KcalRingPainter(
                    pct: pct,
                    amber: nk.amber,
                    ember: nk.ember,
                  ),
                ),
                // Emblema del gato en el centro del anillo
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pets_rounded,
                      size: 16,
                      color: nk.amber,
                      shadows: [
                        Shadow(
                          color: nk.amber.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatNumber(kcalToday),
                      style: _display(size: 22, height: 1, color: nk.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/ ${_formatNumber(kcalGoal)} KCAL',
                      style: _mono(
                        size: 8,
                        letterSpacing: 0.16,
                        color: nk.textFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          // Barras de macros
          Expanded(
            child: Column(
              children: [
                _MacroBar(
                  label: l10n.dashMacroProtein,
                  consumed: pro,
                  goal: proGoal,
                  color: nk.protein,
                ),
                const SizedBox(height: 12),
                _MacroBar(
                  label: l10n.dashMacroCarbs,
                  consumed: carbs,
                  goal: carbGoal,
                  color: nk.carbs,
                ),
                const SizedBox(height: 12),
                _MacroBar(
                  label: l10n.dashMacroFats,
                  consumed: fats,
                  goal: fatGoal,
                  color: nk.fat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double goal;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final pct = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: _mono(size: 10, letterSpacing: 0.1, color: nk.textFaint),
            ),
            Text(
              '${consumed.round()} / ${goal.round()} g',
              style: _mono(size: 10, weight: FontWeight.w600, color: nk.text),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: nk.surfaceHigh,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Grid 2×2 de stats rápidas (despensa + comidas + pasos).
class _StatsSection extends ConsumerWidget {
  final String uid;
  const _StatsSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firebaseServiceProvider).db;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('users').doc(uid).collection('pantry').snapshots(),
      builder: (context, pantrySnap) {
        final docs = pantrySnap.data?.docs ?? [];
        final inStock = docs
            .where((d) => (d.data() as Map)['isAvailable'] == true)
            .length;
        final depleted = docs.length - inStock;

        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('users')
              .doc(uid)
              .collection('meals')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
              )
              .where(
                'createdAt',
                isLessThan: Timestamp.fromDate(
                  dayStart.add(const Duration(days: 1)),
                ),
              )
              .snapshots(),
          builder: (context, mealsSnap) {
            final l10n = AppLocalizations.of(context);
            final docs = mealsSnap.data?.docs ?? [];
            final mealTypes = docs
                .map((d) => (d.data() as Map)['mealType'] as String?)
                .where((t) => t != null && t.isNotEmpty)
                .toSet()
                .length
                .clamp(0, 4);

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.kitchen,
                        value: '$inStock',
                        label: l10n.homeInPantry,
                        accent: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stat(
                        icon: Icons.inventory_2_outlined,
                        value: '$depleted',
                        label: l10n.homeDepleted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: _StepsStat()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stat(
                        icon: Icons.restaurant,
                        value: '$mealTypes / 4',
                        label: l10n.homeMealsToday,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool accent;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: (accent && nk.mode == NekoThemeMode.dark)
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [nk.amber.withValues(alpha: 0.12), Colors.transparent],
              )
            : null,
        color: accent
            ? (nk.mode == NekoThemeMode.dark
                  ? null
                  : nk.amber.withValues(alpha: 0.10))
            : nk.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent ? nk.amber.withValues(alpha: 0.28) : nk.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: nk.textFaint),
          const SizedBox(height: 6),
          Text(value, style: _display(size: 22, height: 1, color: nk.text)),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: _mono(size: 9, letterSpacing: 0.16, color: nk.textFaint),
          ),
        ],
      ),
    );
  }
}

/// Pasos + distancia + calorías de hoy vía Health Connect.
/// Si HC no está disponible o no tiene permisos, muestra un CTA para conectar.
class _StepsStat extends ConsumerStatefulWidget {
  const _StepsStat();

  @override
  ConsumerState<_StepsStat> createState() => _StepsStatState();
}

class _StepsStatState extends ConsumerState<_StepsStat> {
  late final HealthConnectService _service = ref.read(
    healthConnectServiceProvider,
  );
  DailyActivity? _today;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    DailyActivity? activity;
    try {
      final available = await _service.isAvailable;
      if (available && await _service.hasPermissions()) {
        activity = await _service.today();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _today = activity;
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    try {
      final granted = await _service.requestPermissions();
      if (granted) {
        _init();
      } else if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.stepsPermissionDenied),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return _Stat(
        icon: Icons.directions_walk,
        value: '...',
        label: l10n.stepsToday,
      );
    }

    if (_today != null) {
      final steps = _today!.steps.toInt();
      final km = _today!.distanceKm;
      final kcal = _today!.activeKcal.toInt();

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: nk.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: nk.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.directions_walk, size: 18, color: nk.textFaint),
            const SizedBox(height: 6),
            Text(
              _formatNumber(steps),
              style: _display(size: 22, height: 1, color: nk.text),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.stepsToday.toUpperCase(),
              style: _mono(size: 9, letterSpacing: 0.16, color: nk.textFaint),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniMetric('${km.toStringAsFixed(1)} km', nk),
                const SizedBox(width: 8),
                _miniMetric('$kcal kcal', nk),
              ],
            ),
          ],
        ),
      );
    }

    // Sin conexión → CTA para vincular
    return GestureDetector(
      onTap: _connect,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: nk.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: nk.amber.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link_rounded, size: 18, color: nk.amber),
            const SizedBox(height: 6),
            Text(
              l10n.stepsLink,
              style: _display(size: 15, height: 1, color: nk.amber),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.stepsToday.toUpperCase(),
              style: _mono(size: 9, letterSpacing: 0.16, color: nk.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String text, NekoColors nk) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(color: nk.cat, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(text, style: _mono(size: 10, color: nk.textFaint)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3.5. Plan nutricional — muestra el plan activo y permite crearlo/editarlo
// ═════════════════════════════════════════════════════════════════════════════
class _PlanCard extends ConsumerWidget {
  final String uid;
  const _PlanCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final db = ref.read(firebaseServiceProvider).db;

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('users')
          .doc(uid)
          .collection('plans')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final hasPlan = docs.isNotEmpty;
        final data = hasPlan
            ? docs.first.data() as Map<String, dynamic>
            : null;
        final phaseName =
            (data?['phase'] as String?) ?? PlanPhase.cut.storageName;
        final phaseLabel = _phaseLabel(l10n, phaseName);
        final duration =
            (data?['durationWeeks'] as num?)?.toInt() ?? 8;

        DateTime? startDate;
        if (data?['startDate'] is Timestamp) {
          startDate = (data!['startDate'] as Timestamp).toDate();
        } else if (data?['createdAt'] is Timestamp) {
          startDate = (data!['createdAt'] as Timestamp).toDate();
        }

        String? progressLabel;
        if (startDate != null) {
          final totalDays = duration * 7;
          final elapsed = DateTime.now()
              .difference(startDate)
              .inDays
              .clamp(0, totalDays)
              .toInt();
          progressLabel = l10n.planCardProgress(totalDays - elapsed, totalDays);
        }

        return GestureDetector(
          onTap: () => _openEditor(context),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: nk.mode == NekoThemeMode.dark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        nk.amber.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    )
                  : null,
              color: nk.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: nk.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      hasPlan
                          ? Icons.restaurant_menu_rounded
                          : Icons.add_circle_outline,
                      size: 20,
                      color: nk.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasPlan
                            ? l10n.homePlanTitle
                            : l10n.homePlanEmptyTitle,
                        style: _display(size: 16, color: nk.text),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: nk.textFaint,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasPlan) ...[
                  Row(
                    children: [
                      _planBadge(phaseLabel, nk.amber, nk),
                      const SizedBox(width: 8),
                      Text(
                        '$duration ${l10n.planCardWeeks}',
                        style: _mono(size: 11, color: nk.textFaint),
                      ),
                    ],
                  ),
                  if (progressLabel != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      progressLabel.toUpperCase(),
                      style: _mono(size: 10, color: nk.textFaint),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    l10n.homePlanEditHint,
                    style: _body(size: 12, color: nk.textDim),
                  ),
                ] else
                  Text(
                    l10n.homePlanEmptyHint,
                    style: _body(size: 12, color: nk.textDim),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditor(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PlanEditorScreen()),
    );
    if (saved == true && context.mounted) {
      final nk = context.nk;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: nk.amber,
          content: Text(
            AppLocalizations.of(context).planSavedNotice,
            style: TextStyle(color: Colors.black),
          ),
        ),
      );
    }
  }

  Widget _planBadge(String label, Color color, NekoColors nk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: _mono(size: 10, weight: FontWeight.w700, color: nk.amber),
      ),
    );
  }

  String _phaseLabel(AppLocalizations l10n, String phase) {
    switch (phase) {
      case 'maintenance':
        return l10n.extremePhaseMaintain;
      case 'lean_gain':
        return l10n.extremePhaseGain;
      case 'recomposition':
        return l10n.extremePhaseRecomp;
      default:
        return l10n.extremePhaseCut;
    }
  }

  TextStyle _display({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color color = const Color(0xFFF4EFE6),
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  TextStyle _mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color color = const Color(0xFF6B6459),
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  TextStyle _body({double size = 12, Color color = const Color(0xFF6B6459)}) =>
      GoogleFonts.dmSans(fontSize: size, color: color);
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. CTAs
// ═════════════════════════════════════════════════════════════════════════════
class _CtaSection extends StatelessWidget {
  final void Function(int index)? onNavigateTo;

  const _CtaSection({this.onNavigateTo});

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.homeQuickAction,
              style: _display(size: 18, color: nk.text),
            ),
            GestureDetector(
              onTap: () => _openStats(context),
              child: Text(
                l10n.homeViewAll,
                style: _mono(size: 11, color: nk.amber, letterSpacing: 0.08),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Analizar plato → escáner de comida
            Expanded(
              child: _TallButton(
                icon: Icons.camera_alt,
                label: l10n.homeScanMeal,
                hint: l10n.homeScanMealHint,
                primary: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Reabastecer → despensa (sección agotados)
            Expanded(
              child: _TallButton(
                icon: Icons.receipt_long,
                label: l10n.homeRestock,
                hint: l10n.homeRestockHint,
                primary: false,
                onTap: () {
                  if (onNavigateTo != null) {
                    onNavigateTo!(1);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PantryScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Ver progreso semanal → stats
        GestureDetector(
          onTap: () => _openStats(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: nk.amber.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 16, color: nk.amber),
                const SizedBox(width: 8),
                Text(
                  l10n.homeWeeklyProgress,
                  style: _display(
                    size: 14,
                    weight: FontWeight.w600,
                    color: nk.amber,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openStats(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StatsScreen()));
  }
}

class _TallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool primary;
  final VoidCallback onTap;

  const _TallButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final nt = context.nt;
    // En dark el CTA primario es ámbar brillante → texto oscuro;
    // en claro es ámbar verde oscuro → texto blanco (contraste AA).
    final textColor = primary ? nt.onAmber : nk.text;
    final hintColor = primary
        ? nt.onAmber.withValues(alpha: 0.72)
        : nk.textFaint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          gradient: (primary && nk.mode == NekoThemeMode.dark)
              ? nt.amberGradient
              : null,
          color: primary
              ? (nk.mode == NekoThemeMode.dark ? null : nk.amber)
              : nk.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: nk.border),
          boxShadow: (primary && nk.mode == NekoThemeMode.dark)
              ? [
                  BoxShadow(
                    color: nk.amber.withValues(alpha: 0.55),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: _display(
                size: 14,
                weight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: _mono(size: 9, letterSpacing: 0.12, color: hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. Ticket térmico — nota de Mochi
// ═════════════════════════════════════════════════════════════════════════════
class _TicketSection extends ConsumerWidget {
  final String uid;
  const _TicketSection({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firebaseServiceProvider).db;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
        final catName = profileData?['catName'] as String? ?? 'Mochi';
        return StreamBuilder<PetState>(
          stream: ref.read(petServiceProvider).watchPetState(uid),
          builder: (context, petSnap) {
            final mood = petSnap.data?.currentMood ?? PetMoods.ok;
            return StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('users')
                  .doc(uid)
                  .collection('meals')
                  .where(
                    'createdAt',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
                  )
                  .where(
                    'createdAt',
                    isLessThan: Timestamp.fromDate(
                      dayStart.add(const Duration(days: 1)),
                    ),
                  )
                  .snapshots(),
              builder: (context, mealsSnap) {
                final meals = mealsSnap.data?.docs ?? [];
                final deducted = meals
                    .where((d) => (d.data() as Map)['pantryItemId'] != null)
                    .length;

                return _TicketCard(
                  catName: catName,
                  mood: mood,
                  mealsCount: meals.length,
                  deductedCount: deducted,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String catName;
  final String mood;
  final int mealsCount;
  final int deductedCount;

  const _TicketCard({
    required this.catName,
    required this.mood,
    required this.mealsCount,
    required this.deductedCount,
  });

  static const _paper = Color(0xFFF6F1E6);
  static const _ink = Color(0xFF1B1A17);
  static const _muted = Color(0xFF6A6255);

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    // En claro el papel casi se funde con el fondo (#F7F6F2 ≈ #F6F1E6):
    // papel más profundo + borde visible + sombra de elevación suave.
    final paper = nk.mode == NekoThemeMode.dark
        ? _paper
        : const Color(0xFFF0EADC);
    final chip = _moodChip(l10n, mood, nk);
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final dayNo =
        now.difference(DateTime(2024, 1, 1)).inDays * 37 % 9000 + 1000;
    final noteName =
        catName.toLowerCase() == 'mochi' ? 'Mochi' : catName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sección head
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.ticketNote(noteName),
              style: _display(size: 18, color: nk.text),
            ),
            Text(
              '$hh:$mm',
              style: _mono(size: 10, letterSpacing: 0.24, color: nk.textFaint),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Ticket térmico con bordes dentados
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _TicketNotchPainter(paper),
            child: const SizedBox.expand(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: paper,
            border: nk.mode == NekoThemeMode.dark
                ? null
                : Border.all(color: const Color(0xFFCFCBC1)),
            boxShadow: nk.mode == NekoThemeMode.dark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0x14000000),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del ticket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NEKOFIT KONBINI',
                    style: _mono(
                      size: 10,
                      weight: FontWeight.w700,
                      letterSpacing: 0.16,
                      color: _muted,
                    ),
                  ),
                  Text(
                    'N.º $dayNo',
                    style: _mono(
                      size: 10,
                      weight: FontWeight.w700,
                      letterSpacing: 0.16,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomPaint(
                painter: _DashedLinePainter(_muted.withValues(alpha: 0.5)),
                child: const SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 10),
              // Cita
              Text(
                '“${_getTip(l10n, mood)}”',
                style: _mono(size: 12.5, color: _ink, height: 1.55),
              ),
              const SizedBox(height: 10),
              CustomPaint(
                painter: _DashedLinePainter(_muted.withValues(alpha: 0.5)),
                child: const SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 8),
              // Pie
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.ticketMood(chip.label),
                    style: _mono(size: 10, letterSpacing: 0.12, color: _muted),
                  ),
                  Text(
                    mealsCount > 0 ? l10n.ticketFed : l10n.ticketFasting,
                    style: _mono(size: 10, letterSpacing: 0.12, color: _muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _TicketNotchPainter(paper),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 10),
        // Nota al pie
        Text(
          l10n.ticketDeducted(deductedCount),
          style: _mono(size: 10, letterSpacing: 0.1),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Painters y helpers de atmósfera
// ═════════════════════════════════════════════════════════════════════════════

/// Anillo de calorías con gradiente ámbar → ember.
class _KcalRingPainter extends CustomPainter {
  final double pct;
  final Color amber;
  final Color ember;

  const _KcalRingPainter({
    required this.pct,
    required this.amber,
    required this.ember,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // Arco con gradiente (empieza arriba, sentido horario — como el SVG
    // rotado -90° del diseño).
    final startAngle = -math.pi / 2;
    final sweep = pct.clamp(0.0, 1.0) * math.pi * 2;
    if (sweep <= 0) return;

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [amber, ember],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _KcalRingPainter old) => old.pct != pct;
}

/// Bordes dentados del ticket (alternancia papel/transparente).
class _TicketNotchPainter extends CustomPainter {
  final Color paper;

  const _TicketNotchPainter(this.paper);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = paper;
    const dash = 8.0;
    const gap = 8.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, dash, size.height), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketNotchPainter old) => old.paper != paper;
}

/// Línea punteada (separadores del ticket).
class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}
