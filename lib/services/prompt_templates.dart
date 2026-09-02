import '../models/pantry_item.dart';

/// Plantillas de prompts del pipeline de IA (Gemini Vision).
///
/// Centralizan la "ingeniería de prompts" para poder iterar sobre los prompts
/// sin tocar la lógica del servicio. Cada método devuelve el prompt completo
/// listo para enviar, interpolando la despensa del usuario.
///
/// El formato de salida (JSON) se exige en el prompt como refuerzo, pero la
/// garantía real viene del `responseSchema` (Structured Output) que configura
/// el servicio; el parser es tolerante a envolturas de markdown.
abstract final class PromptTemplates {
  /// Prompt para analizar una foto de plato.
  static String identifyFood(List<PantryItem> pantryItems) {
    final pantryNames = pantryItems.map((i) => i.name).join(', ');
    return '''
Eres un experto en nutrición y cocina colombiana. Analiza esta foto de un plato de comida.

IDENTIFICA cada ingrediente/alimento visible en la foto. Para cada uno:
1. NOMBRE: Usa exactamente el nombre de la lista de despensa si coincide. Ej: si ves "pechuga de pollo" y en la despensa hay "Pechuga de pollo", usa ese nombre exacto.
2. GRAMOS: Estima los gramos razonables de cada ingrediente basándote en el tamaño visual del plato.
3. MACROS POR 100g: Estima los valores nutricionales por cada 100g basándote en tu conocimiento de alimentos colombianos y latinos.

LISTA DE TU DESPENSA (usa estos nombres si coinciden):
$pantryNames

RESPONDE ÚNICAMENTE con un JSON válido con el esquema:
{
  "dish_name": "nombre del plato",
  "components": [
    {
      "name": "nombre del ingrediente",
      "estimated_grams": 150,
      "calories_per_100": 165,
      "proteins_per_100": 31,
      "carbs_per_100": 0,
      "fats_per_100": 3.6
    }
  ]
}

REGLAS:
- No inventes alimentos que no se vean en la foto.
- Si un ingrediente no está en la despensa, igualmente estima sus macros por 100g.
- Estima gramos de forma realista (una porción típica de pollo: 120-200g, arroz: 150-250g, ensalada: 80-150g).
- Si solo ves un alimento, devuelve un solo componente.
- Los macros por 100g deben ser realistas según tablas nutricionales estándar.
- No pongas texto fuera del JSON.
''';
  }

  /// Prompt para extraer alimentos de una transcripción por voz/texto.
  static String identifyFromText({
    required String transcript,
    required List<PantryItem> pantryItems,
  }) {
    final pantryNames = pantryItems.map((i) => i.name).join(', ');
    return '''
Eres un experto en nutrición. El usuario dictó (o escribió) qué comió. Extrae los alimentos y sus porciones de este texto:

"$transcript"

INSTRUCCIONES:
- Identifica cada alimento mencionado.
- Si el usuario mencionó una cantidad (ej. "200g", "una taza", "dos huevos"), respétala como "estimated_grams". Si no mencionó nada, asume 100g.
- PRIORIZA usar exactamente el nombre de la despensa si coincide. Ej: si dijo "pechuga de pollo" y en la despensa hay "Pechuga de pollo", usa ese nombre exacto.
- Si no está en la despensa, igualmente estima los macros por 100g con valores realistas para la cocina colombiana/latina.

LISTA DE TU DESPENSA (usa estos nombres si coinciden):
$pantryNames

RESPONDE ÚNICAMENTE con un JSON válido con el esquema:
{
  "dish_name": "nombre corto del plato o del conjunto",
  "components": [
    {
      "name": "nombre del ingrediente",
      "estimated_grams": 150,
      "calories_per_100": 165,
      "proteins_per_100": 31,
      "carbs_per_100": 0,
      "fats_per_100": 3.6
    }
  ]
}

REGLAS:
- Si el texto no menciona alimentos reconocibles, devuelve "components": [].
- No inventes ingredientes que no aparezcan en el texto.
- "una taza" = 240g, "un plato" = 250g, "un puñado" = 30g, "una unidad/huevo/manzana" = 100-150g.
- Sé conservador y realista con los macros por 100g.
- No pongas texto fuera del JSON.
''';
  }

  /// Prompt para estimar macros por 100g de un alimento libre.
  static String estimateIngredientMacros(String name) {
    return '''
Eres un experto en nutrición. Devuelve los macros por 100g del siguiente alimento.

Alimento: "$name"

RESPONDE ÚNICAMENTE con un JSON válido con el esquema:
{
  "calories_per_100": 165,
  "proteins_per_100": 31,
  "carbs_per_100": 0,
  "fats_per_100": 3.6
}

REGLAS:
- Usa valores de tablas nutricionales estándar.
- Si el nombre es ambiguo (ej. "pollo"), asume la preparación más común (pechuga cocida sin piel).
- Nunca devuelvas valores negativos.
- Si desconoces el alimento, usa valores genéricos conservadores (150 kcal, 10g proteína, 10g carbs, 5g grasa).
- No pongas texto fuera del JSON.
''';
  }
}