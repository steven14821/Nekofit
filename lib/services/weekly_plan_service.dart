import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calorie_calculator.dart';
import '../models/nutrition_plan.dart';
import '../models/pantry_item.dart';
import '../models/user_context.dart';
import '../models/weekly_plan.dart';

/// Servicio de plan semanal con IA basado en 7 Reglas Fisiológicas y Nutricionales:
///  1. Distribución Fisiológica de Macronutrientes (Proteína por kg, suelo lipídico ≥0.8g/kg, carbs complejos).
///  2. Crononutrición y Leucina (Particionado por tomas y ≥20-40g proteína en comidas principales).
///  3. Densidad Nutricional & Fibra (≥14g/1000 kcal, regla de colores y grasas saturadas <10%).
///  4. Sistema de Intercambio y Ajuste de Matriz de Grasas (Sustitución isocalórica/isomacro).
///  5. Gestión de Saciedad y Densidad Calórica (Volumen en déficit vs Densidad en superávit).
///  6. Regla de Variedad y Microbiota (≥20-30 plantas distintas a la semana).
///  7. Carga e Índice Glucémico Combinado (Carbohidratos siempre combinados con fibra, proteína o grasa).
class WeeklyPlanService {
  WeeklyPlanService._();
  static final WeeklyPlanService instance = WeeklyPlanService._();

  static const _cachePrefix = 'weekly_plan_';
  static const _cacheTtl = Duration(days: 5); // válido hasta 5 días

  Completer<void>? _initCompleter;
  GenerativeModel? _model;

  Future<void> _ensureModel() async {
    if (_model != null) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.5-flash',
        generationConfig: GenerationConfig(
          temperature: 0.5,
          maxOutputTokens: 6144,
        ),
      );
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  /// Devuelve el plan para la semana que contiene [reference].
  /// Si hay caché válido, lo devuelve. Si no, genera con IA.
  Future<WeeklyPlan> getPlan({
    required String uid,
    required UserContext user,
    required List<PantryItem> pantry,
    DateTime? reference,
    bool forceRegenerate = false,
    NutritionPlan? plan,
  }) async {
    final now = reference ?? DateTime.now();
    final monday = WeeklyPlan.mondayOf(now);

    if (!forceRegenerate) {
      final cached = await _readCache(uid, monday);
      if (cached != null) return cached;
    }

    WeeklyPlan planOrNull;
    try {
      await _ensureModel();
      planOrNull = await _generateFromGemini(
        user: user,
        pantry: pantry,
        weekStart: monday,
        plan: plan,
      );
    } catch (_) {
      // Fallback: plan determinístico con las 7 reglas si Gemini falla.
      planOrNull = _fallbackPlan(
        user: user,
        pantry: pantry,
        weekStart: monday,
        plan: plan,
      );
    }

    await _writeCache(uid, planOrNull);
    return planOrNull;
  }

