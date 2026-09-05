import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/auth_gate_controller.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../core/calorie_calculator.dart';
import '../core/providers.dart';
import '../widgets/amber_atmosphere.dart';
import '../models/user_context.dart';
import '../l10n/app_localizations.dart';
import '../services/weekly_plan_service.dart';
import '../widgets/neko_cat_mascot.dart';

/// Pantalla de edición de perfil existente.
/// Carga los datos desde Firestore, permite editarlos, recalcula macros
/// y guarda de vuelta al mismo documento.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  // Inyección de dependencias: se lee del contenedor, no del singleton.
  late final _firebaseService = ref.read(firebaseServiceProvider);
  bool _loading = true;
  bool _saving = false;

  // Controllers
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'Femenino';
  bool get _isMale => _gender == 'Masculino';

  // Body fat
  String _bodyFatMethod = 'visual';
  double _bodyFatVisual = 20.0;
  final _neckController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  double? _bodyFatNavyValue;

  // Lifestyle + training
  String _dailyLifestyle = 'sedentario';
  String _trainingActivity = 'pesas_hit';
  double _weeklyTrainingMinutes = 0;

  // Goal
  String _fitnessGoal = 'Mantener peso';
  final _customGoalController = TextEditingController();

  // Mascot
  final _catNameController = TextEditingController();
  String _petType = 'gato';

  // Calculated
  double _calories = 2000;
  double _proteins = 120;
  double _carbs = 200;
  double _fats = 65;
  String _bmrFormulaUsed = 'mifflin';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _customGoalController.dispose();
    _catNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    final doc = await _firebaseService.db.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) {
      setState(() => _loading = false);
      return;
    }

    // Mascot
    _catNameController.text = data['catName'] as String? ?? 'Mochi';
    _petType = data['petType'] ?? 'gato';

    // Basic fields
    _ageController.text = (data['age'] ?? 25).toString();
    _heightController.text = (data['height'] ?? 170.0).toString();
    _weightController.text = (data['weight'] ?? 70.0).toString();
    _gender = data['gender'] ?? 'Femenino';

    // Body fat
    _bodyFatMethod = data['bodyFatMethod'] ?? 'visual';
    _bodyFatVisual = (data['bodyFatPercent'] ?? 20.0).toDouble();
    // Clamp to valid range for the slider
    final minFat = _isMale ? 5.0 : 12.0;
    final maxFat = _isMale ? 40.0 : 50.0;
    _bodyFatVisual = _bodyFatVisual.clamp(minFat, maxFat);
    _bodyFatNavyValue = (data['bodyFatPercent'] as num?)?.toDouble();
    _neckController.text = data['neckCircumference']?.toString() ?? '';
    _waistController.text = data['waistCircumference']?.toString() ?? '';
    _hipController.text = data['hipCircumference']?.toString() ?? '';

    // Lifestyle + training
    _dailyLifestyle = data['dailyLifestyle'] ?? 'sedentario';
    _trainingActivity = data['trainingActivity'] ?? 'pesas_hit';
    _weeklyTrainingMinutes = (data['weeklyTrainingMinutes'] ?? 0).toDouble();

    // Goal. 'Recomposición' era un valor legacy escrito por la antigua lógica
    // de planes (no es un objetivo fitness válido); se normaliza para que el
    // selector y el cálculo de macros no se rompan.
    const knownGoals = ['Perder peso', 'Mantener peso', 'Ganar músculo', 'Otro/Personalizado'];
    final rawGoal = data['fitnessGoal'] ?? 'Mantener peso';
    _fitnessGoal = knownGoals.contains(rawGoal) ? rawGoal as String : 'Mantener peso';
    _customGoalController.text = data['customGoalDescription'] ?? '';

    // Existing macros
    final macros = data['macroGoals'] as Map<String, dynamic>?;
    if (macros != null) {
      _calories = (macros['calories'] ?? 2000).toDouble();
      _proteins = (macros['proteins'] ?? 120).toDouble();
      _carbs = (macros['carbs'] ?? 200).toDouble();
      _fats = (macros['fats'] ?? 65).toDouble();
    }

    _bmrFormulaUsed = data['bmrFormula'] ?? 'mifflin';

    setState(() => _loading = false);
  }

  // ── Cálculos ──

  double? get _currentBodyFatPercent {
    if (_bodyFatMethod == 'visual') return _bodyFatVisual;
    return _bodyFatNavyValue;
  }

  double? _recalcNavy() {
    final neck = double.tryParse(_neckController.text);
    final waist = double.tryParse(_waistController.text);
    final height = double.tryParse(_heightController.text);
    final hip = double.tryParse(_hipController.text);

    if (neck == null || waist == null || height == null) return null;
    if (!_isMale && (hip == null || hip <= 0)) return null;
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

    final bmrResult = CalorieCalculator.calculateBmr(
      weightKg: weight,
      heightCm: height,
      age: age,
      isMale: _isMale,
      bodyFatPercent: bodyFat,
    );
    _bmrFormulaUsed = bmrResult.formula;

    final tdee = CalorieCalculator.dailyTdee(
      bmr: bmrResult,
      lifestyle: _dailyLifestyle,
      trainingActivityKey: _trainingActivity,
      trainingMinutesPerWeek: _weeklyTrainingMinutes.round(),
    );

    double targetCalories = tdee;
    if (_fitnessGoal == 'Perder peso') {
      targetCalories = tdee - 400;
    } else if (_fitnessGoal == 'Ganar músculo') {
      targetCalories = tdee + 300;
    }
    if (targetCalories < 1200) targetCalories = 1200;

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

  // ── Guardar ──

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      final doc = await _firebaseService.db.collection('users').doc(user.uid).get();
      final username = doc.data()?['username'] as String? ?? 'Usuario';

      final legacyActivity = _dailyLifestyle == 'activo' ? 'Activo' : 'Sedentario';

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
          'calories': _calories,
          'proteins': _proteins,
          'carbs': _carbs,
          'fats': _fats,
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
        petType: _petType,
      );

      await _firebaseService.db.collection('users').doc(user.uid).set(
        userContext.toMap(),
        SetOptions(merge: true),
      );

      // El objetivo definió las calorías: el plan semanal debe regenerarse
      // para reflejar los nuevos valores en vez de servir hasta 5 días viejos.
      await WeeklyPlanService.instance.clearCache(user.uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.peditSavedSnack),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Refresca el auth-gate para que el perfil reactivo quede al día.
      final authGate = ref.read(authGateProvider.notifier);
      Navigator.of(context).pop();
      await authGate.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saveProfileError('$e')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI Builders ──

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: nk.bg,
        body: Center(child: CircularProgressIndicator(color: nk.cat)),
      );
    }

    return Scaffold(
      backgroundColor: nk.bg,
      appBar: AppBar(
        title: Text(
          l10n.profileEdit,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: nk.text,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: nk.text),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: nk.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AmberAtmosphere(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Mascota ──
            _sectionTitle(l10n.peditPetSection, nk),
            const SizedBox(height: 12),
            TextField(
              controller: _catNameController,
              maxLength: 12,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              style: TextStyle(color: nk.text, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: l10n.petNameLabel,
                labelStyle: TextStyle(color: nk.cat),
                hintText: l10n.petNameHint,
                hintStyle: TextStyle(color: nk.textFaint.withValues(alpha: 0.8)),
                prefixIcon: Icon(Icons.pets_rounded, color: nk.cat),
                counterStyle: TextStyle(color: nk.textFaint),
                filled: true,
                fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  borderSide: BorderSide(color: nk.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  borderSide: BorderSide(color: nk.cat, width: 1.5),
                ),
              ),
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

            // ── Gender ──
            Row(
              children: [
                Expanded(child: _genderCard('Femenino', l10n.genderFemale, Icons.female)),
                const SizedBox(width: 16),
                Expanded(child: _genderCard('Masculino', l10n.genderMale, Icons.male)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Basic fields ──
            _input(_ageController, l10n.ageField, Icons.cake_outlined),
            const SizedBox(height: 16),
            _input(_heightController, l10n.heightField, Icons.height_rounded),
            const SizedBox(height: 16),
            _input(_weightController, l10n.weightField, Icons.monitor_weight_outlined),
            const SizedBox(height: 32),

            // ── Body fat section ──
            _sectionTitle(l10n.bodyFatSection, nk),
            const SizedBox(height: 4),
            Text(
              l10n.bodyFatSectionHint,
              style: TextStyle(fontSize: 12, color: nk.textDim),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _methodCard('visual', l10n.methodVisualTitle)),
                const SizedBox(width: 12),
                Expanded(child: _methodCard('us_navy', l10n.methodNavyTitle)),
              ],
            ),
            const SizedBox(height: 16),
            if (_bodyFatMethod == 'visual') _buildBodyFatVisual() else _buildBodyFatNavy(),
            const SizedBox(height: 32),

            // ── Lifestyle ──
            _sectionTitle(l10n.lifestyleSection, nk),
            const SizedBox(height: 12),
            _lifestyleOption('sedentario', l10n.lifestyleSedentary, l10n.lifestyleSedentaryDesc, 'x1.2'),
            const SizedBox(height: 8),
            _lifestyleOption('activo', l10n.lifestyleActive, l10n.lifestyleActiveDesc, 'x1.4'),
            const SizedBox(height: 32),

            // ── Training ──
            _sectionTitle(l10n.trainingSection, nk),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActivityMetFactors.labels.map((key) {
                final selected = _trainingActivity == key;
                return GestureDetector(
                  onTap: () => setState(() => _trainingActivity = key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? nk.cat.withValues(alpha: 0.15)
                          : nk.surfaceHigh.withValues(alpha: 0.4),
                      border: Border.all(
                        color: selected ? nk.cat : nk.border,
                        width: selected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Text(
                      _activityDisplayName(l10n, key),
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
            const SizedBox(height: 16),
            _buildTrainingSlider(),
            const SizedBox(height: 32),

            // ── Goal ──
            _sectionTitle(l10n.peditGoalSection, nk),
            const SizedBox(height: 12),
            _goalOption('Perder peso', l10n.goalLoseWeight, l10n.goalLoseWeightDesc),
            const SizedBox(height: 8),
            _goalOption('Mantener peso', l10n.goalMaintainWeight, l10n.goalMaintainWeightDesc),
            const SizedBox(height: 8),
            _goalOption('Ganar músculo', l10n.goalGainMuscle, l10n.goalGainMuscleDesc),
            const SizedBox(height: 8),
            _goalOption('Otro/Personalizado', l10n.goalCustom, l10n.goalCustomDesc),
            if (_fitnessGoal == 'Otro/Personalizado') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customGoalController,
                style: TextStyle(color: nk.text),
                decoration: InputDecoration(
                  labelText: l10n.customGoalLabel,
                  labelStyle: TextStyle(color: nk.textDim),
                  filled: true,
                  fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    borderSide: BorderSide(color: nk.amber),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Macros preview ──
            _buildMacrosPreview(),
            const SizedBox(height: 24),

            // ── Save ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: nk.amber,
                  foregroundColor: nk.mode == NekoThemeMode.dark
                      ? const Color(0xFF1A1206)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  elevation: nk.mode == NekoThemeMode.dark ? 4 : 0,
                ),
                child: _saving
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: nk.mode == NekoThemeMode.dark
                            ? const Color(0xFF1A1206)
                            : Colors.white,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.prodSave,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: nk.mode == NekoThemeMode.dark
                                  ? const Color(0xFF1A1206)
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.check_rounded,
                              size: 20,
                              color: nk.mode == NekoThemeMode.dark
                                  ? const Color(0xFF1A1206)
                                  : Colors.white),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }

  // ── Reusable widgets ──

  Widget _sectionTitle(String text, NekoColors nk) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: nk.textFaint,
        letterSpacing: 1.5,
      ),
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
          borderRadius: BorderRadius.circular(AppRadii.card),
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
                color: selected ? nk.text : nk.textDim,
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
      onTap: () {
        setState(() {
          _gender = value;
          // Clamp body fat to valid range for new gender
          final minFat = _isMale ? 5.0 : 12.0;
          final maxFat = _isMale ? 40.0 : 50.0;
          _bodyFatVisual = _bodyFatVisual.clamp(minFat, maxFat);
        });
      },
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
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: selected ? nk.amberSoft : nk.textDim),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? nk.text : nk.textDim,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon) {
    final nk = context.nk;
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: TextStyle(color: nk.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: nk.textDim),
        prefixIcon: Icon(icon, color: nk.textDim),
        filled: true,
        fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _methodCard(String key, String title) {
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
              : nk.surfaceHigh.withValues(alpha: 0.4),
          border: Border.all(
            color: selected ? nk.cat : nk.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? nk.cat : nk.text,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _lifestyleOption(String key, String title, String desc, String mult) {
    final nk = context.nk;
    final selected = _dailyLifestyle == key;
    return GestureDetector(
      onTap: () => setState(() => _dailyLifestyle = key),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? nk.cat.withValues(alpha: 0.12)
              : nk.surfaceHigh.withValues(alpha: 0.4),
          border: Border.all(
            color: selected ? nk.cat : nk.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? nk.cat : nk.text,
                    fontSize: 14,
                  )),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 12, color: nk.textDim)),
                ],
              ),
            ),
            Text(mult, style: TextStyle(
              fontFamily: AppFonts.mono,
              fontWeight: FontWeight.w800,
              color: selected ? nk.cat : nk.textDim,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }

  Widget _goalOption(String value, String title, String desc) {
    final nk = context.nk;
    final selected = _fitnessGoal == value;
    return GestureDetector(
      onTap: () {
        setState(() => _fitnessGoal = value);
        _calculateMacros();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? nk.amber.withValues(alpha: 0.12)
              : nk.surfaceHigh.withValues(alpha: 0.4),
          border: Border.all(
            color: selected ? nk.amber : nk.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: selected ? nk.amberSoft : nk.text,
            )),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 11, color: nk.textDim)),
          ],
        ),
      ),
    );
  }

  // ── Body fat visual ──

  String _activityDisplayName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'pesas_hit':
        return l10n.peditActivityPesasHit;
      case 'pesas_moderado':
        return l10n.peditActivityPesasModerado;
      case 'correr_moderado':
        return l10n.peditActivityCorrerModerado;
      case 'correr_rapido':
        return l10n.peditActivityCorrerRapido;
      case 'caminar':
        return l10n.peditActivityCaminar;
      case 'ciclismo':
        return l10n.peditActivityCiclismo;
      default:
        return ActivityMetFactors.displayName(key);
    }
  }

  Widget _buildBodyFatVisual() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Big number
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: nk.mode == NekoThemeMode.dark
                ? const LinearGradient(
                    colors: [Color(0xFFFFB37A), Color(0xFF8A5E30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: nk.mode == NekoThemeMode.dark
                ? null
                : nk.cat.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: nk.mode == NekoThemeMode.dark
                ? null
                : Border.all(color: nk.cat.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Text(
                l10n.myBodyFatEstimated,
                style: const TextStyle(color: Color(0xFF1A0F00), fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${_bodyFatVisual.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF1A0F00),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: nk.cat,
            inactiveTrackColor: nk.border,
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
      ],
    );
  }

  // ── Body fat Navy ──

  Widget _buildBodyFatNavy() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final value = _bodyFatNavyValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: nk.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: nk.cat.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(l10n.navyCalculated,
                  style: TextStyle(color: nk.textDim, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value == null ? '--%' : '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: value == null ? nk.textFaint : nk.cat,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _input(_neckController, l10n.neckField, Icons.accessibility_new),
        const SizedBox(height: 12),
        _input(_waistController, l10n.waistField, Icons.straighten),
        if (!_isMale) ...[
          const SizedBox(height: 12),
          _input(_hipController, l10n.hipField, Icons.straighten),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: _recalculateNavyFromInputs,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: nk.cat, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
            child: Text(l10n.calculate, style: TextStyle(color: nk.cat, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Training slider ──

  Widget _buildTrainingSlider() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final dailyKcal = CalorieCalculator.weeklyTrainingKcal(
      activityKey: _trainingActivity,
      minutesPerWeek: _weeklyTrainingMinutes.round(),
    ) / 7.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.weeklyMinutes, style: TextStyle(color: nk.textDim, fontSize: 12)),
              Text(
                l10n.minPerWeek(_weeklyTrainingMinutes.round()),
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  color: nk.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: nk.cat,
              inactiveTrackColor: nk.border,
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: nk.cat.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.trainingKcalPerDay, style: TextStyle(color: nk.textDim, fontSize: 11)),
                Text(
                  '${dailyKcal.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    color: nk.cat,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Macros preview ──

  Widget _buildMacrosPreview() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: nk.mode == NekoThemeMode.dark
            ? const LinearGradient(
                colors: [Color(0xFFFFB37A), Color(0xFF8A5E30)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: nk.mode == NekoThemeMode.dark
            ? null
            : nk.cat.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: nk.mode == NekoThemeMode.dark
            ? null
            : Border.all(color: nk.cat.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            l10n.peditMacrosTitle,
            style: const TextStyle(
              color: Color(0xFF1A0F00),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_calories.toStringAsFixed(0)} kcal',
            style: const TextStyle(
              color: Color(0xFF1A0F00),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _macroLabel(l10n.profileCarbs, '${_carbs.toStringAsFixed(0)}g'),
              _macroLabel(l10n.profileProtein, '${_proteins.toStringAsFixed(0)}g'),
              _macroLabel(l10n.profileFats, '${_fats.toStringAsFixed(0)}g'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.bmrFormula(_bmrFormulaUsed == 'katch' ? l10n.bmrFormulaKatch : l10n.bmrFormulaMifflin),
            style: const TextStyle(
              color: Color(0xFF1A0F00),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLabel(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF1A0F00), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
          fontFamily: AppFonts.mono,
          color: Color(0xFF1A0F00),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        )),
      ],
    );
  }
}
