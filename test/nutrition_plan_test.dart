import 'package:flutter_test/flutter_test.dart';
import 'package:nekofit/core/calorie_calculator.dart';
import 'package:nekofit/models/nutrition_plan.dart';

void main() {
  group('MealSchedule', () {
    test('se serializa y deserializa', () {
      const s = MealSchedule(
          mealsPerDay: 5, intermittentFasting: true, fastingHours: 18);
      final back = MealSchedule.fromMap(s.toMap());
      expect(back.mealsPerDay, 5);
      expect(back.intermittentFasting, true);
      expect(back.fastingHours, 18);
    });
  });

  group('NutritionPlan', () {
    test('detecta expiración', () {
      final plan = NutritionPlan(
        phase: PlanPhase.cut,
        durationWeeks: 4,
        startDate: DateTime.now().subtract(const Duration(days: 40)),
        endDate: DateTime.now().subtract(const Duration(days: 12)),
      );
      expect(plan.hasExpired, true);
      expect(plan.daysRemaining, 0);
    });

    test('proyecta la fase de transición recomendada', () {
      expect(PlanPhase.cut.projectedNext, PlanPhase.maintenance);
      expect(PlanPhase.leanGain.projectedNext, PlanPhase.maintenance);
      expect(PlanPhase.recomposition.projectedNext, PlanPhase.maintenance);
      expect(planNext(PlanPhase.maintenance), PlanPhase.maintenance);
    });

    test('se serializa y deserializa con contexto', () {
      final plan = NutritionPlan(
        phase: PlanPhase.leanGain,
        durationWeeks: 12,
        schedule: const MealSchedule(
            mealsPerDay: 5, intermittentFasting: true, fastingHours: 16),
        context: const NutritionContext(
          medicalConditions: ['insulino-resistencia'],
          dietaryPreferences: ['sin gluten'],
          mustHaveFoods: ['arroz integral'],
          aversions: ['café'],
        ),
      );
      final back = NutritionPlan.fromMap(plan.toMap());
      expect(back.phase, PlanPhase.leanGain);
      expect(back.durationWeeks, 12);
      expect(back.schedule.mealsPerDay, 5);
      expect(back.context.medicalConditions, ['insulino-resistencia']);
      expect(back.context.aversions, ['café']);
      expect(back.context.isEmpty, false);
    });

    test('fecha de fin por defecto = start + duración', () {
      final start = DateTime(2026, 9, 1);
      final plan = NutritionPlan(
        phase: PlanPhase.maintenance,
        durationWeeks: 8,
        startDate: start,
      );
      expect(plan.endDate.difference(start).inDays, 56);
    });
  });

  group('NutritionContext', () {
    test('está vacío sin datos y no con datos', () {
      expect(const NutritionContext().isEmpty, true);
      expect(const NutritionContext(medicalConditions: ['x']).isEmpty, false);
    });
  });

  group('CalorieCalculator.mealPartitioning', () {
    test('4 comidas suma el 100% de kcal y macros', () {
      final p = CalorieCalculator.mealPartitioning(
        targetCalories: 2000,
        targetProteins: 150,
        targetCarbs: 200,
        targetFats: 67,
      );
      expect(p['Desayuno']!['calories'], 500);
      expect(p['Almuerzo']!['calories'], 700);
      expect(p['Cena']!['calories'], 500);
      final kcalSum = p.values.fold<double>(0, (a, m) => a + m['calories']!);
      expect(kcalSum, 2000);
    });

    test('3 comidas omite la merienda', () {
      final p = CalorieCalculator.mealPartitioning(
        targetCalories: 1800,
        targetProteins: 140,
        targetCarbs: 180,
        targetFats: 60,
        mealCount: 3,
      );
      expect(p['Merienda']!['calories'], 0);
      expect(p['Desayuno']!['calories'], 540);
      expect(p['Almuerzo']!['calories'], 720);
      final kcalSum = p.values.fold<double>(0, (a, m) => a + m['calories']!);
      expect(kcalSum, 1800);
    });

    test('5 comidas incluye snack', () {
      final p = CalorieCalculator.mealPartitioning(
        targetCalories: 2200,
        targetProteins: 160,
        targetCarbs: 240,
        targetFats: 73,
        mealCount: 5,
      );
      expect(p['Snack']!['calories'], 330);
      final kcalSum = p.values.fold<double>(0, (a, m) => a + m['calories']!);
      expect(kcalSum, 2200);
    });

    test('las comidas principales respetan el umbral de leucina (>=20g P)', () {
      final p = CalorieCalculator.mealPartitioning(
        targetCalories: 2200,
        targetProteins: 160,
        targetCarbs: 240,
        targetFats: 73,
        mealCount: 5,
      );
      // Con 5 tomas el umbral solo aplica a comidas con pct alto o main.
      expect(p['Desayuno']!['proteins']!, greaterThanOrEqualTo(20));
    });
  });

  group('CalorieCalculator.feedingWindowSlots', () {
    test('sin ayuno devuelve la secuencia completa', () {
      expect(
        CalorieCalculator.feedingWindowSlots(
            mealCount: 4, intermittentFasting: false),
        ['Desayuno', 'Almuerzo', 'Merienda', 'Cena'],
      );
      expect(
        CalorieCalculator.feedingWindowSlots(
            mealCount: 5, intermittentFasting: false),
        ['Desayuno', 'Almuerzo', 'Merienda', 'Cena', 'Snack'],
      );
      // 3 comidas no incluye merienda (coherente con mealPartitioning).
      expect(
        CalorieCalculator.feedingWindowSlots(
            mealCount: 3, intermittentFasting: false),
        ['Desayuno', 'Almuerzo', 'Cena'],
      );
    });

    test('con ayuno se excluye el desayuno', () {
      final slots = CalorieCalculator.feedingWindowSlots(
          mealCount: 4, intermittentFasting: true);
      expect(slots.contains('Desayuno'), false);
      expect(slots.length, 3);
    });

    test('con 3 comidas y ayuno quedan Almuerzo y Cena', () {
      expect(
        CalorieCalculator.feedingWindowSlots(
            mealCount: 3, intermittentFasting: true),
        ['Almuerzo', 'Cena'],
      );
    });
  });

  group('CalorieCalculator.feedingWindowPartitions', () {
    Map<String, Map<String, double>> p4() => CalorieCalculator.mealPartitioning(
          targetCalories: 2000,
          targetProteins: 150,
          targetCarbs: 200,
          targetFats: 67,
          mealCount: 4,
        );

    test('sin ayuno no altera el reparto', () {
      final slots = CalorieCalculator.feedingWindowSlots(
          mealCount: 4, intermittentFasting: false);
      final p = CalorieCalculator.feedingWindowPartitions(
        partitions: p4(),
        feedSlots: slots,
        targetCalories: 2000,
      );
      final kcal = p.values.fold<double>(0, (a, m) => a + m['calories']!);
      expect(kcal, closeTo(2000, 3));
      expect(p.keys.toList(), ['Desayuno', 'Almuerzo', 'Merienda', 'Cena']);
    });

    test('con ayuno las tomas de la ventana suman el 100% de la meta', () {
      final slots = CalorieCalculator.feedingWindowSlots(
          mealCount: 4, intermittentFasting: true);
      expect(slots, ['Almuerzo', 'Merienda', 'Cena']);
      final p = CalorieCalculator.feedingWindowPartitions(
        partitions: p4(),
        feedSlots: slots,
        targetCalories: 2000,
      );
      // Sin renorm la ventana solo cubría 75% de la meta: 700+300+500.
      final kcal = p.values.fold<double>(0, (a, m) => a + m['calories']!);
      expect(kcal, closeTo(2000, 3));
      expect(p.keys.toSet(), slots.toSet());
      expect(p.containsKey('Desayuno'), false);
    });

    test('5 comidas con ayuno también cubren la meta', () {
      final slots = CalorieCalculator.feedingWindowSlots(
          mealCount: 5, intermittentFasting: true);
      final partitions = CalorieCalculator.mealPartitioning(
        targetCalories: 2200,
        targetProteins: 160,
        targetCarbs: 240,
        targetFats: 73,
        mealCount: 5,
      );
      final p = CalorieCalculator.feedingWindowPartitions(
        partitions: partitions,
        feedSlots: slots,
        targetCalories: 2200,
      );
      final kcal = p.values.fold<double>(0, (a, m) => a + m['calories']!);
      expect(kcal, closeTo(2200, 3));
    });
  });
}

PlanPhase planNext(PlanPhase p) => p.projectedNext;