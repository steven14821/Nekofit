import 'package:cloud_firestore/cloud_firestore.dart';

/// Ingrediente serializable dentro de una receta guardada.
class SavedIngredient {
  final String name;
  final double grams;
  final double caloriesPer100;
  final double proteinsPer100;
  final double carbsPer100;
  final double fatsPer100;
  final String pantryItemId;

  const SavedIngredient({
    required this.name,
    required this.grams,
    required this.caloriesPer100,
    required this.proteinsPer100,
    required this.carbsPer100,
    required this.fatsPer100,
    this.pantryItemId = '',
  });

  double get calories => caloriesPer100 * (grams / 100.0);
  double get proteins => proteinsPer100 * (grams / 100.0);
  double get carbs => carbsPer100 * (grams / 100.0);
  double get fats => fatsPer100 * (grams / 100.0);

  Map<String, dynamic> toMap() => {
        'name': name,
        'grams': grams,
        'caloriesPer100': caloriesPer100,
        'proteinsPer100': proteinsPer100,
        'carbsPer100': carbsPer100,
        'fatsPer100': fatsPer100,
        'pantryItemId': pantryItemId,
      };

  factory SavedIngredient.fromMap(Map<String, dynamic> m) => SavedIngredient(
        name: m['name'] ?? '',
        grams: (m['grams'] ?? 100).toDouble(),
        caloriesPer100: (m['caloriesPer100'] ?? 0).toDouble(),
        proteinsPer100: (m['proteinsPer100'] ?? 0).toDouble(),
        carbsPer100: (m['carbsPer100'] ?? 0).toDouble(),
        fatsPer100: (m['fatsPer100'] ?? 0).toDouble(),
        pantryItemId: m['pantryItemId'] ?? '',
      );
}

/// Receta guardada por el usuario en `users/{uid}/recipes`.
///
/// Almacena el nombre, tipo de comida y la lista de ingredientes con sus
/// macros pre-computados. Cuando el usuario elige una receta, se crean
/// entradas de comida individuales (mismo esquema que el escáner) y se
/// descuentan los items reales de la despensa.
class SavedRecipe {
  final String id;
  final String name;
  final String mealType;
  final List<SavedIngredient> ingredients;
  final double totalCalories;
  final double totalProteins;
  final double totalCarbs;
  final double totalFats;
  final DateTime createdAt;

  const SavedRecipe({
    required this.id,
    required this.name,
    required this.mealType,
    required this.ingredients,
    required this.totalCalories,
    required this.totalProteins,
    required this.totalCarbs,
    required this.totalFats,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'mealType': mealType,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
        'totalCalories': totalCalories,
        'totalProteins': totalProteins,
        'totalCarbs': totalCarbs,
        'totalFats': totalFats,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory SavedRecipe.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SavedRecipe(
      id: doc.id,
      name: data['name'] ?? '',
      mealType: data['mealType'] ?? 'lunch',
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.map((e) => SavedIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCalories: (data['totalCalories'] ?? 0).toDouble(),
      totalProteins: (data['totalProteins'] ?? 0).toDouble(),
      totalCarbs: (data['totalCarbs'] ?? 0).toDouble(),
      totalFats: (data['totalFats'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
