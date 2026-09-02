// Tests del pipeline de parsing de GeminiVisionService:
//  - ExtractJsonObject tolera markdown / texto extra / llaves dentro de strings.
//  - parseComponents cruza con la despensa y valida la forma con errores tipados.
//  - PromptTemplates interpola despensa/transcripto/nombre.
//  - Las excepciones tipadas (AIException) exponen userMessage para la UI.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nekofit/models/pantry_item.dart';
import 'package:nekofit/services/ai_exceptions.dart';
import 'package:nekofit/services/gemini_vision_service.dart';
import 'package:nekofit/services/prompt_templates.dart';

PantryItem pantry(String name, {double c = 0, double p = 0, double ca = 0, double f = 0}) {
  return PantryItem(
    id: 'id-$name',
    name: name,
    category: 'Proteínas',
    isAvailable: true,
    quantity: '1 unidad',
    calories: c,
    proteins: p,
    carbs: ca,
    fats: f,
    lastReplenished: DateTime.now(),
  );
}

void main() {
  group('extractJsonObject', () {
    test('JSON plano queda idéntico', () {
      const raw = '{"dish_name":"a","components":[]}';
      expect(GeminiVisionService.extractJsonObject(raw), raw);
    });

    test('envuelto en bloque markdown ```json', () {
      const raw = '```json\n{"dish_name":"a","components":[]}\n```';
      expect(
        GeminiVisionService.extractJsonObject(raw),
        '{"dish_name":"a","components":[]}',
      );
    });

    test('texto antes y después del JSON', () {
      const raw = 'Aquí tienes tu análisis:\n{"components":[]}\nEspero que sirva';
      expect(
        GeminiVisionService.extractJsonObject(raw),
        '{"components":[]}',
      );
    });

    test('llaves dentro de un string no rompen el balance', () {
      const raw =
          '{"dish_name":"un plato {de comida}","components":[{"name":"x","estimated_grams":100}]}';
      final extracted = GeminiVisionService.extractJsonObject(raw);
      expect(extracted, raw);
      // y se puede decodificar
      expect(jsonDecode(extracted)['dish_name'], 'un plato {de comida}');
    });

    test('comillas escapadas dentro de un string', () {
      const raw = '{"name":"dijo \\"hola\\"","estimated_grams":1}';
      expect(GeminiVisionService.extractJsonObject(raw), raw);
    });

    test('sin llaves lanza AIResponseException', () {
      expect(
        () => GeminiVisionService.extractJsonObject('no hay json acá'),
        throwsA(isA<AIResponseException>()),
      );
    });

    test('JSON sin cerrar lanza AIResponseException', () {
      expect(
        () => GeminiVisionService.extractJsonObject('{"components": [1, 2'),
        throwsA(isA<AIResponseException>()),
      );
    });
  });

  group('parseComponents', () {
    test('match en despensa usa los macros reales', () {
      final json = {
        'dish_name': 'plato',
        'components': [
          {
            'name': 'Pollo',
            'estimated_grams': 200,
            'calories_per_100': 165,
            'proteins_per_100': 31,
            'carbs_per_100': 0,
            'fats_per_100': 3.6,
          },
        ],
      };
      final foods = GeminiVisionService.parseComponents(
        json,
        [pantry('Pollo', c: 165, p: 31, f: 3.6)],
      );
      expect(foods, hasLength(1));
      final f = foods.first;
      expect(f.name, 'Pollo'); // nombre del pantry
      expect(f.estimatedGrams, 200);
      expect(f.calories, closeTo(330, 0.001)); // 165 * 2
      expect(f.proteins, closeTo(62, 0.001));
      expect(f.pantryItemId, 'id-Pollo');
    });

    test('sin match usa los macros estimados por la IA', () {
      final json = {
        'components': [
          {
            'name': 'Arroz',
            'estimated_grams': 150,
            'calories_per_100': 130,
            'proteins_per_100': 2.7,
            'carbs_per_100': 28,
            'fats_per_100': 0.3,
          },
        ],
      };
      final foods = GeminiVisionService.parseComponents(json, []);
      expect(foods, hasLength(1));
      final f = foods.first;
      expect(f.pantryItemId, isNull);
      expect(f.calories, closeTo(195, 0.001));
      expect(f.proteinsPer100, closeTo(2.7, 0.001));
    });

    test('sin campo components lanza invalidShape', () {
      expect(
        () => GeminiVisionService.parseComponents({}, []),
        throwsA(isA<AIResponseException>()),
      );
    });

    test('componente sin nombre lanza invalidShape', () {
      final json = {
        'components': [
          {'estimated_grams': 100},
        ],
      };
      expect(
        () => GeminiVisionService.parseComponents(json, []),
        throwsA(isA<AIResponseException>()),
      );
    });

    test('componente con macros faltantes usa 0 sin crashear', () {
      final json = {
        'components': [
          {'name': 'X', 'estimated_grams': 100},
        ],
      };
      final foods = GeminiVisionService.parseComponents(json, []);
      expect(foods.single.caloriesPer100, 0);
    });
  });

  group('PromptTemplates', () {
    test('identifyFood incluye los nombres de la despensa', () {
      final prompt = PromptTemplates.identifyFood(
        [pantry('Pollo'), pantry('Arroz')],
      );
      expect(prompt, contains('Pollo'));
      expect(prompt, contains('Arroz'));
      expect(prompt, contains('calories_per_100'));
    });

    test('identifyFromText incluye el transcripto y la despensa', () {
      final prompt = PromptTemplates.identifyFromText(
        transcript: 'comí pollo y arroz',
        pantryItems: [pantry('Pollo')],
      );
      expect(prompt, contains('comí pollo y arroz'));
      expect(prompt, contains('Pollo'));
    });

    test('estimateIngredientMacros incluye el nombre del alimento', () {
      final prompt = PromptTemplates.estimateIngredientMacros('pechuga de pollo');
      expect(prompt, contains('pechuga de pollo'));
      expect(prompt, contains('proteins_per_100'));
    });
  });

  group('excepciones tipadas', () {
    test('AIResponseException expone userMessage para la UI', () {
      const e = AIResponseException.notJson(
        userMessage: 'La IA no devolvió una respuesta válida.',
      );
      expect(e.userMessage, isNotNull);
      expect(e.toString(), contains('JSON'));
      expect(e, isA<AIException>());
    });

    test('ImageProcessingException es AIException', () {
      const e = ImageProcessingException('x', userMessage: 'Foto ilegible');
      expect(e, isA<AIException>());
      expect(e.userMessage, 'Foto ilegible');
    });
  });
}