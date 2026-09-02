import 'package:cloud_firestore/cloud_firestore.dart';

class PantryItem {
  final String id;
  final String name;
  final String category;
  final bool isAvailable;
  final String quantity;
  final String? originalQuantity;
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;
  final DateTime lastReplenished;
  final String? barcode;
  final String? imageUrl;
  final String? baseUnit;
  final String? source;
  /// Precio por unidad de compra (opcional). Se usa en el comparador
  /// de productos para calcular proteína/precio y calorías/precio.
  /// Si es null, las métricas de precio no se muestran en el comparador.
  final double? price;

  PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.isAvailable,
    required this.quantity,
    this.originalQuantity,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.lastReplenished,
    this.barcode,
    this.imageUrl,
    this.baseUnit,
    this.source,
    this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isAvailable': isAvailable,
      'quantity': quantity,
      'originalQuantity': originalQuantity ?? quantity,
      'calories': calories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'lastReplenished': Timestamp.fromDate(lastReplenished),
      'barcode': barcode,
      'imageUrl': imageUrl,
      'baseUnit': baseUnit,
      'source': source,
      if (price != null) 'price': price,
    };
  }

  factory PantryItem.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final repVal = map['lastReplenished'];
    if (repVal is Timestamp) {
      parsedDate = repVal.toDate();
    } else if (repVal is String) {
      parsedDate = DateTime.tryParse(repVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return PantryItem(
      id: docId,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Proteínas',
      isAvailable: map['isAvailable'] ?? true,
      quantity: map['quantity'] ?? '1 unidad',
      originalQuantity: map['originalQuantity'],
      calories: (map['calories'] ?? 0.0).toDouble(),
      proteins: (map['proteins'] ?? 0.0).toDouble(),
      carbs: (map['carbs'] ?? 0.0).toDouble(),
      fats: (map['fats'] ?? 0.0).toDouble(),
      lastReplenished: parsedDate,
      barcode: map['barcode'],
      imageUrl: map['imageUrl'],
      baseUnit: map['baseUnit'],
      source: map['source'],
      price: (map['price'] as num?)?.toDouble(),
    );
  }
}