  /// Marca una comida como hecha/no hecha. Persiste en el caché.
  Future<WeeklyPlan> toggleMealDone({
    required String uid,
    required WeeklyPlan plan,
    required int dayIndex,
    required int mealIndex,
  }) async {
    if (dayIndex < 0 ||
        dayIndex >= plan.days.length ||
        mealIndex < 0 ||
        mealIndex >= plan.days[dayIndex].meals.length) {
      return plan;
    }

    final day = plan.days[dayIndex];
    final updatedMeals = [...day.meals];
    final meal = updatedMeals[mealIndex];
    updatedMeals[mealIndex] = meal.copyWith(done: !meal.done);

    final updatedDays = [...plan.days];
    updatedDays[dayIndex] = day.copyWith(meals: updatedMeals);

    final updated = WeeklyPlan(
      weekStart: plan.weekStart,
      days: updatedDays,
      generatedAt: plan.generatedAt,
      source: plan.source,
    );

    await _writeCache(uid, updated);
    return updated;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Caché
  // ═══════════════════════════════════════════════════════════════════════════

  Future<WeeklyPlan?> _readCache(String uid, DateTime weekStart) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid, weekStart));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final plan = WeeklyPlan.fromMap(map);
      if (DateTime.now().difference(plan.generatedAt) > _cacheTtl) {
        return null;
      }
      return WeeklyPlan(
        weekStart: plan.weekStart,
        days: plan.days,
        generatedAt: plan.generatedAt,
        source: 'cache',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String uid, WeeklyPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid, plan.weekStart), jsonEncode(plan.toMap()));
  }

  String _key(String uid, DateTime weekStart) {
    final stamp = weekStart.toIso8601String().substring(0, 10);
    return '$_cachePrefix${uid}_$stamp';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Generación con Gemini siguiendo las 7 Reglas Fisiológicas
  // ═══════════════════════════════════════════════════════════════════════════

  Future<WeeklyPlan> _generateFromGemini({
    required UserContext user,
    required List<PantryItem> pantry,
    required DateTime weekStart,
    NutritionPlan? plan,
  }) async {
    final pantryByCategory = <String, List<PantryItem>>{};
    for (final item in pantry.where((i) => i.isAvailable)) {
      pantryByCategory.putIfAbsent(item.category, () => []).add(item);
    }

    // Nº de comidas y ventana de ayuno del plan (si existe). Si no hay plan,
    // se usa el default de 4 comidas, sin ayuno.
    final schedule = plan?.schedule ?? const MealSchedule();
    final mealsPerDay = schedule.mealsPerDay;
    final ifActive = schedule.intermittentFasting;
    final feedSlots = CalorieCalculator.feedingWindowSlots(
      mealCount: mealsPerDay,
      intermittentFasting: ifActive,
    );

    final pantrySummary = pantryByCategory.entries
        .map((e) => {
              'category': e.key,
              'items': e.value
                  .map((i) => {
                        'name': i.name,
                        'quantity': i.quantity,
                        'macros_per_100g': {
                          'kcal': i.calories,
                          'P': i.proteins,
                          'C': i.carbs,
                          'G': i.fats,
                        }
                      })
                  .toList(),
            })
        .toList();

    final double rawTargetKcal = (user.macroGoals['calories'] ?? 0) > 0
        ? user.macroGoals['calories']!
        : ((user.macroGoals['proteins'] ?? user.macroGoals['protein'] ?? 0) * 4 +
            (user.macroGoals['carbs'] ?? 0) * 4 +
            (user.macroGoals['fats'] ?? 0) * 9);
    final double safeTargetKcal = rawTargetKcal > 500 ? rawTargetKcal : 2000.0;

    // Distribución fisiológica centralizada
    final physioMacros = CalorieCalculator.distributeMacros(
      targetCalories: safeTargetKcal,
      weightKg: user.weight > 30 ? user.weight : 70.0,
      fitnessGoal: user.fitnessGoal,
    );

    final double targetProteins = (user.macroGoals['proteins'] ?? user.macroGoals['protein'] ?? 0) > 0
        ? (user.macroGoals['proteins'] ?? user.macroGoals['protein']!)
        : physioMacros['proteins']!;
    final double targetFats = (user.macroGoals['fats'] ?? 0) > 0
        ? user.macroGoals['fats']!
        : physioMacros['fats']!;
    final double targetCarbs = (user.macroGoals['carbs'] ?? 0) > 0
        ? user.macroGoals['carbs']!
        : physioMacros['carbs']!;
    final double minFiberGrams = physioMacros['fiber'] ?? 28.0;

    final mealPartitions = CalorieCalculator.mealPartitioning(
      targetCalories: safeTargetKcal,
      targetProteins: targetProteins,
      targetCarbs: targetCarbs,
      targetFats: targetFats,
      mealCount: mealsPerDay,
    );

    final isDeficit = user.fitnessGoal.toLowerCase().contains('perder') ||
        user.fitnessGoal.toLowerCase().contains('déficit');
    final isSurplus = user.fitnessGoal.toLowerCase().contains('ganar') ||
        user.fitnessGoal.toLowerCase().contains('músculo') ||
        user.fitnessGoal.toLowerCase().contains('superávit');

    // ── Personalización extrema: contexto de salud y comidas ──
    final ctx = plan?.context ?? const NutritionContext();
    final hasCtx = !ctx.isEmpty;
    final activeSlots = ifActive
        ? 'Ayuno intermitente activo (${schedule.fastingHours}:8). Solo estas '
            'tomas entran en la ventana: ${feedSlots.join(", ")}.'
        : 'Sin ayuno intermitente.';
    final contextBlock = hasCtx
        ? '''
══════════════════════════════════════════════════════════════════
CONTEXTO PERSONAL DEL USUARIO (OBLIGATORIO RESPETARLO):
══════════════════════════════════════════════════════════════════
- Condiciones médicas: ${ctx.medicalConditions.isEmpty ? 'Ninguna' : ctx.medicalConditions.join(', ')}
- Preferencias/restricciones alimentarias: ${ctx.dietaryPreferences.isEmpty ? 'Sin restricciones' : ctx.dietaryPreferences.join(', ')}
- Alimentos imprescindibles (INCLUYE al menos uno por día): ${ctx.mustHaveFoods.isEmpty ? 'Ninguno especificado' : ctx.mustHaveFoods.join(', ')}
- Alimentos que DEBES EVITAR (excluirlos por completo): ${ctx.aversions.isEmpty ? 'Ninguno' : ctx.aversions.join(', ')}
- Toma las condiciones médicas en serio: si hay resistencia a la insulina o diabetes tipo 2, prioriza carbohidratos complejos y evita azúcares simples. Si hay hipertensión, minimiza alimentos ultraprocesados y con alto sodio. Si hay hipotiroidismo, asegura suficiente yodo natural y no omitas proteína.
- Respeta estrictamente las preferencias (vegana, vegetariana, sin gluten, sin lactosa, keto). En keto mantén los carbohidratos por debajo de 50g/día.
$activeSlots'''
        : '''
══════════════════════════════════════════════════════════════════
DISTRIBUCIÓN DE COMIDAS:
══════════════════════════════════════════════════════════════════
$activeSlots''';
    final slotRequirements = ifActive
        ? 'Genera exactamente ${feedSlots.length} comidas dentro de la ventana: ${feedSlots.join(", ")}. No generes Desayuno.'
        : 'Genera $mealsPerDay comidas por día${mealsPerDay == 5 ? ': "Desayuno", "Almuerzo", "Merienda", "Cena" y "Snack"' : mealsPerDay == 3 ? ': "Desayuno", "Almuerzo" y "Cena"' : ': "Desayuno", "Almuerzo", "Merienda" y "Cena"'}.';

    final prompt = '''
Eres un científico de la nutrición y chef experto. Diseña un plan de alimentación personalizado de 7 días (lunes a domingo) cumpliendo ESTRICTAMENTE con las siguientes 7 REGLAS FISIOLÓGICAS Y NUTRICIONALES:

══════════════════════════════════════════════════════════════════
DATOS DEL USUARIO Y OBJETIVO
══════════════════════════════════════════════════════════════════
- Género: ${user.gender}
- Edad: ${user.age} años
- Peso: ${user.weight} kg
- Altura: ${user.height} cm
- Nivel de Actividad: ${user.dailyLifestyle} (${user.trainingActivity})
- Objetivo Fitness: ${user.fitnessGoal} (${isDeficit ? 'DÉFICIT CALÓRICO' : (isSurplus ? 'SUPERÁVIT CALÓRICO' : 'MANTENIMIENTO')})
- META CALÓRICA DIARIA EXACTA: ${safeTargetKcal.toStringAsFixed(0)} kcal / día (OBLIGATORIO)

══════════════════════════════════════════════════════════════════
7 REGLAS NUTRICIONALES OBLIGATORIAS QUE DEBES CUMPLIR:
══════════════════════════════════════════════════════════════════

1. DISTRIBUCIÓN FISIOLÓGICA DE MACRONUTRIENTES:
   - Proteínas: ${targetProteins.toStringAsFixed(0)} g/día (${(targetProteins / (user.weight > 0 ? user.weight : 70)).toStringAsFixed(1)} g/kg).
   - Grasas: ${targetFats.toStringAsFixed(0)} g/día (mínimo suelo hormonal ≥ 0.8 g/kg y 20-25% del total).
   - Carbohidratos: ${targetCarbs.toStringAsFixed(0)} g/día (remanente energético).

2. CRONONUTRICIÓN Y UMBRAL DE LEUCINA:
   - Reparto calórico y proteico por tiempos de comida:
${mealPartitions.entries.where((e) => e.value['calories']! > 0).map((e) => '     * ${e.key}: ~${e.value['calories']!.toStringAsFixed(0)} kcal | P: ${e.value['proteins']!.toStringAsFixed(0)}g | C: ${e.value['carbs']!.toStringAsFixed(0)}g | G: ${e.value['fats']!.toStringAsFixed(0)}g').join('\n')}
   - UMBRAL DE LEUCINA: Cada comida principal (Desayuno, Almuerzo y Cena) DEBE contener entre 20 y 40g de proteína de alto valor biológico para estimular la síntesis de proteína muscular (MPS).
   - UMBRAL DE LEUCINA: Cada comida principal (Desayuno, Almuerzo y Cena) DEBE contener entre 20 y 40g de proteína de alto valor biológico para estimular la síntesis de proteína muscular (MPS).

3. DENSIDAD NUTRICIONAL, FIBRA Y CONTROL DE GRASAS:
   - Aporte mínimo de Fibra: AL MENOS ${minFiberGrams.toStringAsFixed(0)} g/día (≥ 14g por 1000 kcal). Cada comida debe incorporar vegetales, frutas enteras, legumbres o granos enteros.
   - Regla de colores: Rotar vegetales verdes (espinaca, brócoli, calabacín), rojos/naranjas (tomate, zanahoria, pimentón), morados (remolacha, berenjena, frutos rojos) y blancos (cebolla, ajo).
   - Grasas saturadas < 10% del total; priorizar mono/poliinsaturadas (AOVE, aguacate, nueces, almendras, semillas de chía, pescado azul).

4. SISTEMA DE INTERCAMBIO Y AJUSTE DE MATRIZ DE GRASAS:
   - Respetar proporciones isocalóricas e isomacro al combinar alimentos.
   - Si una comida incluye una proteína con grasa natural (ej. salmón, huevo entero, carne de res), REDUCE el aceite de cocina añadido en ese plato para mantener el balance calórico exacto.

5. GESTIÓN DE LA SACIEDAD Y DENSIDAD CALÓRICA:
   ${isDeficit ? '- DÉFICIT: Maximizar saciedad y volumen gástrico con alta hidratación y fibra (vegetales de hoja, tubérculos hervidos, sopas, carnes magras).' : (isSurplus ? '- SUPERÁVIT: Utilizar alimentos de alta densidad energética y menor volumen (frutos secos, mantequilla de maní, aceite de oliva, avena, batidos) para evitar llenura excesiva.' : '- MANTENIMIENTO: Equilibrio energético y alta variedad con saciedad estable.')}

6. REGLA DE VARIEDAD Y MICROBIOTA (≥ 20-30 ALIMENTOS VEGETALES DISTINTOS/SEMANA):
   - OBLIGATORIO: El menú de los 7 días debe sumar entre 20 y 30 fuentes vegetales distintas (diferentes verduras, frutas, legumbres como lentejas/frijoles/garbanzos, semillas y cereales integrales).
   - Evita repetir el mismo plato idéntico todos los días.

7. CARGA E ÍNDICE GLUCÉMICO COMBINADO:
   - NUNCA programes carbohidratos simples aislados. Todo carbohidrato debe ir acompañado de proteína, fibra o grasa saludable para ralentizar el vaciado gástrico y estabilizar la glucemia.

══════════════════════════════════════════════════════════════════
DESPENSA DEL USUARIO (Prioriza usar estos productos disponibles):
══════════════════════════════════════════════════════════════════
${jsonEncode(pantrySummary)}

$contextBlock

FORMATO DE SALIDA (Responde ÚNICAMENTE en JSON válido sin markdown ni texto adicional):
{
  "days": [
    {
      "date": "YYYY-MM-DD",
      "meals": [
        {
          "slot": "${feedSlots.first}",
          "title": "Título de la comida",
          "description": "Descripción breve con ingredientes y cantidades",
          "calories": ${mealPartitions[feedSlots.first]!.isEmpty ? 300 : mealPartitions[feedSlots.first]!['calories']!.round()},
          "proteins": ${(mealPartitions[feedSlots.first]!['proteins'] ?? 25).round()},
          "carbs": ${(mealPartitions[feedSlots.first]!['carbs'] ?? 35).round()},
          "fats": ${(mealPartitions[feedSlots.first]!['fats'] ?? 10).round()},
          "pantryItemIds": []
        }
      ]
    }
  ]
}

REQUISITOS ADICIONALES:
- 7 días consecutivos comenzando el ${weekStart.toIso8601String().substring(0, 10)}.
- $slotRequirements
- La suma diaria de calorías de cada día debe ser exactamente ${safeTargetKcal.toStringAsFixed(0)} kcal (±30 kcal).
''';

    final response = await _model!.generateContent([Content.text(prompt)]);
    if (response.text == null || response.text!.isEmpty) {
      throw Exception('Gemini no devolvió respuesta');
    }

    final parsed = _parseResponse(response.text!, weekStart);
    return _attachPantryIds(parsed, pantry);
  }

  WeeklyPlan _parseResponse(String responseText, DateTime weekStart) {
    var cleaned = responseText.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    final days = (json['days'] as List).map((d) {
      final map = Map<String, dynamic>.from(d);
      final date = DateTime.tryParse(map['date'] ?? '') ?? weekStart;
      final meals = (map['meals'] as List).map((m) {
        final mealMap = Map<String, dynamic>.from(m);
        return PlannedMeal(
          slot: mealMap['slot'] ?? 'Almuerzo',
          title: mealMap['title'] ?? '',
          description: mealMap['description'] ?? '',
          calories: (mealMap['calories'] as num?)?.toDouble() ?? 0,
          proteins: (mealMap['proteins'] as num?)?.toDouble() ?? 0,
          carbs: (mealMap['carbs'] as num?)?.toDouble() ?? 0,
          fats: (mealMap['fats'] as num?)?.toDouble() ?? 0,
          pantryItemIds: const [],
        );
      }).toList();
      return PlannedDay(date: date, meals: meals);
    }).toList();

    return WeeklyPlan(
      weekStart: weekStart,
      days: days,
      generatedAt: DateTime.now(),
      source: 'gemini',
    );
  }

  WeeklyPlan _attachPantryIds(WeeklyPlan plan, List<PantryItem> pantry) {
    final byLowerName = {
      for (final item in pantry.where((i) => i.isAvailable))
        item.name.toLowerCase(): item.id,
    };

    final newDays = plan.days.map((day) {
      final newMeals = day.meals.map((meal) {
        final ids = <String>[];
        final titleLower =
            '${meal.title} ${meal.description}'.toLowerCase();
        for (final entry in byLowerName.entries) {
          if (titleLower.contains(entry.key)) {
            ids.add(entry.value);
          }
        }
        return PlannedMeal(
          slot: meal.slot,
          title: meal.title,
          description: meal.description,
          calories: meal.calories,
          proteins: meal.proteins,
          carbs: meal.carbs,
          fats: meal.fats,
          pantryItemIds: ids,
          done: meal.done,
        );
      }).toList();
      return day.copyWith(meals: newMeals);
    }).toList();

    return WeeklyPlan(
      weekStart: plan.weekStart,
      days: newDays,
      generatedAt: plan.generatedAt,
      source: plan.source,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Fallback determinístico con las 7 Reglas
  // ═══════════════════════════════════════════════════════════════════════════

  WeeklyPlan _fallbackPlan({
    required UserContext user,
    required List<PantryItem> pantry,
    required DateTime weekStart,
    NutritionPlan? plan,
  }) {
    final available = pantry.where((i) => i.isAvailable).toList();
    final protein = available.where((i) => i.category == 'Proteínas').toList();
    final carbs = available.where((i) => i.category == 'Carbohidratos').toList();
    final veg = available.where((i) => i.category == 'Vegetales').toList();

    final schedule = plan?.schedule ?? const MealSchedule();
    final mealsPerDay = schedule.mealsPerDay;
    final ifActive = schedule.intermittentFasting;

    final double rawTargetKcal = (user.macroGoals['calories'] ?? 0) > 0
        ? user.macroGoals['calories']!
        : ((user.macroGoals['proteins'] ?? user.macroGoals['protein'] ?? 0) * 4 +
            (user.macroGoals['carbs'] ?? 0) * 4 +
            (user.macroGoals['fats'] ?? 0) * 9);
    final double safeTargetKcal = rawTargetKcal > 500 ? rawTargetKcal : 2000.0;

    final physioMacros = CalorieCalculator.distributeMacros(
      targetCalories: safeTargetKcal,
      weightKg: user.weight > 30 ? user.weight : 70.0,
      fitnessGoal: user.fitnessGoal,
    );

    final double targetProteins = (user.macroGoals['proteins'] ?? user.macroGoals['protein'] ?? 0) > 0
        ? (user.macroGoals['proteins'] ?? user.macroGoals['protein']!)
        : physioMacros['proteins']!;
    final double targetCarbs = (user.macroGoals['carbs'] ?? 0) > 0
        ? user.macroGoals['carbs']!
        : physioMacros['carbs']!;
    final double targetFats = (user.macroGoals['fats'] ?? 0) > 0
        ? user.macroGoals['fats']!
        : physioMacros['fats']!;

    final partitions = CalorieCalculator.mealPartitioning(
      targetCalories: safeTargetKcal,
      targetProteins: targetProteins,
      targetCarbs: targetCarbs,
      targetFats: targetFats,
      mealCount: mealsPerDay,
    );

    String pick(List<PantryItem> pool, int seed, String fallback) {
      if (pool.isEmpty) return fallback;
      return pool[seed % pool.length].name;
    }

    // Plantillas rotando más de 25 vegetales/plantas distintas. El 5º hueco
    // es un snack adicional que solo se usa con 5 comidas; con 3 se omite la
    // merienda; con ayuno se omite el desayuno.
    final templates = [
      // Día 1 (Lunes): Espinaca, Arepa de maíz, Aguacate, Pollo, Arroz integral, Zanahoria, Manzana, Almendras, Salmón, Brócoli
      [
        'Huevos revueltos con ${pick(veg, 0, 'espinaca')} y arepa de maíz',
        '${pick(protein, 0, 'Pechuga de pollo')} con ${pick(carbs, 0, 'arroz integral')} y ensalada de ${pick(veg, 1, 'zanahoria')}',
        'Yogurt griego con manzana verde picada y almendras',
        'Salmón a la plancha con ${pick(veg, 2, 'brócoli')} al vapor y papa cocida',
      ],
      // Día 2 (Martes): Avena, Chía, Banano, Lentejas, Tomate, Pepino, Naranja, Nueces, Pavo, Calabacín
      [
        'Porridge de avena con semillas de chía, banano y canela',
        'Sopa de lentejas con ${pick(protein, 1, 'lomo de cerdo')} y ensalada de ${pick(veg, 3, 'tomate y pepino')}',
        'Naranja fresca con un puñado de nueces',
        'Lomo de pavo salteado con ${pick(veg, 4, 'calabacín')} y batata al horno',
      ],
      // Día 3 (Miércoles): Huevos, Champiñones, Pan integral, Frijoles, Plátano maduro, Papaya, Tofu/Carne, Espárragos
      [
        'Omelette de huevos con ${pick(veg, 5, 'champiñones')} y tostada integral',
        'Frijoles negros con ${pick(protein, 2, 'carne magra')}, plátano cocido y aguacate',
        'Papaya picada con semillas de calabaza y queso campesino',
        'Pechuga a la plancha con ${pick(veg, 6, 'espárragos')} salteados y quinoa',
      ],
      // Día 4 (Jueves): Avena, Fresas, Almendras, Garbanzos, Pimentón, Berenjena, Pera, Pescado, Coliflor
      [
        'Tazón de avena con fresas frescas y mantequilla de maní',
        'Garbanzos guisados con ${pick(protein, 3, 'pollo')} y sofrito de ${pick(veg, 7, 'pimentón y cebolla')}',
        'Pera en rodajas con requesón y canela',
        'Filete de pescado blanco con puré de ${pick(veg, 8, 'coliflor')} y ensalada verde',
      ],
      // Día 5 (Viernes): Huevos, Tomate, Arepa, Pasta integral, Atún, Rúcula, Kiwi, Semillas, Cerdo, Remolacha
      [
        'Huevos pericos con ${pick(veg, 0, 'tomate y cebolla')} y arepa con queso',
        'Pasta integral con atún, aceite de oliva, ${pick(veg, 1, 'rúcula')} y maíz tierno',
        'Kiwi en trozos con yogurt natural y semillas de chía',
        'Lomo de cerdo magro con ${pick(veg, 2, 'remolacha cocida')} y papa al vapor',
      ],
      // Día 6 (Sábado): Panquecas de avena, Arándanos, Carne, Yuca, Ensalada multicolor, Fruta, Pollo, Batata
      [
        'Panquecas caseras de avena y huevo con arándanos',
        'Carne asada magra con yuca al vapor y ensalada de repollo morado y zanahoria',
        'Batido de banano, leche descremada y crema de almendras',
        'Pechuga al horno con batata asada y vainitas verdes',
      ],
      // Día 7 (Domingo): Calentado ligero, Huevos, Pollo, Quinoa, Ensalada de la casa, Frutas, Pescado, Verduras
      [
        'Calentado saludable de arroz y frijoles con huevo pochado',
        'Pollo desmechado con quinoa y ensalada de espinaca baby y tomate cherry',
        'Ensalada de frutas frescas con un toque de semillas de girasol',
        'Pescado a la plancha con verduras salteadas (calabacín, pimentón y champiñones)',
      ],
    ];

    // Mapeo slot → posición en la plantilla según nº de comidas.
    // 5 comidas usa un snack extra; 3 comidas no usa merienda.
    final List<MapEntry<String, int>> slotOrder = switch (mealsPerDay) {
      5 => [
          const MapEntry('Desayuno', 0),
          const MapEntry('Almuerzo', 1),
          const MapEntry('Merienda', 2),
          const MapEntry('Snack', 4),
          const MapEntry('Cena', 3),
        ],
      3 => [
          const MapEntry('Desayuno', 0),
          const MapEntry('Almuerzo', 1),
          const MapEntry('Cena', 3),
        ],
      _ => [
          const MapEntry('Desayuno', 0),
          const MapEntry('Almuerzo', 1),
          const MapEntry('Merienda', 2),
          const MapEntry('Cena', 3),
        ],
    };

    final days = <PlannedDay>[];
    for (var d = 0; d < 7; d++) {
      final date = weekStart.add(Duration(days: d));
      final tpl = templates[d];
      // Con IF (16:8) la ventana de alimentación empieza a medio día: se omite
      // el desayuno y el plan tiene una toma menos al día.
      final slots =
          ifActive ? slotOrder.where((e) => e.key != 'Desayuno').toList() : slotOrder;
      final meals = [
        for (final s in slots)
          _buildPlannedMeal(
            s.key,
            s.key == 'Snack' ? 'Snack de ${pick(veg, d * 2 + 1, 'fruta y frutos secos')} con proteína'
                : tpl[s.value],
            partitions[s.key]!,
          ),
      ];
      days.add(PlannedDay(date: date, meals: meals));
    }

    return WeeklyPlan(
      weekStart: weekStart,
      days: days,
      generatedAt: DateTime.now(),
      source: 'fallback',
    );
  }

  PlannedMeal _buildPlannedMeal(
    String slot,
    String title,
    Map<String, double> macros,
  ) {
    return PlannedMeal(
      slot: slot,
      title: title.trim(),
      description: 'Plato balanceado siguiendo las 7 reglas nutricionales de NekoFit',
      calories: macros['calories']!,
      proteins: macros['proteins']!,
      carbs: macros['carbs']!,
      fats: macros['fats']!,
    );
  }
}

