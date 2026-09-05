import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/nutrition_plan.dart';
import 'firebase_service.dart';
import 'weekly_plan_service.dart';

/// Servicio de planes nutricionales.
///
///   • Persistencia: `users/{uid}/plans/{id}` (solo lectura/escritura del dueño
///     con perfil completo, ver firestore.rules).
///   • Rol: el plan es OPCIONAL y actúa como guía de comidas. Estructura las
///     tomas (cuántas comidas, ayuno, contexto de salud) para el plan semanal
///     con IA. NUNCA modifica `macroGoals` ni `fitnessGoal`: la única fuente de
///     las calorías es el cálculo clásico (TDEE + objetivo del usuario).
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

  /// Crea un plan nuevo o actualiza el activo (mismo [planId]).
  ///
  /// No toca `macroGoals` ni `fitnessGoal`: el objetivo del usuario es la única
  /// fuente de las calorías; el plan solo define la forma de las comidas.
  /// Al cambiar la guía (tomas/ayuno/contexto) se invalida el caché del plan
  /// semanal para que la IA lo regenere con la nueva forma.
  Future<void> saveOrUpdatePlan({
    required String uid,
    required PlanPhase phase,
    required int durationWeeks,
    required MealSchedule schedule,
    NutritionContext context = const NutritionContext(),
    String? planId,
  }) async {
    final start = DateTime.now();
    final plan = NutritionPlan(
      id: planId,
      phase: phase,
      durationWeeks: durationWeeks,
      startDate: start,
      endDate: start.add(Duration(days: 7 * durationWeeks)),
      schedule: schedule,
      context: context,
      createdAt: DateTime.now(),
    );

    final ref = FirebaseService.instance.db
        .collection('users')
        .doc(uid)
        .collection('plans');
    if (planId != null) {
      await ref.doc(planId).set(plan.toMap(), SetOptions(merge: true));
    } else {
      await ref.add(plan.toMap());
    }
    await WeeklyPlanService.instance.clearCache(uid);
  }

  /// Elimina el plan activo (el usuario vuelve al flujo clásico, guiándose
  /// solo por su objetivo). No altera `macroGoals` ni `fitnessGoal` e invalida
  /// el caché del plan semanal.
  Future<void> clearPlan({required String uid}) async {
    final snap = await FirebaseService.instance.db
        .collection('users')
        .doc(uid)
        .collection('plans')
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    await WeeklyPlanService.instance.clearCache(uid);
  }

  /// Describe la transición recomendada al vencer el plan (para mostrarla y
  /// que el usuario la confirme antes de recalcular).
  PlanPhase projectedNextPhase(NutritionPlan? plan) => plan?.nextPhase ?? PlanPhase.maintenance;

  /// Al vencer el plan y tras la aprobación del usuario, crea la siguiente
  /// fase conservando la forma de comidas ([MealSchedule]) y el contexto del
  /// plan anterior. No reescribe macros ni objetivo.
  Future<void> transitionToPhase({
    required String uid,
    required PlanPhase phase,
    NutritionPlan? current,
  }) async {
    await savePlan(
      uid: uid,
      phase: phase,
      durationWeeks: current?.durationWeeks ?? 8,
      schedule: current?.schedule ?? const MealSchedule(),
      context: current?.context ?? const NutritionContext(),
    );
    await WeeklyPlanService.instance.clearCache(uid);
  }
}