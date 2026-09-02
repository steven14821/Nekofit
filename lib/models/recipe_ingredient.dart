import 'nutritional_item.dart';
import 'pantry_item.dart';

/// Ingrediente de una receta construida por el usuario.
///
/// Puede tener dos orígenes:
/// 1. **Despensa** (`isAiEstimated = false`): macros reales del PantryItem.
/// 2. **Libre con IA** (`isAiEstimated = true`): el usuario escribió el
///    nombre libremente y Gemini estimó los macros por 100g. El [source]
///    es un PantryItem "fantasma" (id vacío) que solo lleva los macros.
class RecipeIngredient {
  final PantryItem source;
  final double grams;

  /// Verdadero cuando los macros fueron estimados por Gemini IA,
  /// no obtenidos de un producto real de la despensa.
  final bool isAiEstimated;

  const RecipeIngredient({
    required this.source,
    required this.grams,
    this.isAiEstimated = false,
  });

  /// Constructor para ingredientes libres cuyas macros las estimó la IA.
  ///
  /// Crea un PantryItem "fantasma" con id vacío para que los getters
  /// de macros funcionen con el mismo pipeline que los ingredientes reales.
  factory RecipeIngredient.fromAi({
    required String name,
    required double grams,
    required double caloriesPer100,
    required double proteinsPer100,
    required double carbsPer100,
    required double fatsPer100,
  }) {
    final ghost = PantryItem(
      id: '',
      name: name,
      category: 'Proteínas',
      isAvailable: true,
      quantity: '${grams.toInt()}g',
      calories: caloriesPer100,
      proteins: proteinsPer100,
      carbs: carbsPer100,
      fats: fatsPer100,
      lastReplenished: DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ),
    );
    return RecipeIngredient(
      source: ghost,
      grams: grams,
      isAiEstimated: true,
    );
  }

  /// Porción nutricional sobre la que se delega el cálculo de macros.
  ///
  /// El [source] siempre trae macros por 100g: reales (despensa) o
  /// estimados por IA (pantry item "fantasma"). [g] escala a la porción.
  NutritionalItem get portion => NutritionalItem(
        name: source.name,
        grams: grams,
        caloriesPer100: source.calories,
        proteinsPer100: source.proteins,
        carbsPer100: source.carbs,
        fatsPer100: source.fats,
      );

  /// Macros totales del ingrediente calculados a partir de los valores
  /// por 100g escalados a [grams] (regla única en [NutritionalItem]).
  double get calories => portion.calories;
  double get proteins => portion.proteins;
  double get carbs => portion.carbs;
  double get fats => portion.fats;

  RecipeIngredient copyWith({double? grams}) => RecipeIngredient(
        source: source,
        grams: grams ?? this.grams,
        isAiEstimated: isAiEstimated,
      );
}
