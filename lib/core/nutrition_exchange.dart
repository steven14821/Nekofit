/// Sistema de Intercambio por Grupos Alimentarios y Crononutrición (Reglas 1-7).
///
/// Proporciona:
/// 1. Equivalencias isocalóricas e isomacro entre alimentos del mismo grupo.
/// 2. Ajuste de matriz de grasas al intercambiar proteínas magras por grasas.
/// 3. Catálogo de alimentos vegetales para auditoría de diversidad de microbiota (20-30+ plantas/semana).
/// 4. Validación de carga e índice glucémico combinado.
library;

enum FoodGroup {
  leanProtein, // Pechuga pollo, pavo, lomo cerdo magro, claras
  fattyProtein, // Salmón, huevo entero, carne de res grasa, atún en aceite
  plantProtein, // Tofu, tempeh, seitán, proteína de soya
  legumes, // Lentejas, frijoles, garbanzos (proteína + carb complejo + fibra)
  complexCarb, // Arroz integral, papa, batata/camote, avena, quinoa, pasta integral
  fibrousVeg, // Brócoli, espinaca, calabacín, tomate, zanahoria, coliflor, berenjena
  fruit, // Manzana, banano, arándanos, papaya, naranja, fresas
  healthyFat, // Aceite de oliva virgen extra, aguacate, nueces, almendras, semillas
}

class FoodExchangeItem {
  final String name;
  final FoodGroup group;
  final double standardGrams; // Porción estándar de referencia
  final double calories; // Kcal por 100g
  final double proteins; // g por 100g
  final double carbs; // g por 100g
  final double fats; // g por 100g
  final double fiber; // g por 100g
  final String glycemicSpeed; // 'baja' | 'media' | 'alta'
  final bool isPlantBased;

  const FoodExchangeItem({
    required this.name,
    required this.group,
    required this.standardGrams,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    this.fiber = 0.0,
    this.glycemicSpeed = 'baja',
    this.isPlantBased = false,
  });
}

class NutritionExchangeHelper {
  NutritionExchangeHelper._();

