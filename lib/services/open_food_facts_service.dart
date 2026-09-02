import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodFactsProduct {
  final String barcode;
  final String? name;
  final String? brand;
  final String? quantity;
  final double? calories;
  final double? proteins;
  final double? carbs;
  final double? fats;

  /// Unidad en la que OFF reporta los macros: `"g"` (sólidos) o `"ml"`
  /// (líquidos). Si OFF no lo declara explícitamente, asumimos `g` que es
  /// la convención para productos no bebibles.
  final String baseUnit;

  /// URL de la imagen principal del producto en Open Food Facts, si existe.
  /// La descargamos y subimos a Firebase Storage para no depender de
  /// dominios externos en tiempo de render.
  final String? imageFrontUrl;

  final bool found;

  const OpenFoodFactsProduct({
    required this.barcode,
    this.name,
    this.brand,
    this.quantity,
    this.calories,
    this.proteins,
    this.carbs,
    this.fats,
    this.baseUnit = 'g',
    this.imageFrontUrl,
    required this.found,
  });

  /// Devuelve `true` cuando el producto tiene un nombre utilizable y al
  /// menos un macro cargado. Lo usamos para decidir si mostramos el sheet
  /// de confirmación o saltamos directo al fallback por nombre.
  bool get hasUsableData {
    final hasName = (name ?? '').trim().isNotEmpty;
    final hasAnyMacro = calories != null ||
        proteins != null ||
        carbs != null ||
        fats != null;
    return found && hasName && hasAnyMacro;
  }

  /// Construye un `OpenFoodFactsProduct` "placeholder" preservando solo
  /// el barcode. Útil cuando la API no devuelve nada.
  factory OpenFoodFactsProduct.missing(String barcode) =>
      OpenFoodFactsProduct(
        barcode: barcode,
        found: false,
      );
}

class OpenFoodFactsService {
  // Mirror principal: hispanohablante, mayor densidad de productos
  // reportados desde Colombia y Latinoamérica. Si falla, caemos al world.
  static const _coBase = 'https://es.openfoodfacts.org/api/v2/product';
  static const _coSearch = 'https://es.openfoodfacts.org/cgi/search.pl';
  static const _worldBase = 'https://world.openfoodfacts.org/api/v2/product';
  static const _worldSearch = 'https://world.openfoodfacts.org/cgi/search.pl';

  /// Busca productos por nombre. Devuelve hasta 25 coincidencias del mirror
  /// en español. Usado tanto desde `SearchScreen` como desde el fallback
  /// manual del escáner cuando el barcode falla.
  Future<List<OpenFoodFactsProduct>> searchProducts(String query) async {
    if (query.trim().isEmpty) return [];
    final results = await _searchOn(_coSearch, query);
    if (results.isNotEmpty) return results;
    return _searchOn(_worldSearch, query);
  }

  /// Atajo: dado un nombre, devuelve el primer producto que coincida.
  /// Es el corazón del "fallback por nombre" cuando el barcode no existe
  /// en OFF pero la tabla nutricional del producto sí.
  Future<OpenFoodFactsProduct> firstMatchByName(String query) async {
    final results = await searchProducts(query);
    if (results.isEmpty) return OpenFoodFactsProduct.missing('');
    return results.first;
  }

  /// Busca un producto por código de barras probando primero el mirror en
  /// español y luego el global. Si el barcode existe en OFF pero sin datos
  /// nutricionales, lo devuelve con `hasUsableData = false` para que la UI
  /// ofrezca el fallback manual (sin adivinar automáticamente).
  Future<OpenFoodFactsProduct> resolveBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return OpenFoodFactsProduct.missing(clean);

    final co = await _fetchProduct('$_coBase/$clean.json', clean);
    if (co.hasUsableData) return co;

    final world = await _fetchProduct('$_worldBase/$clean.json', clean);
    if (world.hasUsableData) return world;

