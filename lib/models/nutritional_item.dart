/// Base nutricional común: una porción con gramos concretos.
///
/// Centraliza la única regla de cálculo que antes estaba duplicada en
/// [RecognizedFood] y [RecipeIngredient]:
///
///     total = per100 * grams / 100
///
/// - [caloriesPer100], [proteinsPer100], [carbsPer100] y [fatsPer100] son
///   valores por cada 100g del alimento.
/// - [grams] es la porción concreta.
/// - Los getters ([calories], [proteins], [carbs], [fats]) derivan el total.
///
/// Subclases (ej. [RecognizedFood]) solo aportan metadata (origen, id de
/// despensa) y delegan el cálculo numérico a esta clase.
class NutritionalItem {
  final String name;

  /// Gramos de la porción concreta.
  final double grams;

  final double caloriesPer100;
  final double proteinsPer100;
  final double carbsPer100;
  final double fatsPer100;

  const NutritionalItem({
    required this.name,
    required this.grams,
    required this.caloriesPer100,
    required this.proteinsPer100,
    required this.carbsPer100,
    required this.fatsPer100,
  });

  /// Total de calorías de la porción: `per100 * grams / 100`.
  double get calories => caloriesPer100 * (grams / 100.0);

  /// Total de proteínas de la porción: `per100 * grams / 100`.
  double get proteins => proteinsPer100 * (grams / 100.0);

  /// Total de carbohidratos de la porción: `per100 * grams / 100`.
  double get carbs => carbsPer100 * (grams / 100.0);

  /// Total de grasas de la porción: `per100 * grams / 100`.
  double get fats => fatsPer100 * (grams / 100.0);

  /// Copia con [newGrams] actualizados; los totales se recalculan desde los
  /// valores por 100g (evita error acumulativo al arrastrar sliders).
  NutritionalItem withGrams(double newGrams) {
    return NutritionalItem(
      name: name,
      grams: newGrams,
      caloriesPer100: caloriesPer100,
      proteinsPer100: proteinsPer100,
      carbsPer100: carbsPer100,
      fatsPer100: fatsPer100,
    );
  }

  @override
  String toString() =>
      'NutritionalItem($name, ${grams}g, ${calories.toStringAsFixed(0)} kcal)';
}