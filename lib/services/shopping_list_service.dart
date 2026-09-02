import 'package:shared_preferences/shared_preferences.dart';

import '../models/pantry_item.dart';
import '../models/weekly_plan.dart';
import 'inventory_estimator_service.dart';

/// Una entrada de la lista de compras inteligente.
class ShoppingItem {
  final String name;
  final String? pantryItemId;
  final String category;
  final String reason; // 'agotado' | 'critico' | 'plan' | 'manual'
  final String suggestedQuantity;
  final bool checked;

  const ShoppingItem({
    required this.name,
    required this.category,
    required this.reason,
    required this.suggestedQuantity,
    this.pantryItemId,
    this.checked = false,
  });

  ShoppingItem copyWith({bool? checked, String? suggestedQuantity}) =>
      ShoppingItem(
        name: name,
        pantryItemId: pantryItemId,
        category: category,
        reason: reason,
        suggestedQuantity: suggestedQuantity ?? this.suggestedQuantity,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'pantryItemId': pantryItemId,
        'category': category,
        'reason': reason,
        'suggestedQuantity': suggestedQuantity,
        'checked': checked,
      };

  factory ShoppingItem.fromMap(Map<String, dynamic> map) => ShoppingItem(
        name: map['name'] ?? '',
        pantryItemId: map['pantryItemId'],
        category: map['category'] ?? 'Otros',
        reason: map['reason'] ?? 'manual',
        suggestedQuantity: map['suggestedQuantity'] ?? '',
        checked: map['checked'] == true,
      );
}

/// Servicio que genera y persiste la lista de compras inteligente.
///
/// Cruza tres fuentes:
///  1. Productos agotados de la despensa.
///  2. Productos críticos según el estimador de inventario (≤1 día).
///  3. Ingredientes mencionados en el plan semanal que no están en despensa.
///
/// La lista persistida se guarda en SharedPreferences (clave por uid).
class ShoppingListService {
  ShoppingListService._();
  static final ShoppingListService instance = ShoppingListService._();

  static const _prefix = 'shopping_list_';
  static const _manualAddedPrefix = 'shopping_manual_';

  /// Genera la lista sugerida (no la persiste).
  /// Combina los datos de las tres fuentes.
  Future<List<ShoppingItem>> generateSuggestedList({
    required String uid,
    required List<PantryItem> pantry,
    required WeeklyPlan? plan,
    required List<InventoryEstimate> estimates,
  }) async {
    final byId = {for (final p in pantry) p.id: p};
    final items = <ShoppingItem>[];

    // 1) Agotados.
    for (final p in pantry.where((p) => !p.isAvailable)) {
      items.add(ShoppingItem(
        name: p.name,
        pantryItemId: p.id,
        category: p.category,
        reason: 'agotado',
        suggestedQuantity: p.originalQuantity ?? p.quantity,
      ));
    }

    // 2) Críticos (≤1 día) o advertencia (≤3 días).
    for (final est in estimates) {
      final p = byId[est.pantryItemId];
      if (p == null || !p.isAvailable) continue;
      if (est.isCritical || est.isWarning) {
        items.add(ShoppingItem(
          name: p.name,
          pantryItemId: p.id,
          category: p.category,
          reason: est.isCritical ? 'critico' : 'critico',
          suggestedQuantity: _suggestRestockQuantity(p, est),
        ));
      }
    }

    // 3) Ingredientes del plan semanal que no están en despensa.
    if (plan != null) {
      final pantryNames = pantry
          .where((p) => p.isAvailable)
          .map((p) => p.name.toLowerCase())
          .toSet();
      final seen = <String>{};
      for (final day in plan.days) {
        for (final meal in day.meals) {
          // Solo considerar comidas NO hechas (lo que aún hay que comprar).
          if (meal.done) continue;
          final candidates = _extractIngredientCandidates(meal.title);
          for (final c in candidates) {
            final key = c.toLowerCase();
            if (pantryNames.contains(key)) continue;
            if (seen.contains(key)) continue;
            seen.add(key);
            items.add(ShoppingItem(
              name: c,
              pantryItemId: null,
              category: _guessCategory(c),
              reason: 'plan',
              suggestedQuantity: '1 und',
            ));
          }
        }
      }
    }

    // Agregar ítems manuales persistidos.
    final manual = await _loadManualItems(uid);
    items.addAll(manual);

    return items;
  }

