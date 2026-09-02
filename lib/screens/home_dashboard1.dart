import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import '../models/pet_state.dart';
import '../services/firebase_service.dart';
import '../services/pet_service.dart';
import '../widgets/atmosphere_background.dart';
import '../widgets/celebrations.dart';
import '../widgets/neko_cat_mascot.dart';
import '../widgets/steps_section.dart';
import 'diary_screen.dart';
import 'scan_screen.dart';
import 'stats_screen.dart';

/// Pantalla resumen — punto de entrada principal después del login.
///
/// Muestra un saludo hero, 4 stats rápidas en grid 2×2,
/// CTAs a las pantallas más usadas y un tip sarcástico del gato.
class HomeDashboard extends ConsumerStatefulWidget {
  /// Callback que la MainNavigation expone para cambiar de tab programáticamente.
  final void Function(int index)? onNavigateTo;

  const HomeDashboard({super.key, this.onNavigateTo});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);
  late final PetRepository _petService = ref.read(petServiceProvider);

  // ── Frases del gato por mood (sin IA, rotación estática) ──────────────────
  static const Map<String, List<String>> _catTips = {
    PetMoods.happy: [
      '¡Increíble! Has comido bien hoy. Yo también estoy contento. Casi.',
      'Mochi aprueba tu dieta. Por una vez.',
      '¿De verdad comiste tan bien? Sospechoso.',
    ],
    PetMoods.ok: [
      'Todo bien por ahora… pero eso puede cambiar si no registras tu almuerzo.',
      'Ni bien ni mal. Mediocre, como tu café de esta mañana.',
      'Tengo un ojo en tu despensa. El otro está durmiendo.',
    ],
    PetMoods.full: [
      '¿Cuándo fue la última vez que me diste de comer? Pregunto para un amigo.',
      'Registro atrasado. El gato no olvida.',
      'Mi panza dice que llevas tiempo sin pasar por el diario.',
    ],
    PetMoods.angry: [
      'HAMBRE. EXTREMA. Registra algo. YA.',
      'Cero comidas registradas hoy. Cero. Nada. Vacío total.',
      '¿Estás comiendo? Porque yo no lo veo. Registra tu comida.',
    ],
  };

  String _getTip(String mood) {
    final tips = _catTips[mood] ?? _catTips[PetMoods.ok]!;
    // Rotación por hora para que cambie a lo largo del día
    final idx = DateTime.now().hour % tips.length;
    return tips[idx];
  }

  @override
  Widget build(BuildContext context) {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firebase.db.collection('users').doc(uid).snapshots(),
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data() as Map<String, dynamic>?;

        return StreamBuilder<PetState>(
          stream: _petService.watchPetState(uid),
          builder: (context, petSnap) {
            final petState = petSnap.data;

            return StreamBuilder<QuerySnapshot>(
              stream: _firebase.db
                  .collection('users')
                  .doc(uid)
                  .collection('pantry')
                  .snapshots(),
              builder: (context, pantrySnap) {
                final pantryDocs = pantrySnap.data?.docs ?? [];
                final inStockCount = pantryDocs
                    .where((d) => (d.data() as Map)['isAvailable'] == true)
                    .length;
                final depletedCount = pantryDocs.length - inStockCount;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firebase.db
                      .collection('users')
                      .doc(uid)
                      .collection('meals')
                      .where(
                        'createdAt',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(
                            _todayStart.year,
                            _todayStart.month,
                            _todayStart.day,
                          ),
                        ),
                      )
                      .where(
                        'createdAt',
                        isLessThan: Timestamp.fromDate(
                          _todayStart.add(const Duration(days: 1)),
                        ),
                      )
                      .snapshots(),
                  builder: (context, mealsSnap) {
                    final mealsToday = mealsSnap.data?.docs ?? [];
                    double kcalToday = 0;
                    for (final doc in mealsToday) {
                      final data = doc.data() as Map<String, dynamic>;
                      kcalToday += ((data['calories'] as num?) ?? 0).toDouble();
                    }

                    final goals =
                        profileData?['macroGoals'] as Map<String, dynamic>?;
                    final kcalGoal =
                        (goals?['calories'] as num?)?.toDouble() ?? 2000.0;

                    return Scaffold(
                      backgroundColor: AppColors.background,
                      body: AtmosphereBackground(
                        child: SafeArea(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.l,
                                AppSpacing.m,
                                AppSpacing.l,
                                AppSpacing.xxl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── 1. Hero saludo ───────────────────────────────
                                  _HeroGreeting(
                                    profileData: profileData,
                                    petState: petState,
                                  ),
                                  const SizedBox(height: AppSpacing.l),

                                  // ── 1.5. Pasos de hoy (Health Connect) ────────
                                  const StepsSection(compact: true),
                                  const SizedBox(height: AppSpacing.l),

                                  // ── 2. Stats rápidas 2×2 ────────────────────────
                                  _StatsGrid(
                                    petState: petState,
                                    profileData: profileData,
                                    inStockCount: inStockCount,
                                    depletedCount: depletedCount,
                                    kcalToday: kcalToday,
                                    kcalGoal: kcalGoal,
                                  ),
                                  const SizedBox(height: AppSpacing.l),

                                  // ── 3. CTAs grandes ─────────────────────────────
                                  _CtaRow(onNavigateTo: widget.onNavigateTo),
                                  const SizedBox(height: AppSpacing.m),

                                  // ── 3.1. Progreso / estadísticas ────────────────
                                  const _ProgressCta(),
                                  const SizedBox(height: AppSpacing.l),

                                  // ── 4. Tip del gato ─────────────────────────────
                                  _CatTip(
                                    tip: _getTip(
                                      petState?.currentMood ?? PetMoods.ok,
                                    ),
                                    mood: petState?.currentMood ?? PetMoods.ok,
                                    catName:
                                        (profileData?['catName'] as String?),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Hero saludo
// ─────────────────────────────────────────────────────────────────────────────
class _HeroGreeting extends StatelessWidget {
  final Map<String, dynamic>? profileData;
  final PetState? petState;

  const _HeroGreeting({required this.profileData, required this.petState});

  @override
  Widget build(BuildContext context) {
    final username = profileData?['username'] as String? ?? 'Usuario';
    final rawCatName = profileData?['catName'] as String?;
    final catName = (rawCatName == null || rawCatName.trim().isEmpty)
        ? 'Mochi'
        : rawCatName.trim();
    final petType = profileData?['petType'] as String? ?? 'gato';
    final mood = petState?.currentMood ?? PetMoods.ok;
    final moodLabel = _moodEmoji(mood);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceHigh, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.cat.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar mascota — redondo, con mood derivado
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(
                color: _moodColor(mood).withValues(alpha: 0.50),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: NekoCatMascot(
                size: 72,
                showLabel: false,
                petState: petState,
                imagePath: petAssetPath(petType),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, $username!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      catName,
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cat,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _moodColor(mood).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadii.stamp),
                      ),
                      child: Text(
                        moodLabel,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _moodColor(mood),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case PetMoods.happy:
        return const Color(0xFF4CAF50);
      case PetMoods.full:
        return const Color(0xFFFF9800);
      case PetMoods.angry:
        return const Color(0xFFFF5252);
      default:
        return AppColors.accentSoft;
    }
  }

  String _moodEmoji(String mood) {
    switch (mood) {
      case PetMoods.happy:
        return '😸 FELIZ';
      case PetMoods.full:
        return '😾 HARTITO';
      case PetMoods.angry:
        return '🙀 HAMBRIENTO';
      default:
        return '😺 OK';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Stats rápidas 2×2
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final PetState? petState;
  final Map<String, dynamic>? profileData;
  final int inStockCount;
  final int depletedCount;
  final double kcalToday;
  final double kcalGoal;

  const _StatsGrid({
    required this.petState,
    required this.profileData,
    required this.inStockCount,
    required this.depletedCount,
    required this.kcalToday,
    required this.kcalGoal,
  });

  @override
  Widget build(BuildContext context) {
    final hunger = petState?.currentHunger ?? 0;
    final currentStreak = (profileData?['currentStreak'] as num?)?.toInt() ?? 0;
    final longestStreak = (profileData?['longestStreak'] as num?)?.toInt() ?? 0;
    final kcalPct = (kcalToday / kcalGoal).clamp(0.0, 1.0);
    final isStreakMilestone = currentStreak > 0 && currentStreak % 7 == 0;

    return Column(
      children: [
        Row(
          children: [
            // Hambre mascota
            Expanded(
              child: _MiniCard(
                icon: Icons.restaurant_rounded,
                label: 'HAMBRE',
                value: '${hunger.toStringAsFixed(0)}%',
                accent: hunger >= 70 ? AppColors.depleted : AppColors.cat,
                progressValue: hunger / 100.0,
                chipText: _hungerChip(hunger),
                invertBar: true,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            // Racha (brasa si es hito de 7 días)
            Expanded(
              child: Stack(
                children: [
                  _MiniCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'RACHA',
                    value: '$currentStreak días',
                    accent: currentStreak >= 3 || isStreakMilestone
                        ? const Color(0xFFFF9800)
                        : AppColors.textMuted,
                    chipText: isStreakMilestone
                        ? '🔥 ¡$currentStreak días!'
                        : (longestStreak > 0
                              ? 'Récord: $longestStreak'
                              : 'Sin récord'),
                  ),
                  if (isStreakMilestone)
                    Positioned.fill(
                      child: ParticleBurst(
                        trigger: currentStreak ~/ 7,
                        mode: BurstMode.embers,
                        count: 26,
                        origin: const Alignment(0.2, 1.15),
                        duration: const Duration(milliseconds: 2600),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            // Despensa
            Expanded(
              child: _MiniCard(
                icon: Icons.inventory_2_rounded,
                label: 'DESPENSA',
                value: '$inStockCount en stock',
                accent: depletedCount > 0
                    ? const Color(0xFFFF9800)
                    : AppColors.inStock,
                chipText: depletedCount > 0
                    ? '$depletedCount agotados'
                    : 'Todo ok',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            // Diario hoy
            Expanded(
              child: _MiniCard(
                icon: Icons.calendar_today_rounded,
                label: 'HOY',
                value: '${kcalToday.toStringAsFixed(0)} kcal',
                accent: kcalPct >= 1.0 ? AppColors.inStock : AppColors.accent,
                progressValue: kcalPct,
                chipText: 'Meta: ${kcalGoal.toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _hungerChip(double hunger) {
    if (hunger >= 75) return '🙀 Urgente';
    if (hunger >= 45) return '😾 Hartito';
    if (hunger >= 15) return '😺 Ok';
    return '😸 Lleno';
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final double? progressValue;
  final String chipText;
  final bool invertBar;

  const _MiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.chipText,
    this.progressValue,
    this.invertBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePct = invertBar
        ? (progressValue ?? 0)
        : (progressValue ?? 0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: accent.withValues(alpha: 0.20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + icono
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          // Valor principal
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: AppSpacing.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 5,
                color: AppColors.surfaceHigh,
                child: FractionallySizedBox(
                  widthFactor: effectivePct,
                  alignment: Alignment.centerLeft,
                  child: Container(color: accent),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          // Chip de contexto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CTAs grandes
// ─────────────────────────────────────────────────────────────────────────────
class _CtaRow extends StatelessWidget {
  final void Function(int index)? onNavigateTo;

  const _CtaRow({this.onNavigateTo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Agregar comida → DiaryScreen (tab índice 2)
        Expanded(
          child: _CtaButton(
            icon: Icons.add_circle_rounded,
            label: 'Agregar\ncomida',
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4A42D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              if (onNavigateTo != null) {
                onNavigateTo!(2);
              } else {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DiaryScreen()));
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        // Escanear producto → ScanScreen (push directo)
        Expanded(
          child: _CtaButton(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Escanear\nproducto',
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
        ),
      ],
    );
  }
}

class _ProgressCta extends StatelessWidget {
  const _ProgressCta();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MI PROGRESO',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Calorías, comidas y rachas de la semana',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _CtaButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Tip del gato
// ─────────────────────────────────────────────────────────────────────────────
class _CatTip extends StatelessWidget {
  final String tip;
  final String mood;
  final String? catName;

  const _CatTip({required this.tip, required this.mood, this.catName});

  @override
  Widget build(BuildContext context) {
    final color = _moodAccent(mood);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono del gato
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DICE ${(catName == null || catName!.trim().isEmpty) ? 'MOCHI' : catName!.trim().toUpperCase()}',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _moodAccent(String mood) {
    switch (mood) {
      case PetMoods.happy:
        return const Color(0xFF4CAF50);
      case PetMoods.full:
        return const Color(0xFFFF9800);
      case PetMoods.angry:
        return const Color(0xFFFF5252);
      default:
        return AppColors.accentSoft;
    }
  }
}
