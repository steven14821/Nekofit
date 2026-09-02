import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'neko_cat_mascot.dart';

/// Modo de la ráfaga de partículas.
enum BurstMode {
  /// Confeti clásico: dispara desde [ParticleBurst.origin] hacia arriba y cae.
  confetti,

  /// Brasas de racha: ascienden desde abajo con vaivén (estilo fuego).
  embers,

  /// Ráfaga radial para subidas de nivel.
  radial,
}

/// Ráfaga de partículas (confeti / brasas / chispas) dibujada con
/// `CustomPainter`. Se dispara una vez al montar (si [trigger] > 0) y de nuevo
/// cada vez que cambia [trigger]. Ignora toques para no bloquear la UI.
///
/// Best-effort: la animación nunca depende de red ni de servicios.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    required this.trigger,
    this.count = 60,
    this.colors,
    this.mode = BurstMode.confetti,
    this.origin = const Alignment(0, 0.8),
    this.duration = const Duration(milliseconds: 2200),
    this.onFinished,
  });

  /// Cambiar este valor re-dispara la ráfaga.
  final int trigger;
  final int count;
  final List<Color>? colors;
  final BurstMode mode;

  /// Punto de lanzamiento dentro del Stack (normalizado).
  final Alignment origin;
  final Duration duration;
  final VoidCallback? onFinished;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<Color> _confettiColors = [
    AppColors.cat,
    AppColors.inStock,
    AppColors.accentSoft,
    Color(0xFF52B788),
    AppColors.depleted,
    Colors.white,
  ];

  static const List<Color> _emberColors = [
    Color(0xFFFF9800),
    AppColors.cat,
    Color(0xFFFF5252),
    Color(0xFFFFD54F),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished?.call();
    });
    if (widget.trigger > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(ParticleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        (widget.mode == BurstMode.embers ? _emberColors : _confettiColors);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            progress: _controller.value,
            trigger: widget.trigger,
            count: widget.count,
            colors: colors,
            mode: widget.mode,
            origin: widget.origin,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.progress,
    required this.trigger,
    required this.count,
    required this.colors,
    required this.mode,
    required this.origin,
  });

  final double progress;
  final int trigger;
  final int count;
  final List<Color> colors;
  final BurstMode mode;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Semilla estable por disparo: las partículas no "brincan" entre frames.
    final rng = math.Random(trigger.abs() * 7919 + count);
    final originOffset = origin.alongSize(size);
    final speedFactor = math.max(size.shortestSide * 0.55, 120.0);

    for (var i = 0; i < count; i++) {
      final color = colors[i % colors.length];

      // Dirección según el modo.
      final double angle;
      switch (mode) {
        case BurstMode.confetti:
          angle = -math.pi * (0.05 + rng.nextDouble() * 0.9);
        case BurstMode.embers:
          angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 0.9;
        case BurstMode.radial:
          angle = rng.nextDouble() * math.pi * 2;
      }

      final speed =
          mode == BurstMode.embers ? 0.3 + rng.nextDouble() * 0.35 : 0.5 + rng.nextDouble() * 0.6;
      final particleSize = mode == BurstMode.embers
          ? 2.5 + rng.nextDouble() * 3.5
          : 3.5 + rng.nextDouble() * 4.5;
      final delay = rng.nextDouble() * 0.16;

      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final eased = Curves.easeOutCubic.transform(t);
      // Las brasas no caen; el confeti y la radial sí (gravedad).
      final gravity = mode == BurstMode.embers ? -0.03 : 0.5;
      final spreadX = (0.6 + rng.nextDouble() * 0.7);

      final dx = math.cos(angle) * speed * eased * speedFactor * spreadX;
      final sway = mode == BurstMode.embers
          ? math.sin(progress * math.pi * 6 + i * 0.7) * 20.0
          : 0.0;
      final dy = math.sin(angle) * speed * eased * speedFactor +
          gravity * eased * eased * speedFactor * 1.7 +
          sway;
      final pos = originOffset + Offset(dx, dy);

      final opacity = (1 - t) * (mode == BurstMode.embers ? 1.0 : 0.9);
      if (opacity <= 0) continue;

      final isRound = mode == BurstMode.embers ||
          (mode == BurstMode.radial && i.isEven);
      final rotation = rng.nextDouble() * math.pi * 2 * t;

      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      if (isRound) {
        canvas.drawCircle(Offset.zero, particleSize, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: particleSize * 1.7,
              height: particleSize * 0.9,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trigger != trigger ||
      oldDelegate.mode != mode ||
      oldDelegate.count != count;
}

/// Celebración de subida de nivel: ráfaga radial + gato + "¡NIVEL N!".
///
/// Se anima al montar y avisa con [onFinished] al terminar para que el padre
/// lo pueda quitar del árbol (o ignorarlo si el overlay es efímero).
class LevelUpCelebration extends StatefulWidget {
  const LevelUpCelebration({
    super.key,
    required this.level,
    this.xp = 0,
    this.catName = 'Mochi',
    this.onFinished,
    this.duration = const Duration(milliseconds: 3000),
  });

  final int level;
  final int xp;
  final String catName;
  final VoidCallback? onFinished;
  final Duration duration;

  @override
  State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _scale;
  late final AnimationController _fade;

  static const List<Color> _levelColors = [
    AppColors.accent,
    AppColors.inStock,
    Color(0xFF4CAF50),
    Colors.white,
    AppColors.cat,
  ];

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = AnimationController(vsync: this, duration: widget.duration);
    _fade.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished?.call();
    });
    _scale.forward();
    _fade.forward();
  }

  @override
  void dispose() {
    _scale.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popIn = CurvedAnimation(parent: _scale, curve: Curves.elasticOut);
    final fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _fade,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ParticleBurst(
            trigger: 1,
            mode: BurstMode.radial,
            origin: const Alignment(0, -0.05),
            colors: _levelColors,
            count: 80,
          ),
          Center(
            child: ScaleTransition(
              scale: popIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadii.stamp),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Text(
                      '¡SUBISTE DE NIVEL!',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.accentSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const NekoCatMascot(mood: CatMood.success, size: 130),
                  const SizedBox(height: 16),
                  Text(
                    '¡NIVEL ${widget.level}!',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.catName} creció. Los outfits de nivel se desbloquean.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (widget.xp > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.xp}/100 XP',
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
