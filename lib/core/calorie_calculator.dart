import 'dart:math' as math;

/// Factores de gasto calórico por minuto, según el tipo de actividad.
/// Los valores son kcal aproximadas por minuto para una persona de ~70 kg.
/// Para cálculos precisos se ponderan por el peso real del usuario.
class ActivityMetFactors {
  ActivityMetFactors._();

  /// kcal de entrenamiento por minuto, según el tipo de actividad.
  /// Los valores son kcal/min absolutos, calibrados para una persona de ~70 kg.
  /// Pesas HIIT > Pesas moderado > correr rápido > correr moderado > ciclismo > caminar.
  static const Map<String, double> byKey = {
    'pesas_hit': 6.0,
    'pesas_moderado': 4.5,
    'correr_moderado': 10.0,
    'correr_rapido': 12.5,
    'caminar': 4.0,
    'ciclismo': 7.5,
  };

  static const List<String> labels = [
    'pesas_hit',
    'pesas_moderado',
    'correr_moderado',
    'correr_rapido',
    'caminar',
    'ciclismo',
  ];

  static String displayName(String key) {
    switch (key) {
      case 'pesas_hit':
        return 'Pesas (HIIT / alta intensidad)';
      case 'pesas_moderado':
        return 'Pesas (ritmo moderado)';
      case 'correr_moderado':
        return 'Correr (ritmo moderado)';
      case 'correr_rapido':
        return 'Correr (ritmo rápido / intervalos)';
      case 'caminar':
        return 'Caminar';
      case 'ciclismo':
        return 'Ciclismo';
      default:
        return key;
    }
  }

  static String emoji(String key) {
    switch (key) {
      case 'pesas_hit':
        return 'd';
      case 'pesas_moderado':
        return 'p';
      case 'correr_moderado':
        return 'r';
      case 'correr_rapido':
        return 'R';
      case 'caminar':
        return 'c';
      case 'ciclismo':
        return 'b';
    }
    return '.';
  }
}

/// Resultado del cálculo de metabolismo basal.
class BmrResult {
  final double value;
  final String formula; // 'katch' | 'mifflin'
  final double? leanMassKg;

  const BmrResult(this.value, this.formula, this.leanMassKg);
}

/// Calculadora central de calorías, BMR y macros.
/// Mantenida pura (sin Flutter, sin Firebase) para que sea fácil de probar.
class CalorieCalculator {
  CalorieCalculator._();

  /// Masa magra en kg = peso * (1 - %grasa/100).
  static double leanMassKg(double weightKg, double bodyFatPercent) {
    final clampedFat = bodyFatPercent.clamp(0.0, 80.0);
    return weightKg * (1 - clampedFat / 100.0);
  }

  /// Katch-McArdle: BMR = 370 + (21.6 * LBM).
  static double bmrKatch(double leanMass) {
    return 370 + (21.6 * leanMass);
  }

