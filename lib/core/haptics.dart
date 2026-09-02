import 'package:flutter/services.dart';

/// Lenguaje Háptico de NekoFit.
///
/// Define un vocabulario táctil consistente para que el usuario pueda
/// entender qué está pasando sin mirar la pantalla.
///
/// | Acción | Patrón | Significado |
/// | :--- | :--- | :--- |
/// | `tap()` | Light | Acción menor / Navegación |
/// | `success()` | Medium | Confirmación / Logro |
/// | `error()` | Heavy | Fallo / Acción prohibida |
/// | `select()` | Selection | Cambio de estado sutil (chips/tabs) |
/// | `warn()` | Light $\rightarrow$ Medium | Alerta / Atención del gato |
/// | `impact(level)` | Varia | Feedback físico según intensidad |
class Haptics {
  Haptics._();

  /// Toque ligero para acciones menores: abrir un producto, toggles, navegar.
  static Future<void> tap() => HapticFeedback.lightImpact();

  /// Confirmación media para logros: comida guardada, subida de nivel,
  /// nuevo récord, operación completada.
  static Future<void> success() => HapticFeedback.mediumImpact();

  /// Impacto fuerte para errores: validación fallida, acción inválida.
  static Future<void> error() => HapticFeedback.heavyImpact();

  /// Clic de selección: Feedback sutil para chips, pestañas o sliders.
  static Future<void> select() => HapticFeedback.selectionClick();

  /// Alerta sarcástica: Doble vibración para llamar la atención.
  static Future<void> warn() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// Impacto genérico basado en nivel.
  static Future<void> impact(HapticLevel level) {
    switch (level) {
      case HapticLevel.light:
        return HapticFeedback.lightImpact();
      case HapticLevel.medium:
        return HapticFeedback.mediumImpact();
      case HapticLevel.heavy:
        return HapticFeedback.heavyImpact();
    }
  }
}

enum HapticLevel { light, medium, heavy }
