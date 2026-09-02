import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/outfits.dart';
import '../models/pet_state.dart';
import 'firebase_service.dart';
import 'streak_service.dart';

/// Resultado de alimentar a la mascota, para que la UI pueda celebrar.
class FeedResult {
  const FeedResult({
    required this.state,
    required this.levelsGained,
    required this.newlyUnlockedOutfits,
    this.baseXp = 0,
    this.xpGain = 0,
    this.multiplier = 1.0,
  });

  final PetState state;

  /// Niveles subidos en esta comida (0 = sin cambio).
  final int levelsGained;

  /// Ids de outfits desbloqueados automáticamente por nivel.
  final List<String> newlyUnlockedOutfits;

  /// XP base antes del multiplicador.
  final int baseXp;

  /// XP final otorgada (baseXp * multiplier).
  final int xpGain;

  /// Multiplicador de racha aplicado.
  final double multiplier;

  static final FeedResult none = FeedResult(
    state: PetState.initial(),
    levelsGained: 0,
    newlyUnlockedOutfits: [],
    baseXp: 0,
    xpGain: 0,
    multiplier: 1.0,
  );
}

/// Abstracción del pet que consumen la UI y el [petStateProvider].
///
/// Mismos motivos que [AuthRepository]: en tests se sustituye por un fake
/// (`FakePetRepository`) para volar sin Firebase.
abstract interface class PetRepository {
  Future<PetState> getPetState(String uid);

  /// Stream reactivo del estado de la mascota (crea el doc si no existía).
  Stream<PetState> watchPetState(String uid);

  Future<FeedResult> feedPet(
    String uid, {
    required double kcal,
    required double proteinGrams,
    int streak = 0,
  });

  Future<List<String>> unlockEligibleOutfits(
    String uid, {
    int? streak,
    int? level,
  });

  Future<PetState> unlockOutfit(String uid, String outfitId);

  Future<PetState> equipOutfit(String uid, String outfitId);
}

/// Servicio para gestionar el estado de la mascota virtual.
///
/// Persistencia: `users/{uid}/pet/state` (un único doc por usuario).
/// Las operaciones son atómicas cuando es posible (runTransaction / update).
class PetService implements PetRepository {
  PetService._internal();

  static final PetService instance = PetService._internal();

