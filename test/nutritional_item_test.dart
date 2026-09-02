import 'package:flutter_test/flutter_test.dart';

import 'package:nekofit/models/nutritional_item.dart';
import 'package:nekofit/models/pantry_item.dart';
import 'package:nekofit/models/recipe_ingredient.dart';
import 'package:nekofit/models/recognized_food.dart';

PantryItem _pantry({
  String id = 'p-1',
  String name = 'Pollo',
  double cal = 165,
  double prot = 31,
  double carb = 0,
  double fat = 3.6,
}) {
  return PantryItem(
    id: id,
    name: name,
    category: 'Proteínas',
    isAvailable: true,
    quantity: '500g',
    calories: cal,
    proteins: prot,
    carbs: carb,
    fats: fat,
    lastReplenished: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

void main() {
  group('NutritionalItem', () {
    const item = NutritionalItem(
      name: 'Avena',
      grams: 75,
      caloriesPer100: 389,
      proteinsPer100: 16.9,
      carbsPer100: 66.3,
      fatsPer100: 6.9,
    );

    test('totales = per100 * grams / 100', () {
      expect(item.calories, closeTo(291.75, 0.001));
      expect(item.proteins, closeTo(12.675, 0.001));
      expect(item.carbs, closeTo(49.725, 0.001));
      expect(item.fats, closeTo(5.175, 0.001));
    });

    test('withGrams recalcula desde per-100 sin arrastrar precisión', () {
      final half = item.withGrams(37.5);
      expect(half.grams, 37.5);
      expect(half.caloriesPer100, 389);
      expect(half.calories, closeTo(145.875, 0.001));
      // 100g == los valores por 100g exactos.
      final kilo = item.withGrams(100);
      expect(kilo.calories, closeTo(389, 0.001));
      expect(kilo.proteins, closeTo(16.9, 0.001));
    });
  });

  group('RecognizedFood', () {
    test('fromGemini con match de despensa usa macros reales', () {
      final f = RecognizedFood.fromGemini(
        name: 'Pollo a la plancha',
        estimatedGrams: 150,
        pantryMatch: _pantry(),
      );
      expect(f.pantryItemId, 'p-1');
      expect(f.pantryItemName, 'Pollo');
      expect(f.estimatedGrams, 150);
      expect(f.caloriesPer100, 165);
      expect(f.calories, closeTo(247.5, 0.001));
      expect(f.proteins, closeTo(46.5, 0.001));
    });

    test('fromGemini sin match usa macros estimados por IA', () {
      final f = RecognizedFood.fromGemini(
        name: 'Chía',
        estimatedGrams: 30,
        aiCaloriesPer100: 486,
        aiProteinsPer100: 16.5,
        aiCarbsPer100: 42,
        aiFatsPer100: 30.7,
      );
      expect(f.pantryItemId, isNull);
      expect(f.calories, closeTo(145.8, 0.001));
      expect(f.proteins, closeTo(4.95, 0.001));
    });

    test('withGrams conserva metadata y recalcula totales', () {
      final f = RecognizedFood.fromGemini(
        name: 'Pollo',
        estimatedGrams: 100,
        pantryMatch: _pantry(),
      );
      final scaled = f.withGrams(300);
      expect(scaled.pantryItemId, 'p-1');
      expect(scaled.grams, 300);
      expect(scaled.calories, closeTo(495, 0.001));
    });

    test('copyWith por per-100 deriva totales (caso slider)', () {
      final f = RecognizedFood.fromGemini(
        name: 'Arroz',
        estimatedGrams: 100,
        aiCaloriesPer100: 130,
        aiProteinsPer100: 2.7,
        aiCarbsPer100: 28,
        aiFatsPer100: 0.3,
      );
      final edited = f.copyWith(
        caloriesPer100: 200,
        proteinsPer100: 4,
        carbsPer100: 45,
        fatsPer100: 1,
      );
      expect(edited.calories, closeTo(200, 0.001));
      // El total deriva del per-100 nuevo, no arrastra el viejo.
      expect(edited.proteins, closeTo(4, 0.001));
    });

    test('toMap conserva el contrato antiguo (grams)', () {
      final f = RecognizedFood.fromGemini(
        name: 'Huevo',
        estimatedGrams: 55,
        pantryMatch: _pantry(name: 'Huevo', cal: 143, prot: 12.6, carb: 0.7, fat: 9.5),
      );
      final map = f.toMap();
      expect(map['name'], 'Huevo');
      expect(map['grams'], 55);
      expect((map['calories'] as double), closeTo(78.65, 0.001));
      expect(map['pantryItemId'], 'p-1');
    });
  });

  group('RecipeIngredient', () {
    test('parte real de despensa escala vía porción nutricional', () {
      final ri = RecipeIngredient(
        source: _pantry(),
        grams: 250,
      );
      expect(ri.isAiEstimated, isFalse);
      expect(ri.calories, closeTo(412.5, 0.001));
      expect(ri.proteins, closeTo(77.5, 0.001));
    });

    test('fromAi crea pantry fantasma y escala igual que uno real', () {
      final ri = RecipeIngredient.fromAi(
        name: 'Almendras',
        grams: 40,
        caloriesPer100: 579,
        proteinsPer100: 21.2,
        carbsPer100: 6.5,
        fatsPer100: 50,
      );
      expect(ri.isAiEstimated, isTrue);
      expect(ri.source.id, '');
      expect(ri.portion.name, 'Almendras');
      expect(ri.calories, closeTo(231.6, 0.001));
      expect(ri.fats, closeTo(20, 0.001));
    });
  });

  group('Coherencia', () {
    test('RecognizedFood con match y RecipeIngredient coinciden', () {
      final item = _pantry();
      final f = RecognizedFood.fromGemini(
        name: 'Pollo',
        estimatedGrams: 250,
        pantryMatch: item,
      );
      final ri = RecipeIngredient(source: item, grams: 250);
      expect(f.caloriesPer100, ri.source.calories);
      expect(f.calories, ri.calories);
      expect(f.proteins, ri.proteins);
    });
  });
}