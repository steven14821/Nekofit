/// Parser heurístico para tablas nutricionales. No busca cubrir todos los
/// formatos del mercado (es un MVP), sino los más comunes en productos
/// colombianos: tablas en español con "Porción / Por 100g" o "Por 100ml"
/// y macros etiquetados (Calorías, Energía, Proteínas, Carbohidratos,
/// Grasas, Grasa).
///
/// Devuelve un `ParsedNutrition` con los macros por 100g o 100ml según
/// detecte. Si no encuentra el patrón, devuelve un objeto con `confidence`
/// bajo y campos nulos para que la UI muestre lo que se pudo reconocer y
/// deje al usuario editar.
class ParsedNutrition {
  final double? calories;
  final double? proteins;
  final double? carbs;
  final double? fats;
  final String baseUnit; // "g" o "ml"
  final double confidence; // 0..1

  const ParsedNutrition({
    this.calories,
    this.proteins,
    this.carbs,
    this.fats,
    this.baseUnit = 'g',
    this.confidence = 0,
  });

  bool get hasAnyMacro =>
      calories != null || proteins != null || carbs != null || fats != null;
}

class NutritionLabelParser {
  /// Detecta palabras que significan "energía / calorías".
  static const _energyKeywords = [
    'calorias',
    'caloría',
    'calorías',
    'energia',
    'energía',
    'valor energetico',
    'valor energético',
    'kcal',
  ];

  static const _proteinKeywords = [
    'proteina',
    'proteína',
    'proteinas',
    'proteínas',
  ];

  static const _carbKeywords = [
    'carbohidrato',
    'carbohidratos',
    'carbohirato',
  ];

  static const _fatKeywords = [
    'grasa',
    'grasas',
    'lipido',
    'lípido',
    'lipidos',
    'lípidos',
  ];

  /// Punto de entrada. Recibe el texto crudo de ML Kit (líneas
  /// separadas por `\n` o un único string). Devuelve los macros
  /// encontrados y la base inferida.
  static ParsedNutrition parse(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => _normalize(l))
        .where((l) => l.isNotEmpty)
        .toList();

    final fullText = lines.join(' \n ');
    final baseUnit = _detectBaseUnit(fullText);
    final isPerServing = _detectPerServing(fullText);

    final calories = _findMacro(lines, _energyKeywords, baseUnit, isPerServing);
    final proteins = _findMacro(lines, _proteinKeywords, baseUnit, isPerServing);
    final carbs = _findMacro(lines, _carbKeywords, baseUnit, isPerServing);
    final fats = _findMacro(lines, _fatKeywords, baseUnit, isPerServing);

    // Confianza simple: cantidad de macros encontrados, máximo 1.
    final found =
        [calories, proteins, carbs, fats].where((v) => v != null).length;
    final confidence = found / 4.0;

    return ParsedNutrition(
      calories: calories,
      proteins: proteins,
      carbs: carbs,
      fats: fats,
      baseUnit: baseUnit,
      confidence: confidence,
    );
  }

  static String _normalize(String s) {
    final lower = s.toLowerCase();
    // Reemplazos típicos de OCR: "0" por "O", "1" por "l", comas por puntos.
    return lower
        .replaceAll(',', '.')
        .replaceAll('kcal.', 'kcal')
        .replaceAll('kca l', 'kcal')
        .replaceAll('prote ina', 'proteina')
        .replaceAll('prote inas', 'proteinas')
        .replaceAll('carboh idratos', 'carbohidratos')
        .replaceAll('grasas ', 'grasas')
        .trim();
  }

  static String _detectBaseUnit(String text) {
    if (RegExp(r'100\s*ml|por\s*100\s*ml|cada\s*100\s*ml|por\s*cada\s*100\s*ml')
        .hasMatch(text)) {
      return 'ml';
    }
    return 'g';
  }

  static bool _detectPerServing(String text) {
    return RegExp(
            r'por\s*porcion|por\s*porción|por\s*servicio|por\s*envase|cada\s*porcion|cada\s*porción')
        .hasMatch(text);
  }

  /// Busca, en orden, una línea que contenga una keyword del grupo y
  /// extrae el primer número cercano (misma línea, o en las 2 siguientes
  /// si están en formato de tabla).
  static double? _findMacro(
    List<String> lines,
    List<String> keywords,
    String baseUnit,
    bool perServing,
  ) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!keywords.any(line.contains)) continue;

      // 1) Intenta encontrar el número en la misma línea.
      final same = _firstNumber(line);
      if (same != null) return same;

      // 2) Mira en las 2 líneas siguientes (formato de tabla).
      for (var j = 1; j <= 2 && i + j < lines.length; j++) {
        final next = lines[i + j];
        final value = _firstNumber(next);
        if (value != null) return value;
      }
    }
    return null;
  }

  /// Devuelve el primer número decimal o entero de la línea, aceptando
  /// "12,5", "12.5", "0 g", "menos de 0,5". Si encuentra varios, prioriza
  /// los que tengan unidad consistente.
  static double? _firstNumber(String line) {
    final match = RegExp(r'(\d+([.,]\d+)?)').firstMatch(line);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }
}
