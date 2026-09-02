import 'package:flutter/foundation.dart';

/// Alertas del gato que se muestran como badge rojo en la pestaña Mascota.
///
/// Mochi "tiene algo que decir" cuando:
/// - El hambre está alta (>= 75%) → alerta permanente mientras dure.
/// - Ocurrió un evento puntual (p. ej. se rompió el récord de racha) → bump().
///
/// La navegación principal escucha [unread] con un `ValueListenableBuilder`
/// para pintar el dot, y llama [markRead] al entrar a la pestaña Mascota.
class CatAlertService {
  CatAlertService._();

  static final CatAlertService instance = CatAlertService._();

  /// Contador de alertas sin leer (0 = sin dot).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  int _events = 0;
  bool _hungerAlert = false;

  /// Suma un evento puntual (p. ej. récord de racha roto).
  void bump() {
    _events++;
    _recompute();
  }

  /// Limpia las alertas cuando el usuario entra a la pestaña Mascota.
  void markRead() {
    _events = 0;
    _hungerAlert = false;
    _recompute();
  }

  /// Alerta permanente mientras el hambre esté alta.
  void setHighHunger(bool active) {
    if (_hungerAlert == active) return;
    _hungerAlert = active;
    _recompute();
  }

  void _recompute() {
    unread.value = (_hungerAlert ? 1 : 0) + _events;
  }
}
