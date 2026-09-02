import 'package:flutter/material.dart';

/// Paleta "Noche Ámbar" — tokens idénticos a los `:root` del diseño HTML
/// del Home Dashboard (konbini japonés a las 3 AM).
///
/// Solo el dashboard y la navegación inferior usan esta paleta por ahora;
/// el resto de la app sigue en el tema claro (`AppColors`).
abstract final class AmberPalette {
  // Superficies
  static const bg = Color(0xFF101014);
  static const bgDeep = Color(0xFF0A0A0D);
  static const surface = Color(0xFF1A1A20);
  static const surfaceHigh = Color(0xFF1D1A16);

  /// Línea de marca: rgba(240, 180, 41, 0.14)
  static const surfaceLine = Color(0x24F0B429);

  // Marca
  static const amber = Color(0xFFF0B429);
  static const amberSoft = Color(0xFFFFD166);
  static const ember = Color(0xFFFF6B3D);
  static const cat = Color(0xFFFFB37A);

  // Semánticos
  static const ok = Color(0xFF7BD88F);
  static const warn = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5B5B);
  static const info = Color(0xFF6EC8FF);

  // Texto
  static const text = Color(0xFFF4EFE6);
  static const textDim = Color(0xFFA49B8D);
  static const textFaint = Color(0xFF6B6459);

  // Macros
  static const protein = Color(0xFFFF6B3D);
  static const carbs = Color(0xFFF0B429);
  static const fat = Color(0xFF6EC8FF);
}