  /// Persiste la lista actual (los checks del usuario se mantienen).
  Future<void> save(String uid, List<ShoppingItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = items.map((i) => i.toMap()).toList();
    await prefs.setString('$_prefix$uid', _encodeList(encoded));
  }

  /// Carga la lista persistida.
  Future<List<ShoppingItem>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$uid');
    if (raw == null) return [];
    try {
      final list = _decodeList(raw);
      return list.map((m) => ShoppingItem.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Añade un ítem manual (no persistido en la lista inteligente principal).
  Future<void> addManual(String uid, ShoppingItem item) async {
    final current = await _loadManualItems(uid);
    current.add(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_manualAddedPrefix$uid',
      _encodeList(current.map((i) => i.toMap()).toList()),
    );
  }

  Future<List<ShoppingItem>> _loadManualItems(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_manualAddedPrefix$uid');
    if (raw == null) return [];
    try {
      final list = _decodeList(raw);
      return list.map((m) => ShoppingItem.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  String _suggestRestockQuantity(PantryItem item, InventoryEstimate est) {
    // Si le quedan 1.5 días y consume 80g/día → sugerir ~250g (3-4 días).
    final refillDays = 5;
    final needed = (est.dailyConsumption * refillDays).ceil();
    if (needed <= 0) return item.originalQuantity ?? item.quantity;
    return '$needed g';
  }

  /// Extrae candidatos a ingrediente del título. Heurística simple.
  List<String> _extractIngredientCandidates(String title) {
    final cleaned = title
        .toLowerCase()
        .replaceAll(RegExp(r'\bcon\b|\by\b|\ba la|\bal\b|\bla\b'), ' ')
        .replaceAll(RegExp(r'[^a-záéíóúñ\s]'), ' ');
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet()
        .toList();
    return words;
  }

  String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (['pollo', 'carne', 'res', 'cerdo', 'atún', 'pescado', 'huevo']
        .any((k) => n.contains(k))) {
      return 'Proteínas';
    }
    if (['arroz', 'papa', 'yuca', 'arepa', 'pan', 'avena', 'lentejas']
        .any((k) => n.contains(k))) {
      return 'Carbohidratos';
    }
    if (['queso', 'yogurt', 'leche'].any((k) => n.contains(k))) {
      return 'Lácteos/Huevos';
    }
    if (['lechuga', 'tomate', 'zanahoria', 'brócoli', 'espinaca']
        .any((k) => n.contains(k))) {
      return 'Vegetales';
    }
    if (['aceite', 'mantequilla', 'aguacate', 'nuez'].any((k) => n.contains(k))) {
      return 'Grasas';
    }
    return 'Otros';
  }

  // ── Serialización simple (sin jsonEncode para evitar import extra) ─────
  String _encodeList(List<Map<String, dynamic>> list) {
    final buf = StringBuffer();
    for (var i = 0; i < list.length; i++) {
      if (i > 0) buf.write('§§§');
      final m = list[i];
      buf.write('${m['name']}|${m['pantryItemId'] ?? ''}|'
          '${m['category']}|${m['reason']}|'
          '${m['suggestedQuantity']}|${m['checked']}');
    }
    return buf.toString();
  }

  List<Map<String, dynamic>> _decodeList(String raw) {
    if (raw.isEmpty) return [];
    return raw.split('§§§').map((entry) {
      final parts = entry.split('|');
      return {
        'name': parts.isNotEmpty ? parts[0] : '',
        'pantryItemId': parts.length > 1 ? parts[1] : null,
        'category': parts.length > 2 ? parts[2] : 'Otros',
        'reason': parts.length > 3 ? parts[3] : 'manual',
        'suggestedQuantity': parts.length > 4 ? parts[4] : '',
        'checked': parts.length > 5 ? parts[5] == 'true' : false,
      };
    }).toList();
  }
}
