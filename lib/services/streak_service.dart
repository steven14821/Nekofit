import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/meal_entry.dart';

class StreakService {
  StreakService._internal();
  static final StreakService instance = StreakService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Multiplicador de XP según los días de racha consecutivos:
  ///  - 0 a 2 días: 1.0x (Base)
  ///  - 3 a 6 días: 1.2x (Llama Ámbar 🔥)
  ///  - 7 a 13 días: 1.5x (Llama Dorada 🔥🔥)
  ///  - 14 a 29 días: 2.0x (Llama Fuego Azul ⚡)
  ///  - 30+ días: 2.5x (Llama Mítica / Corona 👑)
  static double multiplierForStreak(int streak) {
    if (streak >= 30) return 2.5;
    if (streak >= 14) return 2.0;
    if (streak >= 7) return 1.5;
    if (streak >= 3) return 1.2;
    return 1.0;
  }

  /// Información completa del tier de racha actual para la UI (colores, emojis, meta).
  static ({
    String tierName,
    Color color,
    Color glowColor,
    String flameEmoji,
    int? nextTierStreak,
    double multiplier,
    int minStreak,
  }) streakTier(int streak) {
    if (streak >= 30) {
      return (
        tierName: 'Llama Mítica',
        color: const Color(0xFFFFD700), // Dorado puro / Corona
        glowColor: const Color(0xFFFF8C00),
        flameEmoji: '👑🔥',
        nextTierStreak: null,
        multiplier: 2.5,
        minStreak: 30,
      );
    } else if (streak >= 14) {
      return (
        tierName: 'Llama Azul Épica',
        color: const Color(0xFF00E5FF), // Cyan/Azul fuego
        glowColor: const Color(0xFF0091EA),
        flameEmoji: '⚡🔥',
        nextTierStreak: 30,
        multiplier: 2.0,
        minStreak: 14,
      );
    } else if (streak >= 7) {
      return (
        tierName: 'Llama Dorada',
        color: const Color(0xFFFF9800), // Naranja ardiente
        glowColor: const Color(0xFFFF5722),
        flameEmoji: '🔥🔥',
        nextTierStreak: 14,
        multiplier: 1.5,
        minStreak: 7,
      );
    } else if (streak >= 3) {
      return (
        tierName: 'Llama Ámbar',
        color: const Color(0xFFF0B429), // Ámbar marca
        glowColor: const Color(0xFFFFB020),
        flameEmoji: '🔥',
        nextTierStreak: 7,
        multiplier: 1.2,
        minStreak: 3,
      );
    } else {
      return (
        tierName: 'Chispa Inicial',
        color: const Color(0xFF8B8A82), // Muted
        glowColor: Colors.transparent,
        flameEmoji: '✨',
        nextTierStreak: 3,
        multiplier: 1.0,
        minStreak: 0,
      );
    }
  }

  /// Calcula la XP ganada tras aplicar el multiplicador de racha.
  static int calculateXpWithMultiplier(int baseXp, int streak) {
    final mult = multiplierForStreak(streak);
    return (baseXp * mult).round();
  }

  /// Normaliza una fecha a las 00:00:00 del mismo día para comparaciones por calendario.
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Verifica la racha al abrir la app. Si han pasado más de 1 día desde el último registro,
  /// resetea `currentStreak` a 0 visualmente en Firestore.
  Future<void> checkStreakOnAppLaunch(String uid) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data();
      if (data == null) return;

      final lastLogged = data['lastLoggedDate'];
      final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;

      if (lastLogged == null || currentStreak == 0) return;

      DateTime? lastDate;
      if (lastLogged is Timestamp) {
        lastDate = lastLogged.toDate();
      } else if (lastLogged is String) {
        lastDate = DateTime.tryParse(lastLogged);
      }

      if (lastDate != null) {
        final today = _normalizeDate(DateTime.now());
        final lastDay = _normalizeDate(lastDate);
        final diffDays = today.difference(lastDay).inDays;

        // Si pasó más de 1 día (ej. anteayer o antes), la racha activa cayó a 0
        if (diffDays > 1) {
          await docRef.update({
            'currentStreak': 0,
          });
        }
      }
    } catch (_) {}
  }

  /// Verifica si hay al menos un registro de cada uno de los 4 tipos de
  /// comida (breakfast, lunch, dinner, snack) en [todayMeals].
  ///
  /// Solo cuando esto es `true` el día cuenta para la racha.
  static bool allMealTypesLogged(List<Map<String, dynamic>> todayMeals) {
    final logged = todayMeals
        .map((m) => (m['mealType'] as String?) ?? '')
        .toSet();
    return MealType.values.every((t) => logged.contains(t.name));
  }

  /// Ejecutado tras registrar cualquier comida.
  ///
  /// Requiere [todayMeals]: todos los documentos de comidas registrados HOY
  /// por el usuario (con el campo `mealType`).
  ///
  /// La racha **solo avanza** cuando el usuario ha registrado al menos una
  /// entrada en cada uno de los 4 tipos de comida del día
  /// (Desayuno, Almuerzo, Cena y Snack).
  ///
  /// Retorna un Map con `currentStreak`, `longestStreak` y
  /// `allMealsCompleted` (bool).
  Future<Map<String, dynamic>> updateStreakOnMealLogged(
    String uid, {
    required List<Map<String, dynamic>> todayMeals,
  }) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      final snap = await docRef.get();

      int currentStreak = 0;
      int longestStreak = 0;
      DateTime? lastDate;

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
        longestStreak = (data['longestStreak'] as num?)?.toInt() ?? 0;

        final rawLast = data['lastLoggedDate'];
        if (rawLast is Timestamp) {
          lastDate = rawLast.toDate();
        } else if (rawLast is String) {
          lastDate = DateTime.tryParse(rawLast);
        }
      }

      final now = DateTime.now();
      final today = _normalizeDate(now);

      // Solo avanzar la racha si el día tiene las 4 comidas completas.
      final completed = allMealTypesLogged(todayMeals);

      if (!completed) {
        // Aún faltan comidas: guardamos progreso del día pero no movemos racha.
        return {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'allMealsCompleted': false,
        };
      }

      // Las 4 comidas están completas → evaluar racha.
      if (lastDate == null) {
        currentStreak = 1;
        if (currentStreak > longestStreak) longestStreak = currentStreak;
      } else {
        final lastDay = _normalizeDate(lastDate);
        final diffDays = today.difference(lastDay).inDays;

        if (diffDays == 0) {
          // Ya completó las 4 comidas hoy (registro duplicado): sin cambio.
          if (currentStreak == 0) currentStreak = 1;
          if (currentStreak > longestStreak) longestStreak = currentStreak;
        } else if (diffDays == 1) {
          // Completó ayer, hoy también: racha +1.
          currentStreak += 1;
          if (currentStreak > longestStreak) longestStreak = currentStreak;
        } else {
          // Hubo un hueco: reinicia racha.
          currentStreak = 1;
          if (currentStreak > longestStreak) longestStreak = currentStreak;
        }
      }

      await docRef.set({
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastLoggedDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'allMealsCompleted': true,
      };
    } catch (_) {
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'allMealsCompleted': false,
      };
    }
  }
}