  final FirebaseService _firebase = FirebaseService.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) {
    return _firebase.db
        .collection('users')
        .doc(uid)
        .collection('pet')
        .doc('state');
  }

  @override
  Future<PetState> getPetState(String uid) async {
    final snap = await _ref(uid).get();
    if (!snap.exists) {
      final fresh = PetState.initial();
      await _ref(uid).set(fresh.toMap());
      return fresh;
    }
    return PetState.fromMap(snap.data());
  }

  /// Stream reactivo del estado de la mascota.
  /// Al primer attach crea el documento si no existía.
  @override
  Stream<PetState> watchPetState(String uid) async* {
    final initial = await getPetState(uid);
    yield initial;
    yield* _ref(uid).snapshots().map(
          (snap) => PetState.fromMap(snap.exists ? snap.data() : null),
        );
  }

  /// Alimenta a la mascota al guardar una comida en el diario.
  /// El hambre se resetea a 0, sube XP según macros x multiplicador de racha y se gestiona el nivel.
  /// `kcal` y `proteinGrams` deben venir del total de la comida registrada.
  ///
  /// Devuelve un [FeedResult] para que la UI celebre subidas de nivel,
  /// bonificaciones de racha y desbloqueos automáticos por nivel.
  @override
  Future<FeedResult> feedPet(
    String uid, {
    required double kcal,
    required double proteinGrams,
    int streak = 0,
  }) async {
    final current = await getPetState(uid);

    // XP base por comida: 5..40 según aporte nutricional real.
    final rawBaseXp = ((kcal / 10.0) + (proteinGrams * 2.0)).round().clamp(5, 40);

    // Multiplicador por racha gamificada
    final multiplier = StreakService.multiplierForStreak(streak);
    final xpGain = (rawBaseXp * multiplier).round();

    int newXp = current.xp + xpGain;
    int newLevel = current.level;
    int newXpTotal = current.xpTotal + xpGain;
    int levelsGained = 0;

    // Cascada de niveles: por si una sola comida da mucha XP.
    while (newXp >= 100) {
      newXp -= 100;
      newLevel += 1;
      levelsGained += 1;
    }

    // Outfits que ahora tocan por nivel (local, sin re-leer Firestore).
    final unlocked = _eligibleUnlockIds(
      owned: current.ownedOutfits,
      level: newLevel,
    );

    final updated = current.copyWith(
      hunger: 0,
      mood: 'feliz',
      level: newLevel,
      xp: newXp,
      xpTotal: newXpTotal,
      ownedOutfits: [...current.ownedOutfits, ...unlocked],
      lastFedAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
    );

    await _ref(uid).set(updated.toMap(), SetOptions(merge: true));
    return FeedResult(
      state: updated,
      levelsGained: levelsGained,
      newlyUnlockedOutfits: unlocked,
      baseXp: rawBaseXp,
      xpGain: xpGain,
      multiplier: multiplier,
    );
  }

  /// Desbloquea outfits elegibles por racha o nivel (condiciones tipo
  /// 'Racha de N días' / 'Nivel N'). Es idempotente: solo persiste los nuevos.
  /// Devuelve los ids recién desbloqueados.
  @override
  Future<List<String>> unlockEligibleOutfits(String uid, {int? streak, int? level}) async {
    final current = await getPetState(uid);
    final newly = _eligibleUnlockIds(
      owned: current.ownedOutfits,
      streak: streak,
      level: level,
    );
    if (newly.isEmpty) return const [];

    final owned = [...current.ownedOutfits, ...newly];
    await _ref(uid).set({
      'ownedOutfits': owned,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return newly;
  }

  /// Ids de outfits que ya pueden desbloquearse según racha/nivel y que aún
  /// no posee la mascota. Los outfits 'free' se desbloquean manualmente desde
  /// el vestidor (botón "Desbloquear gratis"), no automáticamente.
  List<String> _eligibleUnlockIds({
    required List<String> owned,
    int? streak,
    int? level,
  }) {
    final ownedSet = owned.toSet();
    final newly = <String>[];
    for (final outfit in Outfits.all) {
      final req = outfit.unlockRequirement();
      if (req == null) continue;
      final (kind, value) = req;
      final eligible = switch (kind) {
        OutfitUnlock.free => false,
        OutfitUnlock.streak => streak != null && streak >= value,
        OutfitUnlock.level => level != null && level >= value,
        OutfitUnlock.comingSoon => false,
      };
      if (eligible && !ownedSet.contains(outfit.id)) newly.add(outfit.id);
    }
    return newly;
  }

  /// Desbloquea un outfit y lo marca como propio.
  @override
  Future<PetState> unlockOutfit(String uid, String outfitId) async {
    final current = await getPetState(uid);
    if (current.ownedOutfits.contains(outfitId)) return current;

    final owned = [...current.ownedOutfits, outfitId];
    await _ref(uid).set({
      'ownedOutfits': owned,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return current.copyWith(
      ownedOutfits: owned,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Equipa un outfit que el usuario ya debe tener desbloqueado.
  /// Devuelve el estado resultante o lanza excepción si no es dueño.
  @override
  Future<PetState> equipOutfit(String uid, String outfitId) async {
    final current = await getPetState(uid);
    if (!current.ownedOutfits.contains(outfitId)) {
      throw StateError('Outfit no desbloqueado: $outfitId');
    }

    await _ref(uid).set({
      'currentOutfit': outfitId,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return current.copyWith(
      currentOutfit: outfitId,
      lastUpdatedAt: DateTime.now(),
    );
  }
}
