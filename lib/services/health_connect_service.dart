import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Actividad agregada de un día leída desde Health Connect.
class DailyActivity {
  final DateTime day;
  final double steps;
  final double distanceMeters;
  final double activeKcal;

  const DailyActivity({
    required this.day,
    required this.steps,
    required this.distanceMeters,
    required this.activeKcal,
  });

  double get distanceKm => distanceMeters / 1000.0;
}

/// Acceso a Health Connect (Android) vía el paquete `health`.
///
/// Lee pasos, distancia y calorías activas. Las consultas son locales al
/// dispositivo; no se sube ningún dato de salud a Firestore.
class HealthConnectService {
  static final HealthConnectService instance = HealthConnectService._();
  HealthConnectService._();

  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  // NOTA: el plugin `health` mapea la distancia con DISTANCE_DELTA
  // (DistanceRecord). DISTANCE_WALKING_RUNNING NO existe en el mapToType
  // nativo, por lo que preparePermissionsListInternal devolvía null y
  // requestAuthorization fallaba sin abrir la pantalla de permisos.
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// ¿Está Health Connect instalado y disponible en el dispositivo?
  Future<bool> get isAvailable async {
    try {
      return await _health.isHealthConnectAvailable();
    } catch (e) {
      debugPrint('HealthConnect: isAvailable falló: $e');
      return false;
    }
  }

  /// ¿El usuario ya otorgó acceso de lectura a los 3 tipos?
  Future<bool> hasPermissions() async {
    if (!await isAvailable) return false;
    try {
      await _ensureConfigured();
      final result = await _health.hasPermissions(_types);
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect: hasPermissions falló: $e');
      return false;
    }
  }

  /// Abre la pantalla de permisos de Health Connect. Devuelve true si
  /// el usuario concedió acceso de lectura.
  Future<bool> requestPermissions() async {
    if (!await isAvailable) {
      debugPrint('HealthConnect: requestPermissions abortado, no disponible');
      return false;
    }
    try {
      await _ensureConfigured();
      final granted = await _health.requestAuthorization(_types);
      debugPrint('HealthConnect: requestAuthorization devolvió $granted');
      return granted;
    } catch (e) {
      debugPrint('HealthConnect: requestAuthorization lanzó: $e');
      return false;
    }
  }

  /// Actividad de HOY (pasos, distancia, calorías activas).
  /// Devuelve null si no hay permisos o Health Connect no está disponible.
  Future<DailyActivity?> today() async {
    final days = await lastNDays(1);
    return days.isEmpty ? null : days.last;
  }

  /// Actividad de los últimos [n] días (incluido hoy), del más antiguo
  /// al más reciente. Consulta el rango completo en una sola llamada.
  Future<List<DailyActivity>> lastNDays(int n) async {
    if (!await hasPermissions()) return [];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final start = todayStart.subtract(Duration(days: n - 1));

    try {
      final points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: start,
        endTime: now,
      );

      final byType = <HealthDataType, int>{};
      for (final p in points) {
        byType[p.type] = (byType[p.type] ?? 0) + 1;
      }
      debugPrint(
        'HealthConnect: getHealthDataFromTypes devolvió ${points.length} puntos '
        '(${byType.map((k, v) => MapEntry(k.name, v))}) para $start..$now',
      );

      final dayMap = <String, DailyActivity>{};
      for (int i = n - 1; i >= 0; i--) {
        final day = todayStart.subtract(Duration(days: i));
        dayMap[_key(day)] = DailyActivity(
          day: day,
          steps: 0,
          distanceMeters: 0,
          activeKcal: 0,
        );
      }

      for (final point in points) {
        final value = point.value;
        if (value is! NumericHealthValue) continue;
        final dayKey = _key(point.dateFrom);
        final entry = dayMap[dayKey];
        if (entry == null) continue;

        switch (point.type) {
          case HealthDataType.STEPS:
            dayMap[dayKey] = DailyActivity(
              day: entry.day,
              steps: entry.steps + value.numericValue,
              distanceMeters: entry.distanceMeters,
              activeKcal: entry.activeKcal,
            );
          case HealthDataType.DISTANCE_DELTA:
            dayMap[dayKey] = DailyActivity(
              day: entry.day,
              steps: entry.steps,
              distanceMeters: entry.distanceMeters + value.numericValue,
              activeKcal: entry.activeKcal,
            );
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            dayMap[dayKey] = DailyActivity(
              day: entry.day,
              steps: entry.steps,
              distanceMeters: entry.distanceMeters,
              activeKcal: entry.activeKcal + value.numericValue,
            );
          default:
            break;
        }
      }

      final results = dayMap.values.toList()
        ..sort((a, b) => a.day.compareTo(b.day));
      return results;
    } catch (e) {
      debugPrint('HealthConnect: lastNDays falló: $e');
      return [];
    }
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
