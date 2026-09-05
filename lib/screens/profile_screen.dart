import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/nutrition_plan.dart';
import '../services/firebase_service.dart';
import '../services/nutrition_plan_service.dart';
import '../widgets/amber_atmosphere.dart';
import 'notifications_settings_screen.dart';
import 'profile_edit_screen.dart';
import 'stats_screen.dart';

/// Pantalla de perfil — vista completa con info del usuario,
/// macros y opciones de edición/notificaciones.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);
  Map<String, dynamic>? _data;
  NutritionPlan? _plan;
  bool _planNoticeDismissed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firebase.db.collection('users').doc(uid).get();
    _data = doc.data();
    _plan = await NutritionPlanService.instance.activePlan(uid);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  IconData _genderIcon() => _data?['gender'] == 'Masculino'
      ? Icons.person_rounded
      : Icons.person_rounded;

  String _activityLabel(String key) {
    switch (key) {
      case 'sedentario':
        return 'Sedentario';
      case 'activo':
        return 'Activo';
      default:
        return key;
    }
  }

  String _trainingLabel(String key) {
    switch (key) {
      case 'pesas_hit':
        return 'Pesas / HIIT';
      case 'running':
        return 'Correr';
      case 'cycling':
        return 'Ciclismo';
      case 'swimming':
        return 'Natación';
      case 'yoga':
        return 'Yoga';
      case 'team_sports':
        return 'Deportes de equipo';
      case 'none':
        return 'Ninguno';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;

    if (_loading) {
      return Scaffold(
        backgroundColor: nk.bg,
        body: Center(child: CircularProgressIndicator(color: nk.amber)),
      );
    }

    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    if (_plan != null &&
                        _plan!.hasExpired &&
                        !_planNoticeDismissed) ...[
                      _buildPlanExpiredCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildProfileCard(),
                    const SizedBox(height: 16),
                    _buildMacrosCard(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    _buildActionsSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════════════════════════════════════

  /// Aviso de fin de plan: muestra la fase de transición recomendada y deja
  /// que el usuario la apruebe (nada se recalcula sin su confirmación).
  Widget _buildPlanExpiredCard() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final next = _plan!.nextPhase;
    final phaseLabel = switch (next) {
      PlanPhase.cut => l10n.extremePhaseCut,
      PlanPhase.maintenance => l10n.extremePhaseMaintain,
      PlanPhase.leanGain => l10n.extremePhaseGain,
      PlanPhase.recomposition => l10n.extremePhaseRecomp,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: nk.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: nk.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.planExpiredTitle,
                style: _display(size: 15, color: nk.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.planExpiredBody(
              _plan!.durationWeeks,
              phaseLabel,
            ),
            style: _body(size: 13, color: nk.text),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _dismissExpiredPlan(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: nk.textDim,
                    side: BorderSide(color: nk.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.planSkip),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveTransition(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nk.amber,
                    foregroundColor:
                        nk.mode == NekoThemeMode.dark
                            ? const Color(0xFF1A1206)
                            : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.planApprove,
                    style: _body(size: 13, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveTransition() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null || _data == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await NutritionPlanService.instance.transitionToPhase(
        uid: uid,
        phase: _plan!.nextPhase,
        current: _plan,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.planTransited)),
      );
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.planTransitError('$e'))),
      );
    }
  }

  void _dismissExpiredPlan() {
    if (!mounted) return;
    setState(() => _planNoticeDismissed = true);
  }

  Widget _buildHeader() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            l10n.profileTitle,
            style: _display(
              size: 22,
              weight: FontWeight.w700,
              color: nk.text,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: l10n.profileSettings,
            icon: Icon(Icons.settings_rounded, color: nk.textDim),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Card del perfil — info principal
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildProfileCard() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final username = _data?['username'] as String? ?? l10n.homeDefaultUser;
    final age = _data?['age'] ?? 0;
    final weight = (_data?['weight'] ?? 0).toDouble();
    final height = (_data?['height'] ?? 0).toDouble();
    final bodyFat = (_data?['bodyFatPercent'] as num?)?.toDouble();
    final goal = _data?['fitnessGoal'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: nk.mode == NekoThemeMode.dark
            ? const LinearGradient(
                colors: [Color(0xFFF0B429), Color(0xFFFF6B3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: nk.mode == NekoThemeMode.dark ? null : nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: nk.mode == NekoThemeMode.dark
            ? null
            : Border.all(color: nk.border),
        boxShadow: nk.mode == NekoThemeMode.dark
            ? [
                BoxShadow(
                  color: nk.amber.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Avatar + nombre
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1206).withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1A1206).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                _genderIcon(),
                size: 36,
                color: const Color(0xFF1A1206),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            username,
            style: _display(
              size: 22,
              weight: FontWeight.w700,
              color: const Color(0xFF1A1206),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            goal,
            style: _body(
              size: 13,
              weight: FontWeight.w500,
              color: const Color(0xFF1A1206).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),

          // Info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _profileStat(l10n.profileAge, '$age', l10n.profileYears),
              _profileStat(l10n.profileWeight, '${weight.toStringAsFixed(1)}', 'kg'),
              _profileStat(l10n.profileHeight, '${height.toStringAsFixed(0)}', 'cm'),
              if (bodyFat != null)
                _profileStat(l10n.profileBodyFat, bodyFat.toStringAsFixed(1), '%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: _mono(
            size: 20,
            weight: FontWeight.w700,
            color: const Color(0xFF1A1206),
          ),
        ),
        Text(
          unit,
          style: _mono(
            size: 10,
            weight: FontWeight.w600,
            color: const Color(0xFF1A1206).withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: _mono(
            size: 9,
            weight: FontWeight.w700,
            color: const Color(0xFF1A1206).withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Macros diarios
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildMacrosCard() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final macros = _data?['macroGoals'] as Map<String, dynamic>?;
    final calories = (macros?['calories'] ?? 2000).toDouble();
    final proteins = (macros?['proteins'] ?? 120).toDouble();
    final carbs = (macros?['carbs'] ?? 200).toDouble();
    final fats = (macros?['fats'] ?? 65).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileDailyMacros,
            style: _mono(
              size: 10,
              weight: FontWeight.w700,
              color: nk.textFaint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _macroBigTile(
                  l10n.profileCalories,
                  '${calories.toStringAsFixed(0)}',
                  'kcal',
                  nk.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroBigTile(
                  l10n.profileProtein,
                  '${proteins.toStringAsFixed(0)}',
                  'g',
                  nk.protein,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _macroBigTile(
                  l10n.profileCarbs,
                  '${carbs.toStringAsFixed(0)}',
                  'g',
                  nk.carbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroBigTile(
                  l10n.profileFats,
                  '${fats.toStringAsFixed(0)}',
                  'g',
                  nk.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroBigTile(String label, String value, String unit, Color color) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _mono(size: 9, weight: FontWeight.w700, color: nk.textDim),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: _mono(size: 22, weight: FontWeight.w700, color: color),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: _mono(size: 11, color: nk.textDim)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Grid de estadísticas
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildStatsGrid() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final lifestyle = _data?['dailyLifestyle'] as String? ?? 'sedentario';
    final training = _data?['trainingActivity'] as String? ?? 'pesas_hit';
    final minutes = (_data?['weeklyTrainingMinutes'] as num?)?.toInt() ?? 0;
    final formula = _data?['bmrFormula'] as String? ?? 'mifflin';
    final gender = _data?['gender'] as String? ?? 'Femenino';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileData,
            style: _mono(
              size: 10,
              weight: FontWeight.w700,
              color: nk.textFaint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _statRow(Icons.person_outline_rounded, l10n.profileGender, gender),
          _statRow(
            Icons.directions_walk_rounded,
            l10n.profileLifestyle,
            _activityLabel(lifestyle),
          ),
          _statRow(
            Icons.fitness_center_rounded,
            l10n.profileTraining,
            _trainingLabel(training),
          ),
          _statRow(
              Icons.timer_outlined, l10n.profileMinutesPerWeek, l10n.minShort(minutes)),
          _statRow(
            Icons.calculate_outlined,
            l10n.profileBmrFormula,
            formula == 'katch' ? l10n.bmrFormulaKatch : l10n.bmrFormulaMifflin,
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    final nk = context.nk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: nk.surfaceHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: nk.textDim),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: _body(size: 13, color: nk.textDim)),
          ),
          Text(
            value,
            style: _mono(size: 12, weight: FontWeight.w700, color: nk.text),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Acciones — Editar perfil
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildActionsSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.edit_rounded,
            label: l10n.profileEdit,
            description: l10n.profileEditDesc,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
          ),
          _divider(),
          _actionTile(
            icon: Icons.insights_rounded,
            label: l10n.profileStats,
            description: l10n.profileStatsDesc,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          _divider(),
          _actionTile(
            icon: Icons.calculate_rounded,
            label: l10n.profileRecalc,
            description: l10n.profileRecalcDesc,
            onTap: () => _recalculateAndSave(),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    final nk = context.nk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: nk.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: nk.amber.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 20, color: nk.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: _body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: nk.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: _body(size: 12, color: nk.textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: nk.textFaint),
          ],
        ),
      ),
    );
  }

  void _recalculateAndSave() {
    // Navegar a edición con flag de recálculo
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
  }

  Widget _divider() {
    final nk = context.nk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: nk.divider),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tipografía Noche Ámbar (mismas fuentes que Home/Diario)
// ─────────────────────────────────────────────────────────────────────────────
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

TextStyle _body({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = const Color(0xFFF4EFE6),
}) => GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color);