  /// Mifflin-St Jeor.
  static double bmrMifflin({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return isMale ? base + 5 : base - 161;
  }

  /// Decide qué fórmula usar. Katch gana si hay % grasa.
  static BmrResult calculateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
    double? bodyFatPercent,
  }) {
    if (bodyFatPercent != null && bodyFatPercent > 0 && bodyFatPercent < 60) {
      final lbm = leanMassKg(weightKg, bodyFatPercent);
      return BmrResult(bmrKatch(lbm), 'katch', lbm);
    }
    return BmrResult(
      bmrMifflin(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        isMale: isMale,
      ),
      'mifflin',
      null,
    );
  }

  /// Multiplicador de estilo de vida diario. NO considera entrenamiento.
  /// Sedentario: pasa sentado (desk job). Activo: trabaja de pie o camina mucho.
  static double lifestyleMultiplier(String lifestyle) {
    switch (lifestyle) {
      case 'activo':
        return 1.4;
      case 'sedentario':
      default:
        return 1.2;
    }
  }

  /// kcal de entrenamiento por sesión = factor[actividad] * minutos.
  /// Devuelve el total semanal, no el diario.
  /// Los factores ya están en kcal/min absolutos (ver `ActivityMetFactors`).
  static double weeklyTrainingKcal({
    required String activityKey,
    required int minutesPerWeek,
  }) {
    final factor = ActivityMetFactors.byKey[activityKey] ?? 4.5;
    return factor * minutesPerWeek;
  }

  /// TDEE diario: estilo de vida * BMR + (kcal de entrenamiento semanales / 7).
  static double dailyTdee({
    required BmrResult bmr,
    required String lifestyle,
    required String trainingActivityKey,
    required int trainingMinutesPerWeek,
  }) {
    final lifestylePart = bmr.value * lifestyleMultiplier(lifestyle);
    final trainingDaily =
        weeklyTrainingKcal(
              activityKey: trainingActivityKey,
              minutesPerWeek: trainingMinutesPerWeek,
            ) /
        7.0;
    return lifestylePart + trainingDaily;
  }

  /// Distribución fisiológica de macronutrientes (Reglas 1, 2 y 3):
  /// 1. Proteína por objetivo:
  ///    - Pérdida de peso / déficit: 1.8–2.2 g/kg (preservación muscular y saciedad).
  ///    - Ganancia muscular / superávit: 1.6–2.2 g/kg (estímulo hipertrofia).
  ///    - Mantenimiento: 1.4–1.6 g/kg.
  /// 2. Suelo mínimo de grasas: al menos 20–25% del total o ~0.8 g/kg para salud hormonal.
  /// 3. Carbohidratos energéticos: remanente calórico asignado a carbohidratos complejos.
  /// 4. Fibra mínima: ≥ 14 g por 1000 kcal (o 25–38 g/día).
  static Map<String, double> distributeMacros({
    required double targetCalories,
    required double weightKg,
    String? fitnessGoal,
  }) {
    double proteinPerKg;
    final goalLower = (fitnessGoal ?? '').toLowerCase();
    if (goalLower.contains('perder') ||
        goalLower.contains('déficit') ||
        goalLower.contains('deficit') ||
        goalLower.contains('cut')) {
      proteinPerKg = 2.0; // 1.8–2.2 g/kg
    } else if (goalLower.contains('ganar') ||
        goalLower.contains('músculo') ||
        goalLower.contains('musculo') ||
        goalLower.contains('superávit') ||
        goalLower.contains('bulk')) {
      proteinPerKg = 1.9; // 1.6–2.2 g/kg
    } else if (goalLower.contains('mantener')) {
      proteinPerKg = 1.5; // 1.4–1.6 g/kg
    } else {
      proteinPerKg = 1.8;
    }

    final proteins =
        (weightKg * proteinPerKg).clamp(50.0, double.infinity).toDouble();

    // Suelo de grasas: mayor entre 0.8 g/kg o 25% de calorías
    final fatByWeight = weightKg * 0.8;
    final fatByCalories = (targetCalories * 0.25) / 9.0;
    final fats = math.max(fatByWeight, fatByCalories);

    final remainingKcal = targetCalories - (proteins * 4) - (fats * 9);
    var carbs = remainingKcal / 4.0;
    if (carbs < 40) carbs = 40.0;

    // Aporte mínimo de fibra: al menos 14g por cada 1000 kcal
    final fiber = ((targetCalories / 1000.0) * 14.0).clamp(25.0, 45.0);

    return {
      'calories': targetCalories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'fiber': fiber,
    };
  }

  /// Particionado calórico y proteico por tiempos de comida (Crononutrición y Leucina - Regla 2):
  /// Reparto según nº de tomas, con umbral de leucina (≥20g proteína) en las
  /// comidas principales. Por defecto 4 tomas: 25/35/15/25.
  ///
  ///   - 3 tomas: 30/40/30 (desayuno o cena más "compacta", almuerzo principal)
  ///   - 4 tomas: 25/35/15/25
  ///   - 5 tomas: 20/25/20/20/15 (incluye meriendas o snack adicional)
  ///
  /// Devuelve siempre 4 claves base (Desayuno/Almuerzo/Merienda/Cena) más
  /// `Snack` cuando [mealCount] == 5. Para 3 tomas, `Merienda` queda sin
  /// reparto (macros a 0) porque solo hay 3 comidas diarias.
  static Map<String, Map<String, double>> mealPartitioning({
    required double targetCalories,
    required double targetProteins,
    required double targetCarbs,
    required double targetFats,
    int mealCount = 4,
  }) {
    final Map<String, double> splits;
    switch (mealCount) {
      case 3:
        splits = {'Desayuno': 0.30, 'Almuerzo': 0.40, 'Merienda': 0.0, 'Cena': 0.30};
      case 5:
        splits = {'Desayuno': 0.20, 'Almuerzo': 0.25, 'Merienda': 0.20, 'Cena': 0.20, 'Snack': 0.15};
      default:
        splits = {'Desayuno': 0.25, 'Almuerzo': 0.35, 'Merienda': 0.15, 'Cena': 0.25};
    }

    Map<String, double> split(String name, double pct) {
      final isMain = name == 'Desayuno' || name == 'Almuerzo' || name == 'Cena';
      final prot = mealCount == 5 || !isMain
          ? (targetProteins * pct)
          : math.max(20.0, (targetProteins * pct));
      return {
        'calories': (targetCalories * pct).roundToDouble(),
        'proteins': prot.roundToDouble(),
        'carbs': (targetCarbs * pct).roundToDouble(),
        'fats': (targetFats * pct).roundToDouble(),
      };
    }

    return {
      for (final entry in splits.entries) entry.key: split(entry.key, entry.value),
    };
  }

  /// Claves de tomas según el nº de comidas diarias ([mealCount]).
  /// La base refleja exactamente el plan: 3 tomas no incluye merienda.
  ///   - 3 tomas: Desayuno, Almuerzo, Cena
  ///   - 4 tomas: Desayuno, Almuerzo, Merienda, Cena
  ///   - 5 tomas: Desayuno, Almuerzo, Merienda, Cena, Snack
  static List<String> mealSlots(int mealCount) {
    switch (mealCount) {
      case 3:
        return ['Desayuno', 'Almuerzo', 'Cena'];
      case 5:
        return ['Desayuno', 'Almuerzo', 'Merienda', 'Cena', 'Snack'];
      default:
        return ['Desayuno', 'Almuerzo', 'Merienda', 'Cena'];
    }
  }

  /// Ventana de alimentación bajo ayuno intermitente. La ventana típica (16:8)
  /// empieza a medio día: se omite el Desayuno. Devuelve las claves de tomas
  /// que SÍ entran en la ventana según [mealCount] y la ventana IF.
  static List<String> feedingWindowSlots({
    required int mealCount,
    required bool intermittentFasting,
  }) {
    final base = mealSlots(mealCount);
    if (!intermittentFasting) return base;
    // Con ayuno, la primera toma (Desayuno) queda fuera de la ventana de
    // alimentación, así que se excluye del reparto activo de tomas.
    return base.where((s) => s != 'Desayuno').toList();
  }

  /// Recalcula el particionado para que SOLO las tomas de la ventana activa
  /// [feedSlots] absorban el 100% de la meta diaria. Sin esto, el ayuno deja
  /// fuera el Desayuno y su parte se pierde: el plan serviría solo un 65–80%
  /// de las calorías objetivo.
  static Map<String, Map<String, double>> feedingWindowPartitions({
    required Map<String, Map<String, double>> partitions,
    required List<String> feedSlots,
    required double targetCalories,
  }) {
    final window = partitions.entries
        .where((e) => feedSlots.contains(e.key))
        .toList();
    if (window.isEmpty) return partitions;
    final windowKcal = window.fold<double>(
        0, (sum, e) => sum + e.value['calories']!);
    if (windowKcal <= 0) return partitions;
    final factor = targetCalories / windowKcal;
    return {
      for (final e in window)
        e.key: {
          'calories': (e.value['calories']! * factor).roundToDouble(),
          'proteins': (e.value['proteins']! * factor).roundToDouble(),
          'carbs': (e.value['carbs']! * factor).roundToDouble(),
          'fats': (e.value['fats']! * factor).roundToDouble(),
        },
    };
  }

  /// Fórmula de la Marina de EE.UU. para % de grasa corporal.
  /// Para hombres: 86.010 * log10(cintura - cuello) - 70.041 * log10(altura) + 36.76
  /// Para mujeres: 163.205 * log10(cintura + cadera - cuello) - 97.684 * log10(altura) - 78.387
  ///
  /// Todas las medidas en cm. Devuelve un % entre 3 y 60 para evitar locuras numéricas.
  static double bodyFatNavy({
    required bool isMale,
    required double neckCm,
    required double waistCm,
    required double heightCm,
    double? hipCm,
  }) {
    final isValidMale = neckCm < waistCm && neckCm > 0 && waistCm > 0 && heightCm > 0;
    final isValidFemale = neckCm > 0 && waistCm > 0 && heightCm > 0 &&
        (hipCm ?? 0) > 0;

    if (isMale && isValidMale) {
      final result = 86.010 * math.log(waistCm - neckCm) / math.ln10 -
          70.041 * math.log(heightCm) / math.ln10 +
          36.76;
      return result.clamp(3.0, 60.0).toDouble();
    }
    if (!isMale && isValidFemale) {
      final result = 163.205 * math.log(waistCm + hipCm! - neckCm) / math.ln10 -
          97.684 * math.log(heightCm) / math.ln10 -
          78.387;
      return result.clamp(3.0, 60.0).toDouble();
    }
    // Si la combinación es físicamente imposible (cintura <= cuello) devolvemos
    // un valor conservador para que la UI no truene; el usuario verá el aviso.
    return 20.0;
  }
}