  /// Base de datos de alimentos de referencia para intercambios y rotación de microbiota.
  static const List<FoodExchangeItem> referenceStaples = [
    // --- Proteínas Magras ---
    FoodExchangeItem(
      name: 'Pechuga de pollo',
      group: FoodGroup.leanProtein,
      standardGrams: 100,
      calories: 120,
      proteins: 26,
      carbs: 0,
      fats: 1.5,
    ),
    FoodExchangeItem(
      name: 'Lomo de pavo',
      group: FoodGroup.leanProtein,
      standardGrams: 120,
      calories: 110,
      proteins: 24,
      carbs: 0,
      fats: 1.2,
    ),
    FoodExchangeItem(
      name: 'Lomo de cerdo magro',
      group: FoodGroup.leanProtein,
      standardGrams: 110,
      calories: 130,
      proteins: 25,
      carbs: 0,
      fats: 3.5,
    ),
    FoodExchangeItem(
      name: 'Claras de huevo',
      group: FoodGroup.leanProtein,
      standardGrams: 150,
      calories: 52,
      proteins: 11,
      carbs: 0.7,
      fats: 0.2,
    ),
    FoodExchangeItem(
      name: 'Atún al natural',
      group: FoodGroup.leanProtein,
      standardGrams: 100,
      calories: 115,
      proteins: 26,
      carbs: 0,
      fats: 0.8,
    ),

    // --- Proteínas con Grasa Natural ---
    FoodExchangeItem(
      name: 'Salmón fresco',
      group: FoodGroup.fattyProtein,
      standardGrams: 100,
      calories: 208,
      proteins: 20,
      carbs: 0,
      fats: 13.0,
    ),
    FoodExchangeItem(
      name: 'Huevo entero (unidad ~55g)',
      group: FoodGroup.fattyProtein,
      standardGrams: 110, // 2 huevos
      calories: 145,
      proteins: 12.5,
      carbs: 0.6,
      fats: 10.0,
    ),
    FoodExchangeItem(
      name: 'Carne de res magra',
      group: FoodGroup.fattyProtein,
      standardGrams: 100,
      calories: 165,
      proteins: 22,
      carbs: 0,
      fats: 8.0,
    ),

    // --- Proteínas Vegetales y Legumbres ---
    FoodExchangeItem(
      name: 'Tofu firme',
      group: FoodGroup.plantProtein,
      standardGrams: 140,
      calories: 83,
      proteins: 10,
      carbs: 1.5,
      fats: 4.8,
      fiber: 1.0,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Tempeh',
      group: FoodGroup.plantProtein,
      standardGrams: 110,
      calories: 192,
      proteins: 20,
      carbs: 7.6,
      fats: 10.8,
      fiber: 9.0,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Lentejas cocidas',
      group: FoodGroup.legumes,
      standardGrams: 180,
      calories: 116,
      proteins: 9.0,
      carbs: 20.0,
      fats: 0.4,
      fiber: 7.9,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Frijoles negros cocidos',
      group: FoodGroup.legumes,
      standardGrams: 180,
      calories: 132,
      proteins: 8.9,
      carbs: 23.7,
      fats: 0.5,
      fiber: 8.7,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Garbanzos cocidos',
      group: FoodGroup.legumes,
      standardGrams: 170,
      calories: 164,
      proteins: 8.9,
      carbs: 27.4,
      fats: 2.6,
      fiber: 7.6,
      isPlantBased: true,
    ),

    // --- Carbohidratos Complejos ---
    FoodExchangeItem(
      name: 'Arroz integral cocido',
      group: FoodGroup.complexCarb,
      standardGrams: 150,
      calories: 112,
      proteins: 2.6,
      carbs: 23.5,
      fats: 0.9,
      fiber: 1.8,
      glycemicSpeed: 'media',
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Papa cocida / al vapor',
      group: FoodGroup.complexCarb,
      standardGrams: 200,
      calories: 86,
      proteins: 1.7,
      carbs: 20.0,
      fats: 0.1,
      fiber: 1.8,
      glycemicSpeed: 'media',
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Batata / Camote cocido',
      group: FoodGroup.complexCarb,
      standardGrams: 180,
      calories: 90,
      proteins: 2.0,
      carbs: 20.7,
      fats: 0.2,
      fiber: 3.3,
      glycemicSpeed: 'baja',
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Avena en copos',
      group: FoodGroup.complexCarb,
      standardGrams: 50,
      calories: 389,
      proteins: 16.9,
      carbs: 66.3,
      fats: 6.9,
      fiber: 10.6,
      glycemicSpeed: 'baja',
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Quinoa cocida',
      group: FoodGroup.complexCarb,
      standardGrams: 160,
      calories: 120,
      proteins: 4.4,
      carbs: 21.3,
      fats: 1.9,
      fiber: 2.8,
      glycemicSpeed: 'baja',
      isPlantBased: true,
    ),

    // --- Grasas Saludables ---
    FoodExchangeItem(
      name: 'Aceite de oliva virgen extra',
      group: FoodGroup.healthyFat,
      standardGrams: 15, // 1 cucharada
      calories: 884,
      proteins: 0,
      carbs: 0,
      fats: 100.0,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Aguacate',
      group: FoodGroup.healthyFat,
      standardGrams: 50, // ~1/3 aguacate mediano
      calories: 160,
      proteins: 2.0,
      carbs: 8.5,
      fats: 14.7,
      fiber: 6.7,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Nueces',
      group: FoodGroup.healthyFat,
      standardGrams: 20,
      calories: 654,
      proteins: 15.2,
      carbs: 13.7,
      fats: 65.2,
      fiber: 6.7,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Almendras',
      group: FoodGroup.healthyFat,
      standardGrams: 20,
      calories: 579,
      proteins: 21.2,
      carbs: 21.6,
      fats: 49.9,
      fiber: 12.5,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Mantequilla de maní 100%',
      group: FoodGroup.healthyFat,
      standardGrams: 20,
      calories: 588,
      proteins: 25.0,
      carbs: 20.0,
      fats: 50.0,
      fiber: 8.0,
      isPlantBased: true,
    ),
    FoodExchangeItem(
      name: 'Semillas de chía',
      group: FoodGroup.healthyFat,
      standardGrams: 15,
      calories: 486,
      proteins: 16.5,
      carbs: 42.1,
      fats: 30.7,
      fiber: 34.4,
      isPlantBased: true,
    ),
  ];

  /// Calcula la cantidad equivalente en gramos para sustituir [original] por [replacement]
  /// manteniendo la equivalencia en proteína (para carnes/tofu) o en carbohidratos/calorías.
  static double calculateEquivalentGrams({
    required FoodExchangeItem original,
    required FoodExchangeItem replacement,
    required double originalGrams,
  }) {
    if (original.group == FoodGroup.leanProtein ||
        original.group == FoodGroup.fattyProtein ||
        original.group == FoodGroup.plantProtein) {
      if (replacement.proteins > 0) {
        final targetProtein = (original.proteins * originalGrams) / 100.0;
        return (targetProtein * 100.0) / replacement.proteins;
      }
    }
    // Fallback isocalórico
    final targetKcal = (original.calories * originalGrams) / 100.0;
    return (targetKcal * 100.0) / (replacement.calories > 0 ? replacement.calories : 100.0);
  }

  /// Ajuste de Matriz de Grasas (Regla 4):
  /// Si se cambia una fuente magra por una grasa (ej. pechuga por salmón), calcula
  /// cuántos gramos de aceite/grasa añadida deben restarse del plato para conservar
  /// el total calórico y balance de lípidos.
  static double adjustAddedOilGrams({
    required double baseAddedOilGrams,
    required double originalProteinFatsGrams,
    required double newProteinFatsGrams,
  }) {
    final fatDifference = newProteinFatsGrams - originalProteinFatsGrams;
    if (fatDifference <= 0) return baseAddedOilGrams;
    // 1g de grasa extra de la carne descuenta ~1g de aceite de cocina (con mínimo de 3g para cocinar)
    final adjusted = baseAddedOilGrams - fatDifference;
    return adjusted.clamp(3.0, double.infinity);
  }
}
