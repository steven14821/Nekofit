import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/pantry_item.dart';
import '../models/recognized_food.dart';

/// Entrada persistida en el caché de escaneos de comida.
class _CacheEntry {
  final String hash; // aHash 16 chars hex (64 bits)
  final String pantryFingerprint; // hash de la despensa al momento del scan
  final DateTime createdAt;
  final List<RecognizedFood> foods;

  _CacheEntry({
    required this.hash,
    required this.pantryFingerprint,
    required this.createdAt,
    required this.foods,
  });

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'pantryFingerprint': pantryFingerprint,
        'createdAt': createdAt.toIso8601String(),
        'foods': foods
            .map((f) => {
                  'name': f.name,
                  'estimatedGrams': f.estimatedGrams,
                  'calories': f.calories,
                  'proteins': f.proteins,
                  'carbs': f.carbs,
                  'fats': f.fats,
                  'pantryItemId': f.pantryItemId,
                  'pantryItemName': f.pantryItemName,
                  'caloriesPer100': f.caloriesPer100,
                  'proteinsPer100': f.proteinsPer100,
                  'carbsPer100': f.carbsPer100,
                  'fatsPer100': f.fatsPer100,
                })
            .toList(),
      };

  static _CacheEntry? fromJson(Map<String, dynamic> json) {
    try {
      final foodsRaw = json['foods'] as List<dynamic>?;
      if (foodsRaw == null) return null;
      final foods = foodsRaw
          .whereType<Map<String, dynamic>>()
          .map((f) => RecognizedFood(
                name: f['name'] as String? ?? '',
                grams: (f['estimatedGrams'] as num?)?.toDouble() ?? 0,
                caloriesPer100: (f['caloriesPer100'] as num?)?.toDouble() ?? 0,
                proteinsPer100: (f['proteinsPer100'] as num?)?.toDouble() ?? 0,
                carbsPer100: (f['carbsPer100'] as num?)?.toDouble() ?? 0,
                fatsPer100: (f['fatsPer100'] as num?)?.toDouble() ?? 0,
                pantryItemId: f['pantryItemId'] as String?,
                pantryItemName: f['pantryItemName'] as String?,
              ))
          .toList();
      return _CacheEntry(
        hash: json['hash'] as String? ?? '',
        pantryFingerprint: json['pantryFingerprint'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        foods: foods,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Caché local de resultados del escáner de comida por imagen.
///
/// Cuando el usuario vuelve a fotografiar algo que ya escaneó (mismo plato,
/// mismo ángulo, mismo contenido), evitamos la llamada a Gemini Vision y
/// reutilizamos los alimentos reconocidos.
///
/// Estrategia de matching:
/// 1. aHash perceptual de 64 bits (imagen en escala de grises 8x8). Captura
///    "parecido visual" y es robusto a pequeños cambios de brillo/JPEG.
/// 2. Comparamos por Hamming distance: si la cantidad de bits distintos es
///    menor o igual a [hammingThreshold], consideramos la misma imagen.
/// 3. Validamos que la despensa no haya cambiado tanto como para invalidar
///    los macros (fingerprint sobre los nombres actuales).
/// 4. TTL de [ttlDays]: entradas más viejas se descartan automáticamente.
///
/// Persistencia: archivo JSON en `getApplicationSupportDirectory()`.
class FoodScanCacheService {
  FoodScanCacheService._();
  static final FoodScanCacheService instance = FoodScanCacheService._();

  static const int _maxEntries = 50;
  static const int _hashSize = 8; // 8x8 = 64 bits
  static const int _hammingThreshold = 6; // <=6 bits distintos = mismo plato
  static const int ttlDays = 7;

  File? _file;
  List<_CacheEntry> _entries = [];
  bool _loaded = false;

  /// Devuelve la ruta del archivo de caché (para diagnóstico).
  Future<File> _resolveFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File(p.join(dir.path, 'food_scan_cache.json'));
    return _file!;
  }

  Future<List<_CacheEntry>> _load() async {
    if (_loaded) return _entries;
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        _entries = [];
        _loaded = true;
        return _entries;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _entries = [];
        _loaded = true;
        return _entries;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _entries = [];
        _loaded = true;
        return _entries;
      }
      final list = decoded['entries'] as List<dynamic>?;
      if (list == null) {
        _entries = [];
        _loaded = true;
        return _entries;
      }
      _entries = list
          .whereType<Map<String, dynamic>>()
          .map(_CacheEntry.fromJson)
          .whereType<_CacheEntry>()
          .toList();
      _purgeExpired();
    } catch (_) {
      // Archivo corrupto o no accesible: empezamos vacíos sin romper la app.
      _entries = [];
    }
    _loaded = true;
    return _entries;
  }

  Future<void> _save() async {
    try {
      final file = await _resolveFile();
      final payload = jsonEncode({
        'version': 1,
        'entries': _entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(payload, flush: true);
    } catch (_) {
      // Mejor fallar silencioso: perder caché no debe romper el escáner.
    }
  }

  void _purgeExpired() {
    final cutoff = DateTime.now().subtract(const Duration(days: ttlDays));
    _entries.removeWhere((e) => e.createdAt.isBefore(cutoff));
  }

  /// Calcula un hash perceptual (aHash 64 bits) en hex.
  ///
  /// Decodifica la imagen, la redimensiona a [_hashSize]x[_hashSize] en
  /// escala de grises, y genera un bit por píxel comparándolo contra el
  /// promedio. Robusto a pequeños cambios de brillo, contraste y compresión.
  Future<String> computePerceptualHash(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Si no se puede decodificar, caemos a un hash criptográfico de los
      // bytes crudos para no bloquear el flujo.
      return sha1.convert(bytes).toString().substring(0, 16);
    }
    final resized = img.copyResize(
      decoded,
      width: _hashSize,
      height: _hashSize,
      interpolation: img.Interpolation.average,
    );
    final grayscale = img.grayscale(resized);

    final pixels = <int>[];
    for (final pixel in grayscale) {
      // Canal R == G == B en grayscale; usamos .r.
      pixels.add(pixel.r.toInt());
    }

    final avg = pixels.reduce((a, b) => a + b) / pixels.length;
    final bits = pixels.map((p) => p >= avg ? '1' : '0').join();
    // Convertimos los 64 bits a 16 chars hex.
    final hex = StringBuffer();
    for (var i = 0; i < bits.length; i += 4) {
      final chunk = bits.substring(i, i + 4);
      hex.write(int.parse(chunk, radix: 2).toRadixString(16));
    }
    return hex.toString();
  }

  /// Distancia de Hamming entre dos hashes hex de 64 bits.
  int hammingDistance(String a, String b) {
    if (a.length != b.length) return 64;
    var dist = 0;
    for (var i = 0; i < a.length; i++) {
      var diff = int.parse(a[i], radix: 16) ^ int.parse(b[i], radix: 16);
      while (diff > 0) {
        dist += diff & 1;
        diff >>= 1;
      }
    }
    return dist;
  }

  /// Huella determinística del estado de la despensa, para invalidar
  /// resultados cacheados cuando el usuario añade o quita productos.
  String pantryFingerprint(List<PantryItem> items) {
    if (items.isEmpty) return 'empty';
    final sorted = items
        .map((i) => '${i.id}|${i.name.toLowerCase().trim()}')
        .toList()
      ..sort();
    return sha1.convert(utf8.encode(sorted.join('§'))).toString().substring(0, 16);
  }

  /// Busca un resultado cacheado para [imageBytes] en el contexto de la
  /// [pantryItems] actual. Devuelve null si no hay hit válido.
  Future<List<RecognizedFood>?> lookup({
    required Uint8List imageBytes,
    required List<PantryItem> pantryItems,
  }) async {
    final entries = await _load();
    if (entries.isEmpty) return null;

    final hash = await computePerceptualHash(imageBytes);
    final fingerprint = pantryFingerprint(pantryItems);

    // Buscamos la entrada con menor distancia de Hamming que además
    // coincida con la huella de despensa.
    _CacheEntry? best;
    int bestDist = 1 << 30;
    for (final e in entries) {
      if (e.pantryFingerprint != fingerprint) continue;
      final d = hammingDistance(e.hash, hash);
      if (d <= _hammingThreshold && d < bestDist) {
        best = e;
        bestDist = d;
      }
    }
    return best?.foods;
  }

  /// Guarda el resultado de un escaneo para reuso futuro.
  Future<void> store({
    required Uint8List imageBytes,
    required List<PantryItem> pantryItems,
    required List<RecognizedFood> foods,
  }) async {
    if (foods.isEmpty) return;
    final entries = await _load();

    final hash = await computePerceptualHash(imageBytes);
    final fingerprint = pantryFingerprint(pantryItems);

    // Reemplazamos si ya existía un hit "cercano" para no acumular duplicados.
    final existingIndex = entries.indexWhere(
      (e) => e.pantryFingerprint == fingerprint &&
          hammingDistance(e.hash, hash) <= _hammingThreshold,
    );

    final entry = _CacheEntry(
      hash: hash,
      pantryFingerprint: fingerprint,
      createdAt: DateTime.now(),
      foods: foods,
    );

    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }

    // FIFO al alcanzar el máximo: descartamos la más vieja.
    if (entries.length > _maxEntries) {
      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      entries.removeRange(0, entries.length - _maxEntries);
    }

    _entries = entries;
    await _save();
  }

  /// Borra el caché por completo. Útil para tests o ajustes manuales.
  Future<void> clear() async {
    _entries = [];
    _loaded = true;
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Solo para diagnóstico/debug: cuántas entradas siguen vivas.
  Future<int> debugSize() async {
    final entries = await _load();
    return entries.length;
  }
}
