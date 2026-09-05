import 'package:flutter/foundation.dart';

/// Una comida dentro del plan semanal.
@immutable
class PlannedMeal {
  final String slot; // 'Desayuno' | 'Almuerzo' | 'Merienda' | 'Cena' | 'Snack'
  final String title;
  final String description;
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;

  /// IDs de PantryItem que se usan como ingredientes (opcional).
  final List<String> pantryItemIds;

  /// Si el usuario ya marcó esta comida como "hecha".
  final bool done;

  const PlannedMeal({
    required this.slot,
    required this.title,
    required this.description,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    this.pantryItemIds = const [],
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        'slot': slot,
        'title': title,
        'description': description,
        'calories': calories,
        'proteins': proteins,
        'carbs': carbs,
        'fats': fats,
        'pantryItemIds': pantryItemIds,
        'done': done,
      };

  factory PlannedMeal.fromMap(Map<String, dynamic> map) => PlannedMeal(
        slot: map['slot'] ?? 'Almuerzo',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        proteins: (map['proteins'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fats: (map['fats'] as num?)?.toDouble() ?? 0,
        pantryItemIds: ((map['pantryItemIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        done: map['done'] == true,
      );

  PlannedMeal copyWith({bool? done}) => PlannedMeal(
        slot: slot,
        title: title,
        description: description,
        calories: calories,
        proteins: proteins,
        carbs: carbs,
        fats: fats,
        pantryItemIds: pantryItemIds,
        done: done ?? this.done,
      );
}

/// Un día del plan (lunes, martes, ...).
@immutable
class PlannedDay {
  final DateTime date;
  final List<PlannedMeal> meals;

  const PlannedDay({required this.date, required this.meals});

  double get totalCalories =>
      meals.fold(0.0, (s, m) => s + m.calories);
  double get totalProteins => meals.fold(0.0, (s, m) => s + m.proteins);
  double get totalCarbs => meals.fold(0.0, (s, m) => s + m.carbs);
  double get totalFats => meals.fold(0.0, (s, m) => s + m.fats);

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'meals': meals.map((m) => m.toMap()).toList(),
      };

  factory PlannedDay.fromMap(Map<String, dynamic> map) => PlannedDay(
        date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
        meals: ((map['meals'] as List?) ?? const [])
            .map((e) => PlannedMeal.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  PlannedDay copyWith({List<PlannedMeal>? meals}) =>
      PlannedDay(date: date, meals: meals ?? this.meals);
}

/// Plan semanal completo: 7 días con el número de comidas definido en el plan.
@immutable
class WeeklyPlan {
  final DateTime weekStart; // lunes de la semana
  final List<PlannedDay> days;
  final DateTime generatedAt;
  final String source; // 'gemini' | 'cache' | 'fallback'

  const WeeklyPlan({
    required this.weekStart,
    required this.days,
    required this.generatedAt,
    this.source = 'gemini',
  });

  /// Macros totales de toda la semana (útil para overview).
  double get totalCalories =>
      days.fold(0.0, (s, d) => s + d.totalCalories);
  double get totalProteins =>
      days.fold(0.0, (s, d) => s + d.totalProteins);
  double get totalCarbs => days.fold(0.0, (s, d) => s + d.totalCarbs);
  double get totalFats => days.fold(0.0, (s, d) => s + d.totalFats);

  /// Promedio diario (kcal/día) — el número que de verdad importa.
  double get avgDailyCalories =>
      days.isEmpty ? 0 : totalCalories / days.length;

  Map<String, dynamic> toMap() => {
        'weekStart': weekStart.toIso8601String(),
        'days': days.map((d) => d.toMap()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        'source': source,
      };

  factory WeeklyPlan.fromMap(Map<String, dynamic> map) => WeeklyPlan(
        weekStart:
            DateTime.tryParse(map['weekStart'] ?? '') ?? DateTime.now(),
        days: ((map['days'] as List?) ?? const [])
            .map((e) => PlannedDay.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        generatedAt:
            DateTime.tryParse(map['generatedAt'] ?? '') ?? DateTime.now(),
        source: map['source'] ?? 'gemini',
      );

  /// Devuelve el lunes de la semana que contiene [date].
  static DateTime mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }
}
