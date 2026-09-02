import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'locale_provider.dart';

import '../controllers/auth_gate_controller.dart';
import '../models/pet_state.dart';
import '../services/cat_alert_service.dart';
import '../services/firebase_service.dart';
import '../services/food_scan_cache_service.dart';
import '../services/gemini_vision_service.dart';
import '../services/health_connect_service.dart';
import '../services/nekochat_service.dart';
import '../services/notification_service.dart';
import '../services/nutrition_plan_service.dart';
import '../services/object_detection_service.dart';
import '../services/pet_service.dart';
import '../services/shopping_list_service.dart';
import '../services/streak_service.dart';
import '../services/weekly_plan_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Contenedor de dependencias (Inyección de Dependencias con Riverpod).
///
/// Regla para código NUEVO:
///   • En widgets:  `ref.watch(firebaseServiceProvider)`
///   • En callbacks: `ref.read(firebaseServiceProvider)`
///   • NUNCA importar `FirebaseService.instance` en una pantalla nueva.
///
/// En tests se sobrescriben estos providers para aislar la lógica:
/// ```dart
/// ProviderScope(
///   overrides: [firebaseServiceProvider.overrideWithValue(fakeService)],
///   child: ...
/// )
/// ```
///
/// Los singletons legacy (`Service.instance`) siguen siendo el respaldo de
/// estas fábricas para no romper las pantallas existentes mientras se migran
/// al contenedor (ver análisis en ESTILO.md / refactor de arquitectura).
/// ═══════════════════════════════════════════════════════════════════════════

/// Acceso a Firebase (auth + Firestore). Punto único de sustitución para tests.
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService.instance;
});

/// Abstracción mínima que consume el auth-gate. Se deriva del servicio real,
/// pero en tests se sobrescribe con un fake que no toca Firebase.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(firebaseServiceProvider);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final geminiVisionServiceProvider = Provider<GeminiVisionService>((ref) {
  return GeminiVisionService.instance;
});

final nekoChatServiceProvider = Provider<NekoChatService>((ref) {
  return NekoChatService.instance;
});

/// Acceso al pet (lectura + escritura). Tipado a la interfaz para poder
/// sustituirlo por un fake en tests.
final petServiceProvider = Provider<PetRepository>((ref) => PetService.instance);

/// Estado reactivo del gato de la sesión actual.
///
/// Se deriva del [authGateProvider]: en login/logout/cambio de usuario el
/// provider se reconstruye y se re-subscribe al stream del pet (el stream
/// anterior se cierra solo). Sin sesión no emite nada.
final petStateProvider = StreamProvider.autoDispose<PetState>((ref) {
  final uid = ref.watch(authGateProvider).uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(petServiceProvider).watchPetState(uid);
});

final streakServiceProvider = Provider<StreakService>((ref) => StreakService.instance);

final weeklyPlanServiceProvider = Provider<WeeklyPlanService>((ref) {
  return WeeklyPlanService.instance;
});

final nutritionPlanServiceProvider = Provider<NutritionPlanService>((ref) {
  return NutritionPlanService.instance;
});

final shoppingListServiceProvider = Provider<ShoppingListService>((ref) {
  return ShoppingListService.instance;
});

final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  return HealthConnectService.instance;
});

final objectDetectionServiceProvider = Provider<ObjectDetectionService>((ref) {
  return ObjectDetectionService.instance;
});

final foodScanCacheServiceProvider = Provider<FoodScanCacheService>((ref) {
  return FoodScanCacheService.instance;
});

final catAlertServiceProvider = Provider<CatAlertService>((ref) {
  return CatAlertService.instance;
});