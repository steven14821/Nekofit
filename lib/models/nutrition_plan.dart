import 'package:cloud_firestore/cloud_firestore.dart';

/// Fase nutricional de un plan. Determina cómo se ajusta la meta calórica
/// sobre el mantenimiento (TDEE) y, al vencer, qué fase viene después.
enum PlanPhase {
  cut, // déficit calórico (pérdida de grasa)
  maintenance, // equilibrio calórico (conservar)
  leanGain, // superávit moderado (ganancia muscular)
  recomposition; // recomposición corporal (en mantenimiento, redistribuyendo macros)

  /// Al terminar un plan de fase, indica la fase de transición recomendada:
  /// déficit → mantenimiento, superávit → mantenimiento, mantenimiento →
  /// mantenimiento, recomposición → mantenimiento.
  PlanPhase get projectedNext {
    switch (this) {
      case PlanPhase.cut:
        return PlanPhase.maintenance;
      case PlanPhase.maintenance:
        return PlanPhase.maintenance;
      case PlanPhase.leanGain:
        return PlanPhase.maintenance;
      case PlanPhase.recomposition:
        return PlanPhase.maintenance;
    }
  }

  static PlanPhase fromString(String s) {
    switch (s) {
      case 'cut':
        return PlanPhase.cut;
      case 'lean_gain':
        return PlanPhase.leanGain;
      case 'recomposition':
        return PlanPhase.recomposition;
      case 'maintenance':
      default:
        return PlanPhase.maintenance;
    }
  }

  String get storageName {
    switch (this) {
      case PlanPhase.cut:
        return 'cut';
      case PlanPhase.maintenance:
        return 'maintenance';
      case PlanPhase.leanGain:
        return 'lean_gain';
      case PlanPhase.recomposition:
        return 'recomposition';
    }
  }
}

/// Distribución de comidas del día: cuántas tomas y ventana de ayuno
/// intermitente (opcional). SOLO da forma a las recetas del plan IA.
class MealSchedule {
  final int mealsPerDay; // 3 | 4 | 5
  final bool intermittentFasting;
  final int fastingHours; // 0 si no aplica; típico 16 (16:8)

  const MealSchedule({
    this.mealsPerDay = 4,
    this.intermittentFasting = false,
    this.fastingHours = 0,
  });

  Map<String, dynamic> toMap() => {
        'mealsPerDay': mealsPerDay,
        'intermittentFasting': intermittentFasting,
        'fastingHours': fastingHours,
      };

  factory MealSchedule.fromMap(Map<String, dynamic> map) => MealSchedule(
        mealsPerDay: (map['mealsPerDay'] as num?)?.toInt() ?? 4,
        intermittentFasting: map['intermittentFasting'] == true,
        fastingHours: (map['fastingHours'] as num?)?.toInt() ?? 0,
      );
}

/// Contexto de personalización extrema: historial médico, preferencias
/// alimentarias y alimentos imprescindibles/aversiones.
class NutritionContext {
  /// Condiciones médicas: insulino-resistencia, hipertensión, hipotiroidismo...
  final List<String> medicalConditions;
  /// Preferencias/restricciones: vegana, keto, sin gluten, sin lactosa...
  final List<String> dietaryPreferences;
  /// Alimentos "imprescindibles" para mantener en el plan (fidelización).
  final List<String> mustHaveFoods;
  /// Aversiones estrictas (excluir del plan).
  final List<String> aversions;

  const NutritionContext({
    this.medicalConditions = const [],
    this.dietaryPreferences = const [],
    this.mustHaveFoods = const [],
    this.aversions = const [],
  });

  bool get isEmpty =>
      medicalConditions.isEmpty &&
      dietaryPreferences.isEmpty &&
      mustHaveFoods.isEmpty &&
      aversions.isEmpty;

  Map<String, dynamic> toMap() => {
        'medicalConditions': medicalConditions,
        'dietaryPreferences': dietaryPreferences,
        'mustHaveFoods': mustHaveFoods,
        'aversions': aversions,
      };

  factory NutritionContext.fromMap(Map<String, dynamic> map) => NutritionContext(
        medicalConditions: ((map['medicalConditions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        dietaryPreferences: ((map['dietaryPreferences'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        mustHaveFoods: ((map['mustHaveFoods'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        aversions: ((map['aversions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Plan nutricional con plazo definido (4/8/12 semanas). Vive en
/// `users/{uid}/plans/{id}` y es la fuente de verdad para la meta calórica
/// y la proyección de fase al vencer.
class NutritionPlan {
  final String? id;
  final PlanPhase phase;
  final int durationWeeks; // 4 | 8 | 12
  final DateTime startDate;
  final DateTime endDate;
  final MealSchedule schedule;
  final NutritionContext context;
  final DateTime createdAt;

  NutritionPlan({
    this.id,
    required this.phase,
    required this.durationWeeks,
    DateTime? startDate,
    DateTime? endDate,
    this.schedule = const MealSchedule(),
    this.context = const NutritionContext(),
    DateTime? createdAt,
  })  : startDate = startDate ?? DateTime.now(),
        endDate = endDate ??
            (startDate ?? DateTime.now()).add(Duration(days: 7 * durationWeeks)),
        createdAt = createdAt ?? DateTime.now();

  bool get hasExpired => DateTime.now().isAfter(endDate);

  /// Días restantes del plan (0 si ya venció).
  int get daysRemaining {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Fase de transición que se sugiere al vencer.
  PlanPhase get nextPhase => phase.projectedNext;

  Map<String, dynamic> toMap() => {
        'phase': phase.storageName,
        'durationWeeks': durationWeeks,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'schedule': schedule.toMap(),
        'context': context.toMap(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory NutritionPlan.fromMap(Map<String, dynamic> map, {String? id}) =>
      NutritionPlan(
        id: id,
        phase: PlanPhase.fromString(map['phase'] ?? ''),
        durationWeeks: ((map['durationWeeks'] as num?)?.toInt() ?? 0) > 0
            ? (map['durationWeeks'] as num).toInt()
            : 8,
        startDate: _parseDate(map['startDate']) ?? DateTime.now(),
        endDate: _parseDate(map['endDate']) ??
            DateTime.now().add(const Duration(days: 7 * 8)),
        schedule: map['schedule'] != null
            ? MealSchedule.fromMap(
                Map<String, dynamic>.from(map['schedule'] as Map))
            : const MealSchedule(),
        context: map['context'] != null
            ? NutritionContext.fromMap(
                Map<String, dynamic>.from(map['context'] as Map))
            : const NutritionContext(),
        createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      );

  static DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return DateTime.tryParse(v?.toString() ?? '');
  }
}