/// Rangos de grasa corporal usados por el selector visual (Opción 1).
class BodyFatRange {
  final String key;
  final String label;
  final String description;
  final int min;
  final int max;
  final int recommended; // valor medio que se usa al elegir la tarjeta

  const BodyFatRange({
    required this.key,
    required this.label,
    required this.description,
    required this.min,
    required this.max,
    required this.recommended,
  });

  static const List<BodyFatRange> maleRanges = [
    BodyFatRange(
      key: 'competition',
      label: 'Muy definido',
      description: 'Abdomen perfectamente marcado, venas visibles. (Nivel competicion)',
      min: 6,
      max: 9,
      recommended: 8,
    ),
    BodyFatRange(
      key: 'athletic',
      label: 'Atletico',
      description: 'Abdominales visibles sin esforzarse, aspecto magro.',
      min: 10,
      max: 13,
      recommended: 12,
    ),
    BodyFatRange(
      key: 'average_low',
      label: 'Estetico / Promedio bajo',
      description: 'Se nota la forma atletica, abdomen se intuye con buena luz.',
      min: 14,
      max: 17,
      recommended: 15,
    ),
    BodyFatRange(
      key: 'average_high',
      label: 'Promedio alto',
      description: 'Aspecto mas blando, grasa acumulada en abdomen bajo y lados.',
      min: 18,
      max: 22,
      recommended: 20,
    ),
    BodyFatRange(
      key: 'overweight',
      label: 'Sobrepeso',
      description: 'Curva abdominal pronunciada, sin division muscular.',
      min: 23,
      max: 35,
      recommended: 26,
    ),
  ];

  static const List<BodyFatRange> femaleRanges = [
    BodyFatRange(
      key: 'competition',
      label: 'Muy definido',
      description: 'Abdomen y oblicuos marcados, venas visibles. (Nivel competicion)',
      min: 14,
      max: 17,
      recommended: 15,
    ),
    BodyFatRange(
      key: 'athletic',
      label: 'Atletico',
      description: 'Abdomen tonico, brazos y piernas definidos.',
      min: 18,
      max: 22,
      recommended: 20,
    ),
    BodyFatRange(
      key: 'average_low',
      label: 'Estetico / Promedio bajo',
      description: 'Forma atletica sutil, abdomen se nota con esfuerzo.',
      min: 23,
      max: 26,
      recommended: 24,
    ),
    BodyFatRange(
      key: 'average_high',
      label: 'Promedio alto',
      description: 'Curvas mas suaves, menos definicion en abdomen.',
      min: 27,
      max: 32,
      recommended: 29,
    ),
    BodyFatRange(
      key: 'overweight',
      label: 'Sobrepeso',
      description: 'Mayor volumen corporal, sin division muscular visible.',
      min: 33,
      max: 45,
      recommended: 36,
    ),
  ];
}
