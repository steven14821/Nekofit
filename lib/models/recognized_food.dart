import 'nutritional_item.dart';
import 'pantry_item.dart';

/// Componente reconocido por Gemini Vision en una foto de plato.
///
/// Extiende [NutritionalItem]: el cálculo de totales por porción vive en la
/// base; aquí solo se agrega la metadata del match con la despensa.
class RecognizedFood extends NutritionalItem {
  /// id del [PantryItem] de la despensa si hubo match (null = solo IA).
  final String? pantryItemId;
  final String? pantryItemName;

  const RecognizedFood({
    required super.name,
    required super.grams,
    required super.caloriesPer100,
    required super.proteinsPer100,
    required super.carbsPer100,
    required super.fatsPer100,
    this.pantryItemId,
    this.pantryItemName,
  });

  /// Nombre de campo histórico usado por UI/caché.
  double get estimatedGrams => grams;

  /// Crea una instancia desde la respuesta cruda de Gemini + datos del pantry.
  /// Si hay match en despensa, usa los macros reales. Si no, usa los
  /// estimados por la IA como fallback.
  factory RecognizedFood.fromGemini({
    required String name,
    required double estimatedGrams,
    PantryItem? pantryMatch,
    double aiCaloriesPer100 = 0,
    double aiProteinsPer100 = 0,
    double aiCarbsPer100 = 0,
    double aiFatsPer100 = 0,
  }) {
    if (pantryMatch != null) {
      return RecognizedFood(
        name: pantryMatch.name,
        grams: estimatedGrams,
        caloriesPer100: pantryMatch.calories,
        proteinsPer100: pantryMatch.proteins,
        carbsPer100: pantryMatch.carbs,
        fatsPer100: pantryMatch.fats,
        pantryItemId: pantryMatch.id,
        pantryItemName: pantryMatch.name,
      );
    }

    // Sin match en despensa — usar macros estimados por la IA.
    return RecognizedFood(
      name: name,
      grams: estimatedGrams,
      caloriesPer100: aiCaloriesPer100,
      proteinsPer100: aiProteinsPer100,
      carbsPer100: aiCarbsPer100,
      fatsPer100: aiFatsPer100,
    );
  }

  /// Crea una copia con gramos actualizados (para sliders).
  /// Los totales se recalculan desde los per-100 en la base.
  @override
  RecognizedFood withGrams(double newGrams) {
    return RecognizedFood(
      name: name,
      grams: newGrams,
      caloriesPer100: caloriesPer100,
      proteinsPer100: proteinsPer100,
      carbsPer100: carbsPer100,
      fatsPer100: fatsPer100,
      pantryItemId: pantryItemId,
      pantryItemName: pantryItemName,
    );
  }

  RecognizedFood copyWith({
    String? name,
    double? grams,
    double? estimatedGrams,
    double? caloriesPer100,
    double? proteinsPer100,
    double? carbsPer100,
    double? fatsPer100,
    String? pantryItemId,
    String? pantryItemName,
  }) {
    return RecognizedFood(
      name: name ?? this.name,
      grams: grams ?? estimatedGrams ?? this.grams,
      caloriesPer100: caloriesPer100 ?? this.caloriesPer100,
      proteinsPer100: proteinsPer100 ?? this.proteinsPer100,
      carbsPer100: carbsPer100 ?? this.carbsPer100,
      fatsPer100: fatsPer100 ?? this.fatsPer100,
      pantryItemId: pantryItemId ?? this.pantryItemId,
      pantryItemName: pantryItemName ?? this.pantryItemName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'grams': estimatedGrams,
      'calories': calories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'pantryItemId': pantryItemId,
    };
  }
}