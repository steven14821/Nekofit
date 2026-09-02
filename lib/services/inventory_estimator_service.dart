import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de la estimación de agotamiento para un pantry item.
class InventoryEstimate {
  final String pantryItemId;
  final double currentQuantity;
  final double dailyConsumption;
  final int estimatedDaysLeft;
  final bool isCritical; // <= 1 día
  final bool isWarning;  // <= 3 días

  const InventoryEstimate({
    required this.pantryItemId,
    required this.currentQuantity,
    required this.dailyConsumption,
    required this.estimatedDaysLeft,
    this.isCritical = false,
    this.isWarning = false,
  });
}

class InventoryEstimatorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calcula estimaciones de agotamiento para todos los pantry items dados.
  /// Busca los últimos 30 días de consumo en la colección `meals`.
  Future<List<InventoryEstimate>> estimateAll({
    required String uid,
    required List<Map<String, dynamic>> pantryItems,
  }) async {
    if (pantryItems.isEmpty) return [];

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Obtener todos los meals de los últimos 30 días
    final mealsSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    // Agrupar consumo por pantryItemId
    final Map<String, double> consumptionByItem = {};
    for (final doc in mealsSnap.docs) {
      final data = doc.data();
      final pantryItemId = data['pantryItemId'] as String?;
      final grams = (data['grams'] as num?)?.toDouble() ?? 0;
      if (pantryItemId != null && pantryItemId.isNotEmpty && grams > 0) {
        consumptionByItem[pantryItemId] =
            (consumptionByItem[pantryItemId] ?? 0) + grams;
      }
    }

    // Calcular estimaciones
    final estimates = <InventoryEstimate>[];
    final daysInPeriod = DateTime.now().difference(thirtyDaysAgo).inDays;

    for (final item in pantryItems) {
      final itemId = item['id'] as String? ?? '';
      final quantityStr = item['quantity'] as String? ?? '';
      final currentQty = double.tryParse(
            quantityStr.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.'),
          ) ??
          0;

      if (currentQty <= 0 || itemId.isEmpty) {
        estimates.add(InventoryEstimate(
          pantryItemId: itemId,
          currentQuantity: 0,
          dailyConsumption: 0,
          estimatedDaysLeft: 0,
        ));
        continue;
      }

      final totalConsumed = consumptionByItem[itemId] ?? 0;
      final dailyAvg = daysInPeriod > 0 ? totalConsumed / daysInPeriod : 0.0;
      final daysLeft = dailyAvg > 0 ? (currentQty / dailyAvg).floor() : 999;

      estimates.add(InventoryEstimate(
        pantryItemId: itemId,
        currentQuantity: currentQty,
        dailyConsumption: dailyAvg,
        estimatedDaysLeft: daysLeft,
        isCritical: daysLeft <= 1 && dailyAvg > 0,
        isWarning: daysLeft <= 3 && daysLeft > 1 && dailyAvg > 0,
      ));
    }

    return estimates;
  }
}
