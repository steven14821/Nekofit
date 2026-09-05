import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/auth_gate_controller.dart';
import '../core/neko_palette.dart';
import '../core/calorie_calculator.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/nutrition_plan.dart';
import '../models/user_context.dart';
import '../services/nutrition_plan_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/neko_cat_mascot.dart';
import 'main_navigation.dart';

/// Onboarding post-registro en 3 pasos:
///
///   Paso 1 — "Lo esencial" (30 segundos): género, edad, altura y peso +
///   objetivo fitness. Con eso se calcula la meta calórica al instante y el
///   usuario puede entrar a la app ya. (RF-1 mínimo)
///
///   Paso 2 — "Personaliza tu plan" (opcional): % de grasa corporal, estilo
///   de vida, entrenamiento y mascota. Refina la meta antes de guardar.
///
///   Paso 3 — "Personalización extrema" (opcional, saltable): plan nutricional
///   con plazo definido (4/8/12 semanas), nº de comidas, ayuno intermitente y
///   contexto de salud/preferencias que alimentan al plan semanal IA.
///
/// Los tres caminos escriben el mismo documento `users/{uid}`; los pasos 2 y 3
/// son opcionales y solo añaden campos extra para refinar la meta.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pageController = PageController();
  // Inyección de dependencias: se lee del contenedor, no del singleton.
  late final _firebaseService = ref.read(firebaseServiceProvider);
  int _currentStep = 0; // 0 = Lo esencial, 1 = Personaliza

  // -------- Paso 1: Datos fisiológicos base --------
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'Femenino'; // Masculino o Femenino
  bool get _isMale => _gender == 'Masculino';

  // -------- Paso 2 (personalización): % de grasa corporal --------
  // Método: 'visual' o 'us_navy'
  String _bodyFatMethod = 'visual';

  // Visual: slider + tarjeta seleccionada.
  double _bodyFatVisual = 20.0;
  // US Navy: inputs.
  final _neckController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  double? _bodyFatNavyValue; // calculado en vivo

  // -------- Paso 2 (personalización): Estilo de vida diario --------
  String _dailyLifestyle = 'sedentario';

  // -------- Paso 2 (personalización): Entrenamiento --------
  String _trainingActivity = 'pesas_hit';
  double _weeklyTrainingMinutes = 0;

  // -------- Objetivo fitness (paso 1, usado por ambos) --------
  String _fitnessGoal = 'Mantener peso';
  final _customGoalController = TextEditingController();

  // -------- Paso 2 (personalización): Mascota --------
  final _catNameController = TextEditingController(text: 'Mochi');
  final String _catStyle = 'default';
  String _petType = 'gato';

  // Calculated macros
  double _calories = 2000;
  double _proteins = 120;
  double _carbs = 200;
  double _fats = 65;
  String _bmrFormulaUsed = 'mifflin';

  bool _isLoading = false;

  // -------- Paso 3 (personalización extrema, opcional) --------
  // Si está desactivado, el usuario guarda sin plan (el flujo clásico).
  bool _extremeChatEnabled = false;
  String _extremePhase = 'cut'; // cut | maintenance | lean_gain | recomposition
  bool _extremePhaseTouched = false;
  int _extremeDurationWeeks = 8; // 4 | 8 | 12
  int _extremeMealsPerDay = 4; // 3 | 4 | 5
  bool _extremeIntermittentFasting = false;
  int _extremeFastingHours = 16;
  final _medicalConditionsController = TextEditingController();
  final _dietaryPreferencesController = TextEditingController();
  final _mustHaveFoodsController = TextEditingController();
  final _aversionsController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _customGoalController.dispose();
    _catNameController.dispose();
    _medicalConditionsController.dispose();
    _dietaryPreferencesController.dispose();
    _mustHaveFoodsController.dispose();
    _aversionsController.dispose();
    super.dispose();
  }

  double? get _currentBodyFatPercent {
    if (_bodyFatMethod == 'visual') return _bodyFatVisual;
    return _bodyFatNavyValue;
  }

  /// Vista previa en vivo del cálculo US Navy.
  double? _recalcNavy() {
    final neck = double.tryParse(_neckController.text);
    final waist = double.tryParse(_waistController.text);
    final height = double.tryParse(_heightController.text);
    final hip = double.tryParse(_hipController.text);

    if (neck == null || waist == null || height == null) return null;
    if (!_isMale && (hip == null || hip <= 0)) return null;
    // En hombres la cintura debe ser mayor que el cuello para que la fórmula
    // tenga sentido. Si no, devolvemos null para no mostrar un número basura.
    if (_isMale && waist <= neck) return null;

    return CalorieCalculator.bodyFatNavy(
      isMale: _isMale,
      neckCm: neck,
      waistCm: waist,
      heightCm: height,
      hipCm: _isMale ? null : hip,
    );
  }

  void _recalculateNavyFromInputs() {
    final value = _recalcNavy();
    setState(() {
      _bodyFatNavyValue = value;
    });
  }

  void _calculateMacros() {
    final age = int.tryParse(_ageController.text) ?? 25;
    final height = double.tryParse(_heightController.text) ?? 170;
    final weight = double.tryParse(_weightController.text) ?? 70;
    final bodyFat = _currentBodyFatPercent;

    // 1. BMR: Katch-McArdle si hay % grasa razonable, si no Mifflin.
    final bmrResult = CalorieCalculator.calculateBmr(
      weightKg: weight,
      heightCm: height,
      age: age,
      isMale: _isMale,
      bodyFatPercent: bodyFat,
    );
    _bmrFormulaUsed = bmrResult.formula;

    // 2. TDEE = BMR * lifestyle + (kcal entrenamiento semanales / 7).
    final tdee = CalorieCalculator.dailyTdee(
      bmr: bmrResult,
      lifestyle: _dailyLifestyle,
      trainingActivityKey: _trainingActivity,
      trainingMinutesPerWeek: _weeklyTrainingMinutes.round(),
    );

    // 3. Ajustar por objetivo.
    double targetCalories = tdee;
    if (_fitnessGoal == 'Perder peso') {
      targetCalories = tdee - 400;
    } else if (_fitnessGoal == 'Ganar músculo') {
      targetCalories = tdee + 300;
    }
    if (targetCalories < 1200) targetCalories = 1200;

    // 4. Distribución de macros.
    final macros = CalorieCalculator.distributeMacros(
      targetCalories: targetCalories,
      weightKg: weight,
      fitnessGoal: _fitnessGoal,
    );

    setState(() {
      _calories = macros['calories']!;
      _proteins = macros['proteins']!;
      _carbs = macros['carbs']!;
      _fats = macros['fats']!;
    });
  }

  // ============== VALIDACIÓN ==============

  bool _essentialsValid() {
    return _ageController.text.isNotEmpty &&
        _heightController.text.isNotEmpty &&
        _weightController.text.isNotEmpty;
  }

  bool _customGoalValid() {
    return !(_fitnessGoal == 'Otro/Personalizado' &&
        _customGoalController.text.trim().isEmpty);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ============== GUARDADO (todos los pasos escriben el mismo doc) ==============

  /// Construye el `NutritionPlan` del paso 3 (o null si está desactivado).
  NutritionPlan? _buildExtremePlan() {
    if (!_extremeChatEnabled) return null;
    List<String> split(TextEditingController c) => c.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return NutritionPlan(
      phase: PlanPhase.fromString(_extremePhase),
      durationWeeks: _extremeDurationWeeks,
      schedule: MealSchedule(
        mealsPerDay: _extremeMealsPerDay,
        intermittentFasting: _extremeIntermittentFasting,
        fastingHours: _extremeIntermittentFasting ? _extremeFastingHours : 0,
      ),
      context: NutritionContext(
        medicalConditions: split(_medicalConditionsController),
        dietaryPreferences: split(_dietaryPreferencesController),
        mustHaveFoods: split(_mustHaveFoodsController),
        aversions: split(_aversionsController),
      ),
    );
  }

  Future<void> _saveProfile({NutritionPlan? plan}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      final doc = await _firebaseService.db.collection('users').doc(user.uid).get();
      final username = doc.data()?['username'] as String? ?? 'Usuario';

      // Mantener activityLevel legacy para no romper lecturas existentes.
      final legacyActivity = _dailyLifestyle == 'activo' ? 'Activo' : 'Sedentario';

      // La meta calórica SIEMPRE sale del objetivo (cálculo clásico); el plan
      // nutricional es opcional y solo estructura las comidas (no toca macros).
      final calories = _calories;
      final proteins = _proteins;
      final carbs = _carbs;
      final fats = _fats;

      final userContext = UserContext(
        uid: user.uid,
        username: username,
        gender: _gender,
        age: int.tryParse(_ageController.text) ?? 25,
        weight: double.tryParse(_weightController.text) ?? 70.0,
        height: double.tryParse(_heightController.text) ?? 170.0,
        activityLevel: legacyActivity,
        customActivityDescription: null,
        fitnessGoal: _fitnessGoal,
        customGoalDescription:
            _fitnessGoal == 'Otro/Personalizado' ? _customGoalController.text.trim() : null,
        macroGoals: {
          'calories': calories,
          'proteins': proteins,
          'carbs': carbs,
          'fats': fats,
        },
        bodyFatPercent: _currentBodyFatPercent,
        bodyFatMethod: _bodyFatMethod,
        neckCircumference: double.tryParse(_neckController.text),
        waistCircumference: double.tryParse(_waistController.text),
        hipCircumference: double.tryParse(_hipController.text),
        dailyLifestyle: _dailyLifestyle,
        trainingActivity: _trainingActivity,
        weeklyTrainingMinutes: _weeklyTrainingMinutes.round(),
        bmrFormula: _bmrFormulaUsed,
        catName: _catNameController.text.trim().isEmpty ? 'Mochi' : _catNameController.text.trim(),
        catStyle: _catStyle,
        petType: _petType,
      );

      await _firebaseService.db.collection('users').doc(user.uid).set(
        userContext.toMap(),
        SetOptions(merge: true),
      );

      if (plan != null) {
        await NutritionPlanService.instance.savePlan(
          uid: user.uid,
          phase: plan.phase,
          durationWeeks: plan.durationWeeks,
          schedule: plan.schedule,
          context: plan.context,
        );
      }

      // Navegamos primero (el perfil ya es "completo") y después refrescamos
      // el auth-gate para que el estado reactivo quede al día sin depender
      // de un nuevo cambio de sesión.
      if (!mounted) return;
      final authGate = ref.read(authGateProvider.notifier);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
      await authGate.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).saveProfileError('$e')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onPrimaryFromEssentials() {
    final l10n = AppLocalizations.of(context);
    if (!_essentialsValid()) {
      _showSnack(l10n.snackEssentials);
      return;
    }
    if (!_customGoalValid()) {
      _showSnack(l10n.snackCustomGoal);
      return;
    }
    _saveProfile();
  }

  void _onPrimaryFromPersonalize() {
    if (_bodyFatMethod == 'us_navy' && _bodyFatNavyValue == null) {
      _showSnack(AppLocalizations.of(context).snackMeasures);
      return;
    }
    // Paso 2 termina en el paso 3 (personalización extrema), que es opcional.
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPrimaryFromExtreme() {
    _saveProfile(plan: _buildExtremePlan());
  }

  void _skipExtreme() {
    _saveProfile(); // Sin plan: el usuario entra al flujo clásico.
  }

  // ============== NAVEGACIÓN ENTRE PASOS ==============

  void _goToPersonalize() {
    final l10n = AppLocalizations.of(context);
    if (!_essentialsValid()) {
      _showSnack(l10n.snackEssentials);
      return;
    }
    if (!_customGoalValid()) {
      _showSnack(l10n.snackCustomGoal);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ============== INDICADOR DE PASOS ==============

  Widget _buildStepIndicator() {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.stepEssential, l10n.stepPersonalize, l10n.stepExtreme];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _stepPill(i, labels[i]),
        ],
      ],
    );
  }

  Widget _stepPill(int index, String label) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final active = index == _currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? nk.amber : nk.border,
        ),
      ),
      child: Text(
        label,
        style: _mono(nk,
            size: 11,
            weight: FontWeight.w700,
            letterSpacing: 0.4,
            color: active
                ? (isDark ? const Color(0xFF1A1206) : Colors.white)
                : nk.textDim),
      ),
    );
  }

  // ============== PASO 1: LO ESENCIAL ==============

  Widget _buildEssentialsStep() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.essentialsTitle,
            style: _display(nk, size: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.essentialsBody,
            style: _sans(nk, size: 13, color: nk.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _genderCard('Femenino', l10n.genderFemale, Icons.female),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _genderCard('Masculino', l10n.genderMale, Icons.male),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _input(_ageController, l10n.ageField, Icons.cake_outlined,
              onChanged: (_) => _calculateMacros()),
          const SizedBox(height: 16),
          _input(_heightController, l10n.heightField, Icons.height_outlined,
              onChanged: (_) => _calculateMacros()),
          const SizedBox(height: 16),
          _input(_weightController, l10n.weightField, Icons.monitor_weight_outlined,
              onChanged: (_) => _calculateMacros()),
          const SizedBox(height: 28),
          Text(
            l10n.goalQuestion,
            style: _display(nk, size: 15),
          ),
          const SizedBox(height: 12),
          ..._buildGoalCards(),
          if (_fitnessGoal == 'Otro/Personalizado') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customGoalController,
              style: _sans(nk, size: 15),
              decoration: InputDecoration(
                labelText: l10n.customGoalLabel,
                labelStyle: _sans(nk, size: 14, color: nk.textDim),
                filled: true,
                fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: nk.amber),
                ),
                hintText: l10n.customGoalHint,
                hintStyle: _sans(nk, size: 13, color: nk.textFaint),
              ),
            ),
          ],
          const SizedBox(height: 28),
          _buildLiveMacroPreview(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _buildGoalCards() {
    final l10n = AppLocalizations.of(context);
    final goals = [
      (
        value: 'Perder peso',
        title: l10n.goalLoseWeight,
        desc: l10n.goalLoseWeightDesc,
      ),
      (
        value: 'Mantener peso',
        title: l10n.goalMaintainWeight,
        desc: l10n.goalMaintainWeightDesc,
      ),
      (
        value: 'Ganar músculo',
        title: l10n.goalGainMuscle,
        desc: l10n.goalGainMuscleDesc,
      ),
      (
        value: 'Otro/Personalizado',
        title: l10n.goalCustom,
        desc: l10n.goalCustomDesc,
      ),
    ];
    final nk = context.nk;
    return goals.map((g) {
      final selected = _fitnessGoal == g.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => setState(() {
            _fitnessGoal = g.value;
            _calculateMacros();
          }),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? nk.amber.withValues(alpha: 0.12)
                  : nk.surfaceHigh.withValues(alpha: 0.5),
              border: Border.all(
                color: selected ? nk.amber : nk.border,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: selected ? nk.amber : nk.textFaint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: selected ? nk.amber : nk.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        g.desc,
                        style: TextStyle(fontSize: 11, color: nk.textDim),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildLiveMacroPreview() {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            // Gradiente solo en dark; en claro, tinte plano + borde (lite).
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFFFFB37A), Color(0xFF8A5E30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? null : nk.cat.withValues(alpha: 0.15),
            border: isDark
                ? null
                : Border.all(color: nk.cat.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                l10n.recommendedDailyCalories,
                style: _mono(nk,
                    size: 12,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: const Color(0xFF1A0F00)),
              ),
              const SizedBox(height: 4),
              Text(
                '${_calories.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  color: const Color(0xFF1A0F00),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.bmrFormula(
                  _bmrFormulaUsed == 'katch'
                      ? l10n.bmrFormulaKatch
                      : l10n.bmrFormulaMifflin,
                ),
                style: _mono(nk,
                    size: 10,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: const Color(0xFF1A0F00)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                  l10n.macroCarbs, '${_carbs.toStringAsFixed(0)}g', nk.carbs),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMacroCard(
                  l10n.macroProteins, '${_proteins.toStringAsFixed(0)}g', nk.protein),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMacroCard(
                  l10n.macroFats, '${_fats.toStringAsFixed(0)}g', nk.fat),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroCard(String name, String value, Color color) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.5),
        border: Border.all(color: nk.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(name,
              style: TextStyle(color: nk.textDim, fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============== PASO 2: PERSONALIZA TU PLAN ==============

  Widget _buildPersonalizeStep() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.personalizeTitle,
            style: _display(nk, size: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.personalizeBody,
            style: _sans(nk, size: 13, color: nk.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Text(
            l10n.bodyFatSection,
            style: _display(nk, size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.bodyFatSectionHint,
            style: _sans(nk, size: 12, color: nk.textDim),
          ),
          const SizedBox(height: 12),
          _buildBodyFatSection(),
          const SizedBox(height: 28),
          Text(
            l10n.lifestyleSection,
            style: _display(nk, size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.lifestyleSectionHint,
            style: _sans(nk, size: 12, color: nk.textDim),
          ),
          const SizedBox(height: 12),
          _buildLifestyleSection(),
          const SizedBox(height: 28),
          Text(
            l10n.trainingSection,
            style: _display(nk, size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.trainingSectionHint,
            style: _sans(nk, size: 12, color: nk.textDim),
          ),
          const SizedBox(height: 12),
          _buildTrainingSection(),
          const SizedBox(height: 28),
          Text(
            l10n.petSection,
            style: _display(nk, size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.petSectionHint,
            style: _sans(nk, size: 12, color: nk.textDim),
          ),
          const SizedBox(height: 12),
          _buildMascotSection(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ----- Paso 3: Personalización extrema (opcional) -----

  Widget _buildExtremeStep() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.extremeTitle,
            style: _display(nk, size: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.extremeBody,
            style: _sans(nk, size: 13, color: nk.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _extremeEnableCard(l10n),
          if (_extremeChatEnabled) ...[
            const SizedBox(height: 28),
            Text(l10n.extremePhaseLabel, style: _display(nk, size: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _extremeChip('cut', l10n.extremePhaseCut),
                _extremeChip('maintenance', l10n.extremePhaseMaintain),
                _extremeChip('lean_gain', l10n.extremePhaseGain),
                _extremeChip('recomposition', l10n.extremePhaseRecomp),
              ],
            ),
            const SizedBox(height: 28),
            Text(l10n.extremeDurationLabel, style: _display(nk, size: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _extremeChipDuration(4),
                _extremeChipDuration(8),
                _extremeChipDuration(12),
              ],
            ),
            const SizedBox(height: 28),
            Text(l10n.extremeMealsLabel, style: _display(nk, size: 15)),
            const SizedBox(height: 4),
            Text(
              l10n.extremeMealsHint,
              style: _sans(nk, size: 12, color: nk.textDim),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _extremeChipMeals(3),
                _extremeChipMeals(4),
                _extremeChipMeals(5),
              ],
            ),
            const SizedBox(height: 28),
            _extremeIfCard(l10n, nk),
            const SizedBox(height: 28),
            Text(l10n.extremeContextLabel, style: _display(nk, size: 15)),
            const SizedBox(height: 4),
            Text(
              l10n.extremeContextHint,
              style: _sans(nk, size: 12, color: nk.textDim),
            ),
            const SizedBox(height: 12),
            _input(
              _medicalConditionsController,
              l10n.extremeMedicalLabel,
              Icons.medical_information_outlined,
              keyboardType: TextInputType.text,
              onChanged: (_) {},
            ),
            const SizedBox(height: 8),
            Text(
              l10n.extremeMedicalHint,
              style: _sans(nk, size: 11, color: nk.textDim),
            ),
            const SizedBox(height: 16),
            _input(
              _dietaryPreferencesController,
              l10n.extremeDietLabel,
              Icons.eco_outlined,
              keyboardType: TextInputType.text,
              onChanged: (_) {},
            ),
            const SizedBox(height: 8),
            Text(
              l10n.extremeDietHint,
              style: _sans(nk, size: 11, color: nk.textDim),
            ),
            const SizedBox(height: 16),
            _input(
              _mustHaveFoodsController,
              l10n.extremeMustHaveLabel,
              Icons.favorite_border,
              keyboardType: TextInputType.text,
              onChanged: (_) {},
            ),
            const SizedBox(height: 8),
            Text(
              l10n.extremeMustHaveHint,
              style: _sans(nk, size: 11, color: nk.textDim),
            ),
            const SizedBox(height: 16),
            _input(
              _aversionsController,
              l10n.extremeAversionsLabel,
              Icons.block,
              keyboardType: TextInputType.text,
              onChanged: (_) {},
            ),
            const SizedBox(height: 8),
            Text(
              l10n.extremeAversionsHint,
              style: _sans(nk, size: 11, color: nk.textDim),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: nk.surfaceHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: nk.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, color: nk.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.extremeNotice,
                      style: _sans(nk, size: 12, color: nk.textDim),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _extremeEnableCard(AppLocalizations l10n) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _extremeChatEnabled ? nk.amber : nk.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.extremeEnableLabel, style: _display(nk, size: 14)),
                const SizedBox(height: 4),
                Text(
                  l10n.extremeEnableDesc,
                  style: _sans(nk, size: 12, color: nk.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _extremeChatEnabled,
            activeThumbColor: nk.amber,
            onChanged: (v) => setState(() => _extremeChatEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _extremeChip(String value, String label) {
    final nk = context.nk;
    final selected = _extremePhase == value;
    return GestureDetector(
      onTap: () => setState(() {
        _extremePhase = value;
        _extremePhaseTouched = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(
          label,
          style: _mono(
            nk,
            size: 12,
            weight: FontWeight.w600,
            color: selected
                ? (nk.mode == NekoThemeMode.dark ? const Color(0xFF1A1206) : Colors.white)
                : nk.textDim,
          ),
        ),
      ),
    );
  }

  Widget _extremeChipDuration(int weeks) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final selected = _extremeDurationWeeks == weeks;
    final label = switch (weeks) {
      4 => l10n.extremeW4,
      12 => l10n.extremeW12,
      _ => l10n.extremeW8,
    };
    return GestureDetector(
      onTap: () => setState(() => _extremeDurationWeeks = weeks),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(
          label,
          style: _mono(
            nk,
            size: 12,
            weight: FontWeight.w600,
            color: selected
                ? (nk.mode == NekoThemeMode.dark ? const Color(0xFF1A1206) : Colors.white)
                : nk.textDim,
          ),
        ),
      ),
    );
  }

  Widget _extremeChipMeals(int meals) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final selected = _extremeMealsPerDay == meals;
    final label = switch (meals) {
      3 => l10n.extremeMeals3,
      5 => l10n.extremeMeals5,
      _ => l10n.extremeMeals4,
    };
    return GestureDetector(
      onTap: () => setState(() => _extremeMealsPerDay = meals),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(
          label,
          style: _mono(
            nk,
            size: 12,
            weight: FontWeight.w600,
            color: selected
                ? (nk.mode == NekoThemeMode.dark ? const Color(0xFF1A1206) : Colors.white)
                : nk.textDim,
          ),
        ),
      ),
    );
  }

  Widget _extremeIfCard(AppLocalizations l10n, NekoColors nk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.extremeIfLabel, style: _display(nk, size: 14)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.extremeIfDesc,
                    style: _sans(nk, size: 12, color: nk.textDim),
                  ),
                ],
              ),
            ),
            Switch(
              value: _extremeIntermittentFasting,
              activeThumbColor: nk.amber,
              onChanged: (v) => setState(() => _extremeIntermittentFasting = v),
            ),
          ],
        ),
        if (_extremeIntermittentFasting) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _extremeIfHourChip(16, l10n.extremeIf16),
              _extremeIfHourChip(18, l10n.extremeIf18),
            ],
          ),
        ],
      ],
    );
  }

  Widget _extremeIfHourChip(int hours, String label) {
    final nk = context.nk;
    final selected = _extremeFastingHours == hours;
    return GestureDetector(
      onTap: () => setState(() => _extremeFastingHours = hours),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(
          label,
          style: _mono(
            nk,
            size: 12,
            weight: FontWeight.w600,
            color: selected
                ? (nk.mode == NekoThemeMode.dark ? const Color(0xFF1A1206) : Colors.white)
                : nk.textDim,
          ),
        ),
      ),
    );
  }

  // ----- Sección: % de grasa -----

  Widget _buildBodyFatSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _methodCard(
                'visual',
                l10n.methodVisualTitle,
                l10n.methodVisualDesc,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _methodCard(
                'us_navy',
                l10n.methodNavyTitle,
                l10n.methodNavyDesc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_bodyFatMethod == 'visual') _buildBodyFatVisual() else _buildBodyFatNavy(),
      ],
    );
  }

  Widget _methodCard(String key, String title, String subtitle) {
    final nk = context.nk;
    final selected = _bodyFatMethod == key;
    return GestureDetector(
      onTap: () => setState(() {
        _bodyFatMethod = key;
        if (key == 'us_navy') _recalculateNavyFromInputs();
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? nk.cat.withValues(alpha: 0.12)
              : nk.surfaceHigh.withValues(alpha: 0.5),
          border: Border.all(
            color: selected ? nk.cat : nk.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? nk.cat : nk.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: nk.textDim),
            ),
          ],
        ),
      ),
    );
  }

  // Opción 1: Visual
  Widget _buildBodyFatVisual() {
    final ranges = _isMale ? BodyFatRange.maleRanges : BodyFatRange.femaleRanges;
    final activeRange = ranges.firstWhere(
      (r) => _bodyFatVisual >= r.min && _bodyFatVisual <= r.max,
      orElse: () => ranges.last,
    );

    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            // Gradiente solo en dark; en claro, tinte plano + borde (lite).
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFFFFB37A), Color(0xFF8A5E30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? null : nk.cat.withValues(alpha: 0.15),
            border: isDark
                ? null
                : Border.all(color: nk.cat.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                l10n.myBodyFatEstimated,
                style: _mono(nk,
                    size: 12,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: const Color(0xFF1A0F00)),
              ),
              const SizedBox(height: 4),
              Text(
                '${_bodyFatVisual.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: const Color(0xFF1A0F00),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                activeRange.label,
                style: TextStyle(
                  color: const Color(0xFF1A0F00),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: nk.cat,
            inactiveTrackColor: nk.surfaceHigh,
            thumbColor: nk.cat,
            overlayColor: nk.cat.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: _bodyFatVisual,
            min: (_isMale ? 5 : 12).toDouble(),
            max: (_isMale ? 40 : 50).toDouble(),
            divisions: (_isMale ? 35 : 38),
            label: '${_bodyFatVisual.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _bodyFatVisual = v.roundToDouble()),
          ),
        ),
        const SizedBox(height: 12),
        ...ranges.map((r) {
          final isActive = r.key == activeRange.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setState(() => _bodyFatVisual = r.recommended.toDouble()),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive
                      ? nk.cat.withValues(alpha: 0.08)
                      : nk.surfaceHigh.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isActive ? nk.cat : nk.border,
                    width: isActive ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _silhouetteIcon(isActive, r.key),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? nk.cat : nk.text,
                                ),
                              ),
                              Text(
                                '${r.min}–${r.max}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? nk.cat : nk.textDim,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.description,
                            style: TextStyle(fontSize: 11, color: nk.textDim),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// "Icono" de silueta construido con Containers apilados.
  /// No usamos un asset para evitar binarios en el repo.
  Widget _silhouetteIcon(bool active, String rangeKey) {
    final nk = context.nk;
    final fillColor = active ? nk.cat : nk.textFaint;
    final widths = {
      'competition': 18.0,
      'athletic': 22.0,
      'average_low': 26.0,
      'average_high': 30.0,
      'overweight': 34.0,
    };
    final w = widths[rangeKey] ?? 24.0;
    return SizedBox(
      width: 44,
      height: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fillColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: w,
            height: 20,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Opción 2: US Navy
  Widget _buildBodyFatNavy() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final value = _bodyFatNavyValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: nk.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: nk.cat.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                l10n.navyCalculated,
                style: TextStyle(color: nk.textDim, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value == null ? '--%' : '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: value == null ? nk.textFaint : nk.cat,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              if (value == null) ...[
                const SizedBox(height: 4),
                Text(
                  _isMale ? l10n.navyHintMale : l10n.navyHintFemale,
                  style: TextStyle(color: nk.textFaint, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _input(_neckController, l10n.neckField, Icons.accessibility_new),
        const SizedBox(height: 12),
        _input(_waistController, l10n.waistField, Icons.straighten),
        if (!_isMale) ...[
          const SizedBox(height: 12),
          _input(_hipController, l10n.hipField, Icons.straighten),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: _recalculateNavyFromInputs,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: nk.cat, width: 1.5),
              foregroundColor: nk.cat,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              l10n.calculate,
              style: TextStyle(
                color: nk.cat,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----- Sección: estilo de vida -----

  Widget _buildLifestyleSection() {
    final l10n = AppLocalizations.of(context);
    final lifestyles = [
      (
        key: 'sedentario',
        title: l10n.lifestyleSedentary,
        desc: l10n.lifestyleSedentaryDesc,
        mult: 'x1.2',
        emoji: 'h',
      ),
      (
        key: 'activo',
        title: l10n.lifestyleActive,
        desc: l10n.lifestyleActiveDesc,
        mult: 'x1.4',
        emoji: 'H',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lifestyles.map((l) {
        final nk = context.nk;
        final selected = _dailyLifestyle == l.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => setState(() {
              _dailyLifestyle = l.key;
              _calculateMacros();
            }),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? nk.cat.withValues(alpha: 0.12)
                    : nk.surfaceHigh.withValues(alpha: 0.5),
                border: Border.all(
                  color: selected ? nk.cat : nk.border,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? nk.cat.withValues(alpha: 0.25)
                          : nk.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l.emoji,
                      style: _mono(nk,
                          size: 24,
                          weight: FontWeight.w900,
                          color: selected ? nk.cat : nk.textDim),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: selected ? nk.cat : nk.text,
                              ),
                            ),
                            Text(
                              l.mult,
                              style: _mono(nk,
                                  size: 13,
                                  weight: FontWeight.w800,
                                  color: selected ? nk.cat : nk.textDim),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.desc,
                          style: TextStyle(fontSize: 12, color: nk.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ----- Sección: entrenamiento -----

  Widget _buildTrainingSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final weeklyKcal = CalorieCalculator.weeklyTrainingKcal(
      activityKey: _trainingActivity,
      minutesPerWeek: _weeklyTrainingMinutes.round(),
    );
    final dailyKcal = weeklyKcal / 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.trainingActivityLabel,
          style: TextStyle(
              color: nk.textDim, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ActivityMetFactors.labels.map((key) {
            final selected = _trainingActivity == key;
            return GestureDetector(
              onTap: () => setState(() {
                _trainingActivity = key;
                _calculateMacros();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? nk.cat.withValues(alpha: 0.15)
                      : nk.surfaceHigh.withValues(alpha: 0.5),
                  border: Border.all(
                    color: selected ? nk.cat : nk.border,
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ActivityMetFactors.displayName(key),
                  style: TextStyle(
                    color: selected ? nk.cat : nk.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: nk.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: nk.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.weeklyMinutes,
                    style: TextStyle(color: nk.textDim, fontSize: 12),
                  ),
                  Text(
                    l10n.minPerWeek(_weeklyTrainingMinutes.round()),
                    style: _mono(nk,
                        size: 18, weight: FontWeight.w800, color: nk.text),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: nk.cat,
                  inactiveTrackColor: nk.surfaceHigh,
                  thumbColor: nk.cat,
                  overlayColor: nk.cat.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _weeklyTrainingMinutes,
                  min: 0,
                  max: 600,
                  divisions: 60,
                  label: l10n.minShort(_weeklyTrainingMinutes.round()),
                  onChanged: (v) {
                    setState(() => _weeklyTrainingMinutes = v);
                    _calculateMacros();
                  },
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: nk.cat.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: nk.cat.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.trainingKcalPerDay,
                      style: TextStyle(
                        color: nk.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${dailyKcal.toStringAsFixed(0)} kcal',
                      style: _mono(nk,
                          size: 16, weight: FontWeight.w800, color: nk.cat),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----- Sección: mascota -----

  Widget _buildMascotSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NekoCatMascot(
          size: 120,
          showLabel: false,
          imagePath: petAssetPath(_petType),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.chooseYourPet,
          style: _display(nk, size: 15),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _petCard('gato', l10n.petCat)),
            const SizedBox(width: 12),
            Expanded(child: _petCard('perro1', l10n.petDog1)),
            const SizedBox(width: 12),
            Expanded(child: _petCard('perro2', l10n.petDog2)),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _catNameController,
          maxLength: 12,
          inputFormatters: [LengthLimitingTextInputFormatter(12)],
          style: TextStyle(
              color: nk.text, fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: l10n.petNameLabel,
            labelStyle: TextStyle(color: nk.cat),
            hintText: l10n.petNameHint,
            hintStyle: TextStyle(color: nk.textFaint),
            prefixIcon: Icon(Icons.pets_rounded, color: nk.cat),
            counterStyle: TextStyle(color: nk.textFaint),
            filled: true,
            fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: nk.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: nk.cat, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _petCard(String type, String label) {
    final nk = context.nk;
    final selected = _petType == type;
    return GestureDetector(
      onTap: () => setState(() => _petType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? nk.amber.withValues(alpha: 0.15)
              : nk.surfaceHigh.withValues(alpha: 0.5),
          border: Border.all(
            color: selected ? nk.amber : nk.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: ClipOval(
                child: Image.asset(
                  petAssetPath(type),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? nk.amber : nk.textDim,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderCard(String value, String label, IconData icon) {
    final nk = context.nk;
    final selected = (_gender == value);
    return GestureDetector(
      onTap: () => setState(() {
        _gender = label;
        _calculateMacros();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? nk.amber.withValues(alpha: 0.15)
              : nk.surfaceHigh.withValues(alpha: 0.5),
          border: Border.all(
            color: selected ? nk.amber : nk.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: selected ? nk.amber : nk.textDim),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  color: selected ? nk.amber : nk.textDim,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c, String label, IconData icon,
    {ValueChanged<String>? onChanged,
    TextInputType keyboardType = TextInputType.number}) {
    final nk = context.nk;
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: _sans(nk, size: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _sans(nk, size: 14, color: nk.textDim),
        prefixIcon: Icon(icon, color: nk.textDim),
        filled: true,
        fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ============== PIE CON ACCIONES ==============

  Widget _buildFooter() {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    if (_currentStep == 0) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _goToPersonalize,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: nk.textDim,
                side: BorderSide(color: nk.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(l10n.customizeButton),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onPrimaryFromEssentials,
              style: ElevatedButton.styleFrom(
                backgroundColor: nk.amber,
                foregroundColor: isDark
                    ? const Color(0xFF1A1206)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              isDark ? const Color(0xFF1A1206) : Colors.white),
                    )
                  : Text(
                      l10n.saveAndStart,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF1A1206)
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: _isLoading ? null : _goBack,
          child: Text(
            l10n.back,
            style: _sans(nk, size: 15, color: nk.textDim),
          ),
        ),
        const Spacer(),
        if (_currentStep == 1) ...[
          ElevatedButton(
            onPressed: _isLoading ? null : _onPrimaryFromPersonalize,
            style: ElevatedButton.styleFrom(
              backgroundColor: nk.amber,
              foregroundColor: isDark ? const Color(0xFF1A1206) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              l10n.stepExtremeContinue,
              style: TextStyle(
                color: isDark ? const Color(0xFF1A1206) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        if (_currentStep == 2) ...[
          TextButton(
            onPressed: _isLoading ? null : _skipExtreme,
            child: Text(
              l10n.stepExtremeSkip,
              style: _sans(nk, size: 15, color: nk.textDim),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _onPrimaryFromExtreme,
            style: ElevatedButton.styleFrom(
              backgroundColor: nk.amber,
              foregroundColor: isDark ? const Color(0xFF1A1206) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? const Color(0xFF1A1206) : Colors.white),
                  )
                : Text(
                    l10n.saveAndStart,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF1A1206) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  // ============== BUILD ==============

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildStepIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                    // Al llegar al paso del plan, alinear la fase por defecto
                    // con el objetivo elegido si el usuario no la tocó aún.
                    if (index == 2 && !_extremePhaseTouched) {
                      _extremePhase = switch (_fitnessGoal) {
                        'Perder peso' => 'cut',
                        'Ganar músculo' => 'lean_gain',
                        _ => 'maintenance',
                      };
                    }
                  });
                },
                children: [
                  _buildEssentialsStep(),
                  _buildPersonalizeStep(),
                  _buildExtremeStep(),
                ],
              ),
            ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers tipográficos
// ═════════════════════════════════════════════════════════════════════════════

TextStyle _display(NekoColors nk,
        {double size = 22, FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.text,
      letterSpacing: -0.02 * size,
    );

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
}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.text,
    );
