import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de la mascota virtual (Mochi) por usuario.
///
/// Se persiste como un único documento en `users/{uid}/pet/state`.
/// No usamos subcolección porque el estado del gato es escalar: un solo
/// documento actualizado atómicamente (cumple RNF-3 — sin duplicación).
class PetState {
  /// Hambre en escala 0..100. 0 = lleno, 100 = hambriento.
  final double hunger;

  /// Humor derivado: 'feliz' | 'ok' | 'hartito' | 'enojado'.
  final String mood;

  /// Nivel: sube cada 100 XP.
  final int level;

  /// XP acumulado desde el último nivel (0..99).
  final int xp;

  /// XP total acumulada a lo largo de la vida de la mascota (sólo lectura,
  /// para mostrar en stats). Se calcula derivando de level + xp.
  final int xpTotal;

  /// Id del outfit actualmente equipado (clave en `Outfits.byId`).
  final String currentOutfit;

  /// Outfits desbloqueados. Lista serializada como array de strings.
  final List<String> ownedOutfits;

  /// Última vez que la mascota comió (alimentada vía diario alimentario).
  final DateTime? lastFedAt;

  /// Última actualización del documento.
  final DateTime lastUpdatedAt;

  PetState({
    required this.hunger,
    required this.mood,
    required this.level,
    required this.xp,
    required this.xpTotal,
    required this.currentOutfit,
    required this.ownedOutfits,
    required this.lastFedAt,
    required this.lastUpdatedAt,
  });

  /// Estado inicial: mascota recién creada, sin nombre aún, con bastante hambre
  /// (nunca ha comido) y equipado con el outfit por defecto.
  factory PetState.initial() {
    final now = DateTime.now();
    return PetState(
      hunger: 50,
      mood: 'ok',
      level: 1,
      xp: 0,
      xpTotal: 0,
      currentOutfit: 'default',
      ownedOutfits: const ['default'],
      lastFedAt: now.subtract(const Duration(hours: 8)),
      lastUpdatedAt: now,
    );
  }

  /// Versión mutable para aplicar cambios locales (la fuente de verdad es Firestore;
  /// este modelo se rehidrata desde el documento).
  PetState copyWith({
    double? hunger,
    String? mood,
    int? level,
    int? xp,
    int? xpTotal,
    String? currentOutfit,
    List<String>? ownedOutfits,
    DateTime? lastFedAt,
    DateTime? lastUpdatedAt,
  }) {
    return PetState(
      hunger: hunger ?? this.hunger,
      mood: mood ?? this.mood,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpTotal: xpTotal ?? this.xpTotal,
      currentOutfit: currentOutfit ?? this.currentOutfit,
      ownedOutfits: ownedOutfits ?? this.ownedOutfits,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hunger': hunger,
      'mood': mood,
      'level': level,
      'xp': xp,
      'xpTotal': xpTotal,
      'currentOutfit': currentOutfit,
      'ownedOutfits': ownedOutfits,
      'lastFedAt':
          lastFedAt != null ? Timestamp.fromDate(lastFedAt!) : FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PetState.fromMap(Map<String, dynamic>? map) {
    final raw = map ?? const {};
    final lastUpdated = raw['lastUpdatedAt'] is Timestamp
        ? (raw['lastUpdatedAt'] as Timestamp).toDate()
        : DateTime.now();
    final lastFed = raw['lastFedAt'] is Timestamp
        ? (raw['lastFedAt'] as Timestamp).toDate()
        : null;
    return PetState(
      hunger: ((raw['hunger'] as num?) ?? 50).toDouble(),
      mood: (raw['mood'] as String?) ?? 'ok',
      level: ((raw['level'] as num?) ?? 1).toInt(),
      xp: ((raw['xp'] as num?) ?? 0).toInt(),
      xpTotal: ((raw['xpTotal'] as num?) ?? 0).toInt(),
      currentOutfit: (raw['currentOutfit'] as String?) ?? 'default',
      ownedOutfits:
          (raw['ownedOutfits'] as List?)?.map((e) => e.toString()).toList() ??
              const ['default'],
      lastFedAt: lastFed,
      lastUpdatedAt: lastUpdated,
    );
  }

  /// Calcula el hambre actual considerando el tiempo transcurrido desde la
  /// última comida. Cada hora suma ~3 puntos de hambre (lineal, máximo 100):
  /// si no se registran comidas, la mascota se vuelve hambrienta en menos de
  /// un día (100 a las ~33h desde la última comida).
  ///
  /// Se evalúa cada vez que la UI lee el estado, sin necesidad de un timer.
  double get currentHunger {
    final last = lastFedAt ?? lastUpdatedAt;
    final hoursSinceFed = DateTime.now().difference(last).inMinutes / 60.0;
    final fresh = hunger + (hoursSinceFed * 3.0);
    return fresh.clamp(0.0, 100.0);
  }

  /// Mood derivado del hambre actual.
  String get currentMood {
    final h = currentHunger;
    if (h >= 75) return 'enojado';
    if (h >= 45) return 'hartito';
    if (h >= 15) return 'ok';
    return 'feliz';
  }

  /// Progreso al siguiente nivel en 0..1.
  double get levelProgress => (xp / 100.0).clamp(0.0, 1.0);
}

/// Constantes del mood para evitar magic strings en la UI.
class PetMoods {
  PetMoods._();
  static const String happy = 'feliz';
  static const String ok = 'ok';
  static const String full = 'hartito';
  static const String angry = 'enojado';

  static const List<String> all = [happy, ok, full, angry];

  static String label(String mood) {
    switch (mood) {
      case happy:
        return 'Feliz';
      case ok:
        return 'Ok';
      case full:
        return 'Hartito';
      case angry:
        return 'Enojado';
      default:
        return mood;
    }
  }
}
