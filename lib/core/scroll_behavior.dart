import 'package:flutter/material.dart';

/// ScrollBehavior personalizado para NekoFit.
///
/// Fuerza el uso de [BouncingScrollPhysics] en toda la aplicación,
/// proporcionando el efecto de "estiramiento" (rubber-banding) característico de iOS,
/// lo que hace que los límites del scroll se sientan físicos y no como una pared dura.
class NekoScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // Ocultamos la scrollbar estándar para un look más limpio.
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
