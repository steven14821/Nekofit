import 'dart:async';

import 'package:nekofit/models/pet_state.dart';
import 'package:nekofit/services/firebase_service.dart';
import 'package:nekofit/services/notification_service.dart';
import 'package:nekofit/services/pet_service.dart';

/// Fake de [AuthRepository] que NO toca Firebase: los tests controlan qué
/// documento devolver y qué uid emite el stream de sesión.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository()
      : _controller = StreamController<String?>.broadcast(sync: true);

  final StreamController<String?> _controller;

  /// Documento que devolverá [fetchUserDoc] (null = documento inexistente).
  Map<String, dynamic>? doc;

  /// Error que lanzará [fetchUserDoc] si está seteado.
  Object? error;

  /// Valor de [currentUid] usado por `refresh()`.
  String? currentUidValue;

  int fetchCalls = 0;

  /// Emite un cambio de sesión (uid o null para logout).
  void emit(String? uid) => _controller.add(uid);

  @override
  Stream<String?> get authState => _controller.stream;

  @override
  String? get currentUid => currentUidValue;

  @override
  Future<Map<String, dynamic>?> fetchUserDoc(String uid) async {
    fetchCalls++;
    final err = error;
    if (err != null) throw err;
    return doc;
  }

  @override
  Future<void> logout() async {}
}

/// Fake de [NotificationService]: no toca plugins ni Firestore. Solo cuenta
/// cuántas veces se programaron los recordatorios.
class FakeNotifications extends NotificationService {
  int mealSchedules = 0;
  int contextualSchedules = 0;

  @override
  Future<Map<String, String>> getSavedMealTimes() async => const {};

  @override
  Future<void> scheduleMealReminders(Map<String, String>? customTimes) async {
    mealSchedules++;
  }

  @override
  Future<void> scheduleContextualNotifications() async {
    contextualSchedules++;
  }
}

/// Perfil "completo" mínimo: los mismos campos que exige el auth-gate.
Map<String, dynamic> completeProfile({
  String uid = 'user-1',
  String username = 'Neko',
}) {
  return {
    'uid': uid,
    'username': username,
    'age': 28,
    'weight': 72.0,
    'height': 172.0,
    'fitnessGoal': 'Mantener peso',
    'macroGoals': {
      // Firestore guarda doubles; Map<String, double>.from no acepta ints.
      'calories': 2200.0,
      'proteins': 140.0,
      'carbs': 220.0,
      'fats': 75.0,
    },
  };
}

/// Fake de [PetRepository]: sin Firebase. Emite un [PetState] editable y
/// cuenta suscripciones activas para verificar re-subscripciones al cambiar
/// de usuario.
class FakePetRepository implements PetRepository {
  final Map<String, StreamController<PetState>> _controllers = {};

  /// Último uid al que se suscribió.
  String? lastSubscribedUid;

  /// Suscripciones de stream activas (Riverpod abre 2 por provider:
  /// `lastCancelable` + `stream.listen`).
  int activeSubscriptions = 0;

  /// Uids cuya suscripción de stream se cerró (para verificar cleanup).
  final Set<String> cancelledUids = {};

  /// Estado emitido a los suscriptores. Arranca hambriento (>= 75).
  PetState petState = PetState.initial().copyWith(hunger: 90);

  @override
  Stream<PetState> watchPetState(String uid) {
    lastSubscribedUid = uid;
    final controller = StreamController<PetState>.broadcast();
    _controllers[uid] = controller;
    controller.onListen = () {
      activeSubscriptions++;
      // El estado inicial se entrega en una microtarea: Riverpod adjunta dos
      // suscripciones (lastCancelable + data) en el mismo turno síncrono, y
      // un broadcast no "replay" para suscriptores posteriores.
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(petState);
      });
    };
    controller.onCancel = () {
      activeSubscriptions--;
      cancelledUids.add(uid);
    };
    return controller.stream;
  }

  /// Empuja un nuevo estado (p.ej. hambre actualizada) a todos los
  /// suscriptores vivos del fake.
  void emit(PetState state) {
    petState = state;
    for (final c in _controllers.values) {
      if (!c.isClosed) c.add(state);
    }
  }

  @override
  Future<PetState> getPetState(String uid) async => petState;

  @override
  Future<FeedResult> feedPet(
    String uid, {
    required double kcal,
    required double proteinGrams,
    int streak = 0,
  }) async {
    emit(petState.copyWith(hunger: 0));
    return FeedResult(state: petState, levelsGained: 0, newlyUnlockedOutfits: const []);
  }

  @override
  Future<List<String>> unlockEligibleOutfits(
    String uid, {
    int? streak,
    int? level,
  }) async {
    return const [];
  }

  @override
  Future<PetState> unlockOutfit(String uid, String outfitId) async => petState;

  @override
  Future<PetState> equipOutfit(String uid, String outfitId) async => petState;
}