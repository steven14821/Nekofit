import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/user_context.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

/// Estado del "auth gate": a qué pantalla debe ir la app en cada momento.
///
/// Reemplaza la lógica que vivía dentro del `AuthWrapper` de `main.dart`
/// (StreamBuilder + FutureBuilder + comprobaciones manuales del perfil) por
/// un estado reactivo, testeable y con una única fuente de verdad.
enum AuthGateStatus {
  /// Cargando sesión y/o perfil (splash con el gato).
  checking,

  /// No hay sesión → LoginScreen.
  unauthenticated,

  /// Sesión activa sin onboarding visto → OnboardingScreen.
  needsOnboarding,

  /// Sesión activa con onboarding visto pero perfil incompleto → ProfileSetupScreen.
  needsProfileSetup,

  /// Perfil completo → MainNavigation.
  authenticated,

  /// Error al leer el perfil (p. ej. sin red). La UI ofrece reintentar.
  error,
}

class AuthGateState {
  const AuthGateState({
    required this.status,
    this.uid,
    this.profile,
    this.error,
  });

  final AuthGateStatus status;
  final String? uid;
  final UserContext? profile;
  final String? error;

  static const checking = AuthGateState(status: AuthGateStatus.checking);
}

/// Controlador reactivo de autenticación + "perfil completo".
///
/// Escucha el stream de autenticación y, ante cada cambio de sesión (login,
/// logout, refresh), lee el documento `users/{uid}` y decide la ruta de la
/// app. También es el punto donde se programan las notificaciones una sola
/// vez cuando el usuario entra a la app (best-effort, nunca bloquea la UI).
///
/// Depende de la interfaz [AuthRepository] y de [NotificationService]: ambos
/// se inyectan vía providers, por lo que en tests se sustituyen por fakes.
class AuthGateController extends StateNotifier<AuthGateState> {
  AuthGateController({
    required AuthRepository repository,
    required NotificationService notificationService,
  })
      // Se inyectan por nombre público; el campo es privado a propósito.
      // ignore: prefer_initializing_formals
      : _repository = repository,
        _notifications = notificationService,
        super(const AuthGateState(status: AuthGateStatus.checking)) {
    _authSub = _repository.authState.listen(_onAuthStateChanged);
  }

  final AuthRepository _repository;
  final NotificationService _notifications;
  StreamSubscription<String?>? _authSub;
  bool _notificationsScheduled = false;

  @override
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  void _onAuthStateChanged(String? uid) {
    if (!mounted) return;
    if (uid == null) {
      state = const AuthGateState(status: AuthGateStatus.unauthenticated);
      return;
    }
    // Re-evaluamos el perfil (login o cambio de sesión).
    unawaited(_evaluate(uid));
  }

  /// Fuerza una re-lectura del perfil actual. Se llama desde la UI después
  /// de guardar el profile (setup / edición) para mantener el estado
  /// reactivo al día sin esperar a un cambio de autenticación.
  Future<void> refresh() async {
    final uid = _repository.currentUid;
    if (uid != null) {
      await _evaluate(uid);
    }
  }

  Future<void> _evaluate(String uid) async {
    if (!mounted) return;
    state = AuthGateState(status: AuthGateStatus.checking, uid: uid);
    try {
      final data = await _repository.fetchUserDoc(uid);
      if (!mounted) return;
      if (_isCompleteProfile(data)) {
        await _scheduleNotificationsOnce();
        if (!mounted) return;
        state = AuthGateState(
          status: AuthGateStatus.authenticated,
          uid: uid,
          profile: UserContext.fromMap(data!),
        );
        return;
      }

      // Usuario sin perfil completo: onboarding una sola vez y después el
      // wizard de datos (mismo criterio que tenía el AuthWrapper).
      final hasSeenOnboarding = data?['seenOnboarding'] == true;
      state = AuthGateState(
        status: hasSeenOnboarding
            ? AuthGateStatus.needsProfileSetup
            : AuthGateStatus.needsOnboarding,
        uid: uid,
      );
    } catch (e) {
      if (!mounted) return;
      state = AuthGateState(
        status: AuthGateStatus.error,
        uid: uid,
        error: e.toString(),
      );
    }
  }

  /// El documento es "perfil completo" si tiene los campos reales que
  /// escribe el ProfileSetupScreen (antes solo se miraba `age`).
  static bool _isCompleteProfile(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data.containsKey('age') &&
        data.containsKey('weight') &&
        data.containsKey('height') &&
        data.containsKey('fitnessGoal') &&
        data.containsKey('macroGoals') &&
        (data['age'] is int ? (data['age'] as int) > 0 : true) &&
        ((data['weight'] as num?) ?? 0) > 0 &&
        ((data['height'] as num?) ?? 0) > 0;
  }

  /// Programa las notificaciones inteligentes UNA sola vez por sesión.
  /// Best-effort: si falla, queda pendiente el siguiente `refresh()`.
  Future<void> _scheduleNotificationsOnce() async {
    if (_notificationsScheduled) return;
    try {
      final times = await _notifications.getSavedMealTimes();
      await _notifications.scheduleMealReminders(times);
      await _notifications.scheduleContextualNotifications();
      _notificationsScheduled = true;
    } catch (_) {
      _notificationsScheduled = false;
    }
  }

  Future<void> logout() => _repository.logout();
}

/// Provider del auth-gate. Vive en el ProviderScope raíz (se conserva aunque
/// el AuthWrapper se reconstruya), así el stream de auth no se recrea nunca.
final authGateProvider =
    StateNotifierProvider<AuthGateController, AuthGateState>((ref) {
  return AuthGateController(
    repository: ref.watch(authRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

/// Perfil reactivo del usuario autenticado.
///
/// Es el "UserProvider" que pide la arquitectura: cualquier pantalla puede
/// leer el contexto actual (`ref.watch(userContextProvider)`) y se
/// actualizará cuando el profile cambie en Firestore (login/logout/edit).
final userContextProvider = Provider<UserContext?>((ref) {
  return ref.watch(authGateProvider).profile;
});