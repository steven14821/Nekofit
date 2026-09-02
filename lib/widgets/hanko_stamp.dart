import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';

/// Variante del sello hanko.
enum HankoStampKind {
  /// Reposición: sello verde con carácter "入" (entrada/stock).
  replenish,

  /// Producto nuevo: sello rojo con carácter "新" (nuevo).
  newItem,

  /// Logro / nivel: sello dorado con carácter "祝" (celebración).
  celebrate,

  /// Racha: sello rojo con número de días.
  streak,
}

/// Helper estático para lanzar el overlay de un sello hanko animado.
/// Se monta en el `Overlay` raíz y se autodestruye al terminar.
class HankoStamp {
  HankoStamp._();

  static OverlayEntry? _current;

  /// Dispara un sello. Si ya hay uno en pantalla, lo reemplaza.
  static void show(
    BuildContext context, {
    HankoStampKind kind = HankoStampKind.replenish,
    String label = '',
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    Haptics.success();

    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _HankoStampHost(
        kind: kind,
        label: label,
        duration: duration,
        onDismissed: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _HankoStampHost extends StatefulWidget {
  const _HankoStampHost({
    required this.kind,
    required this.label,
    required this.duration,
    required this.onDismissed,
  });

  final HankoStampKind kind;
  final String label;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_HankoStampHost> createState() => _HankoStampHostState();
}

class _HankoStampHostState extends State<_HankoStampHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Fases: caída (0–0.45), impacto+rebote (0.45–0.75), reposo (0.75–1.0).
  static const double _fallEnd = 0.45;
  static const double _reboundEnd = 0.75;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDismissed();
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.kind) {
      case HankoStampKind.replenish:
        return AppColors.inStock;
      case HankoStampKind.newItem:
        return AppColors.depleted;
      case HankoStampKind.celebrate:
        return AppColors.warning;
      case HankoStampKind.streak:
        return AppColors.depleted;
    }
  }

  String get _glyph {
    if (widget.label.isNotEmpty) return widget.label;
    switch (widget.kind) {
      case HankoStampKind.replenish:
        return '入';
      case HankoStampKind.newItem:
        return '新';
      case HankoStampKind.celebrate:
        return '祝';
      case HankoStampKind.streak:
        return '連';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;

        // Posición Y: cae con aceleración (easeIn) hasta el centro, luego
        // rebota hacia arriba y vuelve a caer con menos altura (damped).
        double y;
        double scale;
        double rotate;
        double opacity;

        if (t <= _fallEnd) {
          final fallT = t / _fallEnd;
          y = -300 * Curves.easeInCubic.transform(fallT);
          scale = 1.0 + fallT * 0.08;
          rotate = (fallT - 0.5) * 0.4;
          opacity = 1.0;
        } else if (t <= _reboundEnd) {
          final bounceT = (t - _fallEnd) / (_reboundEnd - _fallEnd);
          // Rebote: sube y baja con altura decreciente (oscilación amortiguada).
          final phase = bounceT * math.pi * 2;
          y = -40 * math.sin(phase) * (1 - bounceT * 0.6);
          scale = 1.08 - bounceT * 0.08;
          rotate = (1 - bounceT) * 0.2 - bounceT * 0.05;
          opacity = 1.0;
        } else {
          final restT = (t - _reboundEnd) / (1 - _reboundEnd);
          // Fade out final.
          opacity = 1.0 - Curves.easeIn.transform(restT);
          y = 0;
          scale = 1.0;
          rotate = -0.05;
        }

        return Center(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Transform.rotate(
                  angle: rotate,
                  child: Transform.scale(
                    scale: scale,
                    child: _StampVisual(
                      accent: _accent,
                      glyph: _glyph,
                      kind: widget.kind,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StampVisual extends StatelessWidget {
  const _StampVisual({
    required this.accent,
    required this.glyph,
    required this.kind,
  });

  final Color accent;
  final String glyph;
  final HankoStampKind kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StampPainter(accent: accent, kind: kind),
      child: SizedBox(
        width: 120,
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                glyph,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(kind),
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(HankoStampKind k) {
    switch (k) {
      case HankoStampKind.replenish:
        return 'STOCK';
      case HankoStampKind.newItem:
        return 'NUEVO';
      case HankoStampKind.celebrate:
        return 'LOGRO';
      case HankoStampKind.streak:
        return 'RACHA';
    }
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({required this.accent, required this.kind});

  final Color accent;
  final HankoStampKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;

    // Halo exterior muy sutil.
    canvas.drawCircle(
      c,
      radius + 4,
      Paint()
        ..color = accent.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Anillo exterior grueso.
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Anillo interior fino.
    canvas.drawCircle(
      c,
      radius - 8,
      Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // "Tinta" irregular: pequeños puntos rotos en el anillo exterior para
    // simular un sello de tinta imperfecto.
    final rng = math.Random(kind.index * 31 + 7);
    final inkPaint = Paint()..color = accent.withValues(alpha: 0.85);
    for (var i = 0; i < 24; i++) {
      final angle = (i / 24) * math.pi * 2 + rng.nextDouble() * 0.05;
      final rJitter = radius + (rng.nextDouble() - 0.5) * 2;
      final p = c + Offset(math.cos(angle) * rJitter, math.sin(angle) * rJitter);
      canvas.drawCircle(p, 1.5 + rng.nextDouble(), inkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) =>
      old.accent != accent || old.kind != kind;
}
