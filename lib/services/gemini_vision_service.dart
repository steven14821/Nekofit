import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/pantry_item.dart';
import '../models/recognized_food.dart';
import 'ai_exceptions.dart';
import 'prompt_templates.dart';

/// Servicio de visión IA para identificar alimentos en fotos de platos.
///
/// Usa Firebase AI Logic (Gemini) con Structured Output (`responseSchema` +
/// `responseMimeType: application/json`): Gemini garantiza el JSON según el
/// esquema, y el parser solo valida. Como red de seguridad, [extractJsonObject]
/// tolera envolturas de markdown y texto extra.
///
/// Los errores se elevan tipados ([AIResponseException], [ImageProcessingException])
/// para que la UI muestre mensajes específicos.
///
/// Initialization is race-safe: concurrent calls to [ensureInitialized] all
/// await the same [Completer], so the model is created exactly once even if
/// multiple screens call it simultaneously.
class GeminiVisionService {
  GeminiVisionService._();
  static final GeminiVisionService instance = GeminiVisionService._();

  Completer<void>? _initCompleter;
  GenerativeModel? _model;

  bool get isReady => _model != null;

  /// Ensures the Gemini model is initialized. Safe to call multiple times;
  /// concurrent callers share the same pending future.
  Future<void> ensureInitialized() async {
    if (_model != null) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.5-flash',
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 2048,
        ),
      );
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  GenerativeModel get _safeModel {
    final model = _model;
    if (model == null) {
      throw StateError(
        'GeminiVisionService not initialized. Call ensureInitialized() first.',
      );
    }
    return model;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Esquemas Structured Output (JSON Mode). En lugar de depender del prompt
  // para el formato, Gemini valida el JSON contra estos esquemas.
  // ───────────────────────────────────────────────────────────────────────────

  static final Schema _macroField = Schema.number(
    title: 'Macros por 100g',
    description: 'Valor nutricional por cada 100 gramos',
    minimum: 0,
  );

  static final Schema _componentsSchema = Schema.object(
    description: 'Plato identificado con sus componentes',
    properties: {
      'dish_name': Schema.string(description: 'Nombre corto del plato'),
      'components': Schema.array(
        items: Schema.object(
          properties: {
            'name': Schema.string(description: 'Nombre del ingrediente'),
            'estimated_grams': Schema.number(
              description: 'Gramos estimados de la porción',
              minimum: 0,
            ),
            'calories_per_100': _macroField,
            'proteins_per_100': _macroField,
            'carbs_per_100': _macroField,
            'fats_per_100': _macroField,
          },
        ),
      ),
    },
  );

  static final Schema _macroSchema = Schema.object(
    description: 'Macros por 100g de un alimento',
    properties: {
      'calories_per_100': _macroField,
      'proteins_per_100': _macroField,
      'carbs_per_100': _macroField,
      'fats_per_100': _macroField,
    },
  );

  /// Analiza una foto de plato y devuelve los componentes identificados.
  ///
  /// [imagePath] es la ruta local de la imagen comprimida (<100KB).
  /// [pantryItems] es la lista de productos disponibles del usuario
  /// para hacer matching y usar macros reales.
  Future<List<RecognizedFood>> identifyFood({
    required String imagePath,
    required List<PantryItem> pantryItems,
  }) async {
    await ensureInitialized();

    final imageBytes = await _readCompressedImage(imagePath);
    final mimeType =
        imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final prompt = PromptTemplates.identifyFood(pantryItems);

    final response = await _generateJson(
      schema: _componentsSchema,
      parts: [
        InlineDataPart(mimeType, imageBytes),
        TextPart(prompt),
      ],
    );

    return parseComponents(
      _requireJsonObject(response, context: 'plato'),
      pantryItems,
    );
  }

  /// Analiza una transcripción de texto (modo voz) y devuelve los alimentos
  /// identificados con sus macros estimadas por 100g y los gramos totales.
  ///
  /// Usa el mismo formato JSON que [identifyFood] para mantener
  /// compatibilidad con el resto del pipeline del scanner.
  Future<List<RecognizedFood>> identifyFromText({
    required String transcript,
    required List<PantryItem> pantryItems,
  }) async {
    await ensureInitialized();

    final prompt = PromptTemplates.identifyFromText(
      transcript: transcript,
      pantryItems: pantryItems,
    );

    final response = await _generateJson(
      schema: _componentsSchema,
      parts: [TextPart(prompt)],
    );

    return parseComponents(
      _requireJsonObject(response, context: 'texto'),
      pantryItems,
    );
  }

  /// Estima los macros por 100g de un ingrediente libre (sin imagen).
  ///
  /// Se usa en el Recipe Builder cuando el usuario escribe un ingrediente
  /// que no está en su despensa. Devuelve un Map con las claves:
  /// `calories`, `proteins`, `carbs`, `fats` (todos por 100g).
  ///
  /// Lanza [AIResponseException] si la IA no puede procesar la solicitud.
  Future<Map<String, double>> estimateIngredientMacros({
    required String name,
    required double grams,
  }) async {
    await ensureInitialized();

    final prompt = PromptTemplates.estimateIngredientMacros(name);
    final response = await _generateJson(
      schema: _macroSchema,
      parts: [TextPart(prompt)],
    );

    final json = _requireJsonObject(response, context: 'ingrediente');
    return {
      'calories': (json['calories_per_100'] as num?)?.toDouble() ?? 150,
      'proteins': (json['proteins_per_100'] as num?)?.toDouble() ?? 10,
      'carbs': (json['carbs_per_100'] as num?)?.toDouble() ?? 10,
      'fats': (json['fats_per_100'] as num?)?.toDouble() ?? 5,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Comunicación con Gemini
  // ───────────────────────────────────────────────────────────────────────────

  /// Llama al modelo con Structured Output activado (JSON estricto).
  ///
  /// Convierte cualquier error de red/API en [AIResponseException] para que
  /// la UI no tenga que inspeccionar excepciones de bajo nivel.
  Future<GenerateContentResponse> _generateJson({
    required Schema schema,
    required List<Part> parts,
  }) async {
    try {
      return await _safeModel.generateContent(
        [Content.multi(parts)],
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
          responseSchema: schema,
        ),
      );
    } on AIException {
      rethrow;
    } catch (e) {
      throw AIResponseException(
        'Gemini no respondió: $e',
        userMessage: 'El servidor de IA no respondió. Intenta de nuevo.',
      );
    }
  }

  /// Devuelve el texto de la respuesta o lanza si viene vacío/bloqueado.
  String _requireText(GenerateContentResponse response) {
    try {
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw const AIResponseException.empty(
          userMessage: 'La IA no devolvió resultados. Intenta de nuevo.',
        );
      }
      return text;
    } on AIException {
      rethrow;
    } catch (e) {
      // Un backend bloqueado (safety) lanza desde `response.text`.
      throw AIResponseException('Respuesta de la IA bloqueada: $e');
    }
  }

  /// Decodifica la respuesta como `Map<String, dynamic>` (JSON object).
  Map<String, dynamic> _requireJsonObject(
    GenerateContentResponse response, {
    required String context,
  }) {
    final raw = extractJsonObject(_requireText(response));
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // continuar hacia el error tipado de abajo
    }
    throw AIResponseException(
      'La IA no devolvió un JSON válido para "$context"',
      userMessage: 'No pudimos interpretar la respuesta de la IA.',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Parsing defensivo (red de seguridad para cuando no hay schema)
  // ───────────────────────────────────────────────────────────────────────────

  /// Extrae el primer objeto JSON `{...}` balanceado de una respuesta.
  ///
  /// Tolerante a envolturas de markdown (```json), texto antes/después del
  /// JSON y ruido. Respeta strings (con escapes) y profundidad de llaves.
  /// Lanza [AIResponseException.notJson] si no hay objeto o está sin cerrar.
  static String extractJsonObject(String text) {
    final open = text.indexOf('{');
    if (open < 0) {
      throw const AIResponseException.notJson(
        userMessage: 'La IA no devolvió una respuesta válida.',
      );
    }

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = open; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return text.substring(open, i + 1);
      }
    }
    throw const AIResponseException.notJson(
      userMessage: 'La IA devolvió un JSON sin cerrar.',
    );
  }

  /// Convierte un JSON de componentes en [RecognizedFood], cruzando con la
  /// despensa para usar macros reales cuando hay match.
  ///
  /// Utilidad pública (independiente de la red) para poder probar el parsing
  /// y reutilizarlo desde otros puntos del pipeline sin una instancia del
  /// servicio ni conexión a Firebase.
  static List<RecognizedFood> parseComponents(
    Map<String, dynamic> json,
    List<PantryItem> pantryItems,
  ) {
    final raw = json['components'];
    if (raw is! List) {
      throw const AIResponseException.invalidShape(
        userMessage: 'La IA no devolvió alimentos. Intenta con otra foto.',
      );
    }

    return raw.map((comp) {
      if (comp is! Map<String, dynamic>) {
        throw const AIResponseException.invalidShape(
          userMessage: 'La IA devolvió un componente inválido.',
        );
      }
      final name = comp['name'];
      if (name is! String || name.trim().isEmpty) {
        throw const AIResponseException.invalidShape(
          userMessage: 'La IA devolvió un componente sin nombre.',
        );
      }
      final grams = (comp['estimated_grams'] as num?)?.toDouble() ?? 0;

      // Macros estimados por la IA (por 100g)
      final aiCaloriesPer100 = (comp['calories_per_100'] as num?)?.toDouble() ?? 0;
      final aiProteinsPer100 = (comp['proteins_per_100'] as num?)?.toDouble() ?? 0;
      final aiCarbsPer100 = (comp['carbs_per_100'] as num?)?.toDouble() ?? 0;
      final aiFatsPer100 = (comp['fats_per_100'] as num?)?.toDouble() ?? 0;

      // Buscar match en la despensa (case-insensitive, parcial)
      final match = pantryItems.firstWhere(
        (item) => item.name.toLowerCase().contains(name.toLowerCase()) ||
            name.toLowerCase().contains(item.name.toLowerCase()),
        orElse: () => PantryItem(
          id: '',
          name: name,
          category: 'Proteínas',
          isAvailable: true,
          quantity: '${grams.toInt()}g',
          calories: 0,
          proteins: 0,
          carbs: 0,
          fats: 0,
          lastReplenished: DateTime.now(),
        ),
      );

      final pantryMatch = match.id.isNotEmpty ? match : null;

      return RecognizedFood.fromGemini(
        name: name,
        estimatedGrams: grams,
        pantryMatch: pantryMatch,
        aiCaloriesPer100: aiCaloriesPer100,
        aiProteinsPer100: aiProteinsPer100,
        aiCarbsPer100: aiCarbsPer100,
        aiFatsPer100: aiFatsPer100,
      );
    }).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Imagen
  // ───────────────────────────────────────────────────────────────────────────

  /// Lee y comprime la imagen. Los fallos se elevan como
  /// [ImageProcessingException] (foto ausente / ilegible / demasiado pesada).
  Future<Uint8List> _readCompressedImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw const ImageProcessingException(
          'Imagen no encontrada',
          userMessage: 'No encontramos la foto. Intenta de nuevo.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 500 * 1024) {
        return _compressImage(bytes);
      }
      return bytes;
    } on AIException {
      rethrow;
    } catch (e) {
      throw ImageProcessingException(
        'Imagen ilegible ($e)',
        userMessage: 'No pudimos leer la foto. Prueba con otra.',
      );
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.jpeg,
      );
      return compressed.isNotEmpty ? compressed : bytes;
    } catch (_) {
      return bytes;
    }
  }
}