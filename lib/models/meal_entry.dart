import 'package:cloud_firestore/cloud_firestore.dart';

/// Las 4 comidas del día en NekoFit.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Desayuno';
      case MealType.lunch:
        return 'Almuerzo';
      case MealType.dinner:
        return 'Cena';
      case MealType.snack:
        return 'Snack';
    }
  }

  static MealType fromString(String s) {
    switch (s) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.breakfast;
    }
  }
}

/// Una comida registrada en el diario alimentario.
///
/// Se guarda en la subcolección `users/{uid}/meals`.
/// Las macros se calculan al momento de registrar: se toman los valores
/// por 100g del alimento de la despensa y se escalan por los gramos reales
/// que el usuario indicó.
class MealEntry {
  final String id;
  final MealType mealType;
  final String foodName;
  final double grams;
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;
  final DateTime createdAt;
  final String? pantryItemId;
  final String? imageUrl;

  const MealEntry({
    required this.id,
    required this.mealType,
    required this.foodName,
    required this.grams,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.createdAt,
    this.pantryItemId,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'mealType': mealType.name,
      'foodName': foodName,
      'grams': grams,
      'calories': calories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'createdAt': Timestamp.fromDate(createdAt),
      'pantryItemId': pantryItemId,
      'imageUrl': imageUrl,
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final ts = map['createdAt'];
    if (ts is Timestamp) {
      parsedDate = ts.toDate();
    } else if (ts is String) {
      parsedDate = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return MealEntry(
      id: docId,
      mealType: MealType.fromString(map['mealType'] ?? 'breakfast'),
      foodName: map['foodName'] ?? '',
      grams: (map['grams'] ?? 0).toDouble(),
      calories: (map['calories'] ?? 0).toDouble(),
      proteins: (map['proteins'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fats: (map['fats'] ?? 0).toDouble(),
      createdAt: parsedDate,
      pantryItemId: map['pantryItemId'],
      imageUrl: map['imageUrl'],
    );
  }
}