    // Ninguno de los dos mirrors tiene datos utilizables.
    // Devolvemos el que tenga más información (co > world > missing).
    if (co.found) return co;
    if (world.found) return world;
    return OpenFoodFactsProduct.missing(clean);
  }

  Future<OpenFoodFactsProduct> _fetchProduct(String url, String barcode) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: const {'User-Agent': 'NekoFit/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return OpenFoodFactsProduct.missing(barcode);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) {
        return OpenFoodFactsProduct.missing(barcode);
      }
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return OpenFoodFactsProduct.missing(barcode);

      final nutriments = product['nutriments'] as Map<String, dynamic>?;
      final brand = _firstNonEmpty([
        product['brands_tags']?.toString(),
        product['brands'],
      ]);
      final name = _firstNonEmpty([
        product['product_name_es'],
        product['product_name'],
      ]);
      final baseUnit = _resolveBaseUnit(product);
      final imageFrontUrl = _resolveImageUrl(product);

      return OpenFoodFactsProduct(
        barcode: barcode,
        name: name,
        brand: brand,
        quantity: product['quantity'] as String?,
        calories: _parseDouble(nutriments?['energy-kcal_100g']),
        proteins: _parseDouble(nutriments?['proteins_100g']),
        carbs: _parseDouble(nutriments?['carbohydrates_100g']),
        fats: _parseDouble(nutriments?['fat_100g']),
        baseUnit: baseUnit,
        imageFrontUrl: imageFrontUrl,
        found: true,
      );
    } catch (_) {
      return OpenFoodFactsProduct.missing(barcode);
    }
  }

  /// Resuelve la URL de la imagen principal del producto. OFF expone
  /// varias versiones según tamaño; preferimos la mediana (`400`) para
  /// tarjetas de despensa.
  /// NOTA: Algunas URLs vienen como HTTP → las convertimos a HTTPS para
  /// evitar bloqueos de cleartext en Android.
  static String? _resolveImageUrl(Map<String, dynamic> product) {
    final selected = product['selected_images'] is Map
        ? (product['selected_images'] as Map)['front'] is Map
            ? ((product['selected_images'] as Map)['front'] as Map)['display']
            : null
        : null;
    final raw = selected is String && selected.isNotEmpty
        ? selected
        : _firstNonEmpty([
            product['image_front_url'],
            product['image_url'],
          ]);
    if (raw == null || raw.isEmpty) return null;
    // OFF a veces sirve URLs HTTP → forzamos HTTPS
    if (raw.startsWith('http://')) {
      return 'https://${raw.substring(7)}';
    }
    return raw;
  }

  /// Resuelve la unidad base (`g` o `ml`) en la que OFF reporta los
  /// nutrientes. OFF usa el campo `nutrition_data_per` con valores como
  /// `"100g"`, `"100ml"`, `"serving"` o `"portion"`. Asumimos `g` si el
  /// campo no está, si viene vacío o si vale cualquier cosa distinta de
  /// `100ml`, que es el caso de "bebibles" y algunos productos
  /// líquidos/semi-líquidos mal categorizados.
  static String _resolveBaseUnit(Map<String, dynamic> product) {
    final raw = product['nutrition_data_per'];
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      if (v == '100ml') return 'ml';
      if (v == '100g') return 'g';
    }
    return 'g';
  }

  Future<List<OpenFoodFactsProduct>> _searchOn(String url, String query) async {
    final uri = Uri.parse(url).replace(queryParameters: {
      'search_terms': query,
      'json': 'true',
      'page_size': '25',
      'fields': 'code,product_name,product_name_es,brands,brands_tags,quantity,nutriments,image_front_url,image_url',
      'lang': 'es',
    });
    try {
      final response = await http
          .get(uri, headers: const {'User-Agent': 'NekoFit/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List<dynamic>?;
      if (products == null) return [];
      return products
          .whereType<Map<String, dynamic>>()
          .map((p) {
            final nutriments = p['nutriments'] as Map<String, dynamic>?;
            return OpenFoodFactsProduct(
              barcode: p['code'] as String? ?? '',
              name: _firstNonEmpty([
                p['product_name_es'],
                p['product_name'],
              ]),
              brand: _firstNonEmpty([
                p['brands_tags']?.toString(),
                p['brands'],
              ]),
              quantity: p['quantity'] as String?,
              calories: _parseDouble(nutriments?['energy-kcal_100g']),
              proteins: _parseDouble(nutriments?['proteins_100g']),
              carbs: _parseDouble(nutriments?['carbohydrates_100g']),
              fats: _parseDouble(nutriments?['fat_100g']),
              baseUnit: _resolveBaseUnit(p),
              imageFrontUrl: _resolveImageUrl(p),
              found: true,
            );
          })
          .where((p) => (p.name ?? '').trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}


