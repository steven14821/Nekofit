import '../services/open_food_facts_service.dart';

/// Categorías canónicas que entiende la app y que se pintan en la pestaña
/// de la Despensa Única. Si añades un valor nuevo, recuerda mapearlo en
/// `AppColors.ofCategory` (core/theme.dart).
const pantryCategories = <String>{
  'Proteínas',
  'Carbohidratos',
  'Grasas',
  'Vegetales',
  'Lácteos/Huevos',
};

/// Devuelve la pestaña en la que mejor encaja un producto a partir de su
/// nombre y de sus macros por 100g. La heurística prioriza palabras clave
/// colombianas (plátano, papa, yuca, ahuyama, etc.) y solo recurre a los
/// macros cuando el nombre es ambiguo.
String inferPantryCategory(OpenFoodFactsProduct product) {
  final name = (product.name ?? '').toLowerCase();

  bool contains(List<String> keywords) =>
      keywords.any((k) => name.contains(k));

  if (contains(const [
    'pollo', 'res', 'carne', 'cerdo', 'pescado', 'atun', 'atún',
    'salmon', 'salmón', 'tilapia', 'trucha', 'camaron', 'camarón',
    'huevo', 'huevos', 'tofu', 'tempeh', 'lenteja', 'lentejas',
    'frijol', 'frijoles', 'garbanzo', 'garbanzos', 'albondiga',
    'albondigas', 'albóndiga', 'albóndigas', 'jamon', 'jamón',
  ])) {
    return 'Proteínas';
  }

  if (contains(const [
    'leche', 'yogur', 'yogurt', 'queso', 'kefir', 'kumis', 'cuajada',
    'mantequilla', 'crema de leche',
  ])) {
    return 'Lácteos/Huevos';
  }

  if (contains(const [
    'aceite', 'mantequilla', 'manteca', 'margarina', 'mayonesa',
    'aguacate', 'almendra', 'almendras', 'mani', 'maní', 'nuez',
    'nueces', 'pistacho', 'avellana', 'semilla', 'semillas',
    'aceituna', 'aceitunas', 'oliva', 'coco',
  ])) {
    return 'Grasas';
  }

  if (contains(const [
    'espinaca', 'brocoli', 'brócoli', 'lechuga', 'tomate', 'cebolla',
    'zanahoria', 'pepino', 'pimenton', 'pimentón', 'calabacin',
    'calabacín', 'berenjena', 'apio', 'acelga', 'col', 'repollo',
    'coliflor', 'ajo', 'cilantro', 'perejil', 'albahaca', 'arugula',
    'rúcula', 'remolacha', 'rabano', 'rábano', 'verdura', 'verduras',
    'hortaliza', 'hortalizas', 'champinon', 'champiñón',
  ])) {
    return 'Vegetales';
  }

  if (contains(const [
    'arroz', 'pasta', 'fideos', 'pan', 'avena', 'tortilla', 'arepa',
    'platano', 'plátano', 'papa', 'yuca', 'ahuyama', 'ñame', 'quinoa',
    'quinua', 'cebada', 'trigo', 'maiz', 'maíz', 'harina', 'azucar',
    'azúcar', 'miel', 'chocolate', 'galleta', 'cereal', 'granola',
    'arveja', 'arvejas', 'garbanzo',
  ])) {
    return 'Carbohidratos';
  }

  if (contains(const [
    'manzana', 'pera', 'naranja', 'mandarina', 'banano', 'fresa',
    'mora', 'frambuesa', 'arandano', 'arándano', 'uva', 'kiwi',
    'mango', 'pina', 'piña', 'papaya', 'sandia', 'sandía', 'melon',
    'melón', 'fruta', 'frutas', 'guayaba', 'maracuya', 'maracuyá',
    'lulo', 'tomate de arbol', 'tomate de árbol', 'curuba', 'granadilla',
  ])) {
    return 'Vegetales';
  }

  // Heurística por macros cuando el nombre no da pistas claras.
  final p = product.proteins ?? 0;
  final c = product.carbs ?? 0;
  final f = product.fats ?? 0;
  if (p >= 15) return 'Proteínas';
  if (c >= 20) return 'Carbohidratos';
  if (f >= 15) return 'Grasas';
  return 'Proteínas';
}
