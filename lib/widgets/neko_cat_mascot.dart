import 'dart:math';
import 'package:flutter/material.dart';
import '../core/neko_palette.dart';
import '../models/pet_state.dart';

enum CatMood { idle, thinking, success, alert }

/// Devuelve el asset de la mascota según el `petType` guardado en el perfil.
/// 'gato' (default) | 'perro1' | 'perro2'.
String petAssetPath(String petType) {
  switch (petType) {
    case 'perro1':
      return 'assets/images/perro1_sin_fondo.png';
    case 'perro2':
      return 'assets/images/perro2_sin_fondo.png';
    default:
      return 'assets/images/icono_sin_fondo.png';
  }
}

class NekoCatMascot extends StatefulWidget {
  final CatMood mood;
  final double size;
  final bool showLabel;

  /// Ruta al asset de la mascota seleccionada (gato o perro).
  /// Si es null usa el gato por defecto.
  final String? imagePath;

  /// Overlay opcional para outfits. Ruta a un asset PNG/JPG que se dibuja
  /// ENCIMA del gato con `BoxFit.contain`. Si no hay outfit, pasar null.
  final String? outfitOverlayPath;

  /// Versión del mood desde un `PetState` (helper). Si se pasa, tiene
  /// precedencia sobre [mood] para el color de aura y la animación.
  final PetState? petState;

  const NekoCatMascot({
    super.key,
    this.mood = CatMood.idle,
    this.size = 120,
    this.showLabel = true,
    this.outfitOverlayPath,
    this.petState,
    this.imagePath,
  });

  @override
  State<NekoCatMascot> createState() => _NekoCatMascotState();
}

class _NekoCatMascotState extends State<NekoCatMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(NekoCatMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getMoodColor() {
    // Si llega un PetState, derivamos color directamente del hambre actual.
    final ps = widget.petState;
    if (ps != null) {
      switch (ps.currentMood) {
        case PetMoods.happy:
          return const Color(0xFF4CAF50);
        case PetMoods.full:
          return const Color(0xFFFF9800);
        case PetMoods.ok:
          return Colors.white;
        case PetMoods.angry:
          return const Color(0xFFFF5252);
      }
    }
    switch (widget.mood) {
      case CatMood.idle:
        return Colors.white;
      case CatMood.thinking:
        return NekoPalette.cat(NekoThemeMode.dark);
      case CatMood.success:
        return const Color(0xFF4CAF50);
      case CatMood.alert:
        return const Color(0xFFFF5252);
    }
  }

  String _getMoodText() {
    final ps = widget.petState;
    if (ps != null) {
      switch (ps.currentMood) {
        case PetMoods.happy:
          return '¡Lleno y feliz! Sigue así.';
        case PetMoods.full:
          return 'Estoy un poco hartito…';
        case PetMoods.ok:
          return 'Todo bien por ahora';
        case PetMoods.angry:
          return '¡Tengo hambre! Aliméntame.';
      }
    }
    switch (widget.mood) {
      case CatMood.idle:
        return '¡Hola! Estoy aquí para ayudarte';
      case CatMood.thinking:
        return 'Déjame analizar esto...';
      case CatMood.success:
        return '¡Listo! Buen provecho';
      case CatMood.alert:
        return '¡Ojo! Se te está acabando algo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getMoodColor();
    final ps = widget.petState;

    // Si hay petState, derivamos mood-animación del hambre actual.
    final effectiveMood = ps != null ? _moodFromString(ps.currentMood) : widget.mood;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final breathScale = 0.95 + (_controller.value * 0.1);
            double scale = breathScale;
            double rotation = 0;

            switch (effectiveMood) {
              case CatMood.thinking:
                rotation = sin(_controller.value * pi * 2) * 0.05;
                scale *= 1.05;
                break;
              case CatMood.success:
                scale *= 1.1;
                break;
              case CatMood.alert:
                rotation = sin(_controller.value * pi * 6) * 0.03;
                break;
              case CatMood.idle:
                break;
            }

            return Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          widget.imagePath ?? 'assets/images/icono_sin_fondo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Overlay del outfit (encima del gato). Para outfits
                      // tipo "capa" el asset debería ser full-circle sin fondo.
                      if (widget.outfitOverlayPath != null)
                        IgnorePointer(
                          child: ClipOval(
                            child: Image.asset(
                              widget.outfitOverlayPath!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _getMoodText(),
              key: ValueKey(ps != null ? ps.currentMood : widget.mood),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  CatMood _moodFromString(String mood) {
    switch (mood) {
      case PetMoods.happy:
        return CatMood.success;
      case PetMoods.full:
        return CatMood.thinking;
      case PetMoods.angry:
        return CatMood.alert;
      default:
        return CatMood.idle;
    }
  }
}
