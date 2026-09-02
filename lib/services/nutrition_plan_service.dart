import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/calorie_calculator.dart';
import '../models/nutrition_plan.dart';
import '../models/user_context.dart';
import 'firebase_service.dart';

/// Resultado de aplicar una fase a la meta calórica.
class PhaseMacroTarget {
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;
  final String phase;

  const PhaseMacroTarget({
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.phase,
  });

  Map<String, double> toMacroGoals() =>
      {'calories': calories, 'proteins': proteins, 'carbs': carbs, 'fats': fats};
}

/// Servicio de planes nutricionales.
///
///   • Persistencia: `users/{uid}/plans/{id}` (solo lectura/escritura del dueño
///     con perfil completo, ver firestore.rules).
///   • Cálculo: deriva la meta calórica/macros de una fase desde el TDEE del
///     usuario, escalando el déficit/superávit por el plazo del plan.
///   • Ciclo de vida: detecta planes vencidos y proyecta la fase de transición
///     recomendada («aviso + aprobación»), sin cambiar nada en secreto.
class NutritionPlanService {
  NutritionPlanService._();
  static final NutritionPlanService instance = NutritionPlanService._();

  /// Lee el plan activo (el más reciente) del usuario, o null si no tiene.
  Future<NutritionPlan?> activePlan(String uid) async {
    final snap = await FirebaseService.instance.db
        .collection('users')
        .doc(uid)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return NutritionPlan.fromMap(
      Map<String, dynamic>.from(snap.docs.first.data()),
      id: snap.docs.first.id,
    );
  }

  /// Guarda (crea) un plan en la subcolección del usuario. Devuelve el id.
  Future<String> savePlan({
    required String uid,
    required PlanPhase phase,
    required int durationWeeks,
    required MealSchedule schedule,
    NutritionContext context = const NutritionContext(),
    DateTime? startDate,
  }) async {
    final start = startDate ?? DateTime.now();
    final plan = NutritionPlan(
      phase: phase,
      durationWeeks: durationWeeks,
      startDate: start,
      endDate: start.add(Duration(days: 7 * durationWeeks)),
      schedule: schedule,
      context: context,
      createdAt: DateTime.now(),
    );
    final ref = await FirebaseService.instance.db
        .collection('users')
        .doc(uid)
        .collection('plans')
        .add(plan.toMap());
    return ref.id;
  }

  /// Aplica la fase del plan a las métricas del usuario para obtener la meta
  /// de calorías y macronutrientes. Si [plan] es nulo calcula con el objetivo
  /// legacy (`fitnessGoal` + ajustes fijos -400/+300).
  PhaseMacroTarget computeTarget({
    required UserContext user,
    required NutritionPlan? plan,
  }) {
    final bmr = CalorieCalculator.calculateBmr(
      weightKg: user.weight,
      heightCm: user.height,
      age: user.age,
      isMale: user.gender == 'Masculino',
      bodyFatPercent: user.bodyFatPercent,
    );
    final tdee = CalorieCalculator.dailyTdee(
      bmr: bmr,
      lifestyle: user.dailyLifestyle,
      trainingActivityKey: user.trainingActivity,
      trainingMinutesPerWeek: user.weeklyTrainingMinutes,
    );

    final isDeficit = _goalIs(user, ['perder', 'déficit', 'deficit', 'cut']);
    final isSurplus = _goalIs(user, ['ganar', 'músculo', 'musculo', 'superávit', 'bulk']);

    final phaseName = plan?.phase.storageName ??
        (isDeficit
            ? 'cut'
            : (isSurplus ? 'lean_gain' : 'maintenance'));

    final adjustment = CalorieCalculator.caloricAdjustment(
      phase: phaseName,
      durationWeeks: plan?.durationWeeks ?? 8,
      isDeficit: isDeficit,
      isSurplus: isSurplus,
    );
    var targetCalories = (tdee + adjustment).roundToDouble();
    if (targetCalories < 1200) targetCalories = 1200;

    final recomposition = plan?.phase == PlanPhase.recomposition;
    final macros = CalorieCalculator.distributeMacros(
      targetCalories: targetCalories,
      weightKg: user.weight > 30 ? user.weight : 70.0,
      fitnessGoal: user.fitnessGoal,
      recomposition: recomposition,
    );
    return PhaseMacroTarget(
      calories: macros['calories']!,
      proteins: macros['proteins']!,
      carbs: macros['carbs']!,
      fats: macros['fats']!,
      phase: phaseName,
    );
  }

  /// Describe la transición recomendada al vencer el plan (para mostrarla y
  /// que el usuario la confirme antes de recalcular).
  PlanPhase projectedNextPhase(NutritionPlan? plan) => plan?.nextPhase ?? PlanPhase.maintenance;

  /// Si el plan ya venció, persiste los macros de mantenimiento (la fase de
  /// transición) en `users/{uid}/macroGoals` después de que el usuario lo
  /// apruebe. No se llama sin confirmación explícita.
  Future<void> transitionToPhase({
    required String uid,
    required UserContext user,
    required PlanPhase phase,
  }) async {
    final pending = NutritionPlan(
      phase: phase,
      durationWeeks: 8,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7 * 8)),
      schedule: const MealSchedule(),
    );
    final target = computeTarget(user: user, plan: pending);
    await FirebaseService.instance.db.collection('users').doc(uid).set(
      {
        'fitnessGoal': _goalForPhase(phase),
        'macroGoals': target.toMacroGoals(),
        'bmrFormula': user.bmrFormula,
      },
      SetOptions(merge: true),
    );
    await savePlan(
      uid: uid,
      phase: phase,
      durationWeeks: 8,
      schedule: const MealSchedule(),
    );
  }

  bool _goalIs(UserContext user, List<String> needles) {
    final g = user.fitnessGoal.toLowerCase();
    return needles.any(g.contains);
  }

  String _goalForPhase(PlanPhase phase) {
    switch (phase) {
      case PlanPhase.cut:
        return 'Perder peso';
      case PlanPhase.leanGain:
        return 'Ganar músculo';
      case PlanPhase.recomposition:
        return 'Recomposición';
      case PlanPhase.maintenance:
        return 'Mantener peso';
    }
  }
}