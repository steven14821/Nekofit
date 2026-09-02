import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/neko_palette.dart';

/// Variantes de la burbuja de diálogo manga de NekoFit.
/// Reemplazan los `SnackBar` genéricos: cada interacción importante del usuario
/// merece un mensaje con personalidad.
enum BubbleVariant {
  /// Jagged/sharp — alerta sarcástica ("te excediste", macro fuera de rango).
  jagged,

  /// Nube redonda — pensando/analizando (escaneando, generando plan).
  cloud,

  /// Con corazón — músculo feliz (meta cumplida, racha, nivel).
  heart,
}

/// Burbuja de diálogo manga reutilizable.
///
/// Se usa desde `NekoAlert.show()` (reemplazo de SnackBar) o como widget
/// suelto en tours y sheets de la mascota.
class NekoSpeechBubble extends StatelessWidget {
  const NekoSpeechBubble({
    super.key,
    required this.message,
    this.variant = BubbleVariant.cloud,
    this.tailAlignment = BubbleTail.right,
    this.tailSize = 14,
    this.color,
    this.textColor,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.maxWidth = 320,
  });

  final String message;
  final BubbleVariant variant;
  final BubbleTail tailAlignment;
  final double tailSize;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final accent = _accentFor(nk, variant);
    final bg = color ?? nk.surface;
    final fg = textColor ?? nk.text;

    final tailSide = _TailSide(tailAlignment);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CustomPaint(
        painter: _BubblePainter(
          color: bg,
          borderColor: accent,
          variant: variant,
          tailSide: tailSide,
          tailSize: tailSize,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    height: 1.35,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentFor(NekoColors nk, BubbleVariant v) {
    switch (v) {
      case BubbleVariant.jagged:
        return nk.danger;
      case BubbleVariant.cloud:
        return nk.amber;
      case BubbleVariant.heart:
        return nk.cat;
    }
  }
}

enum BubbleTail { left, right, bottom, none }

class _TailSide {
  final BubbleTail tail;
  const _TailSide(this.tail);
}

/// CustomPainter que dibuja la silueta de la burbuja + cola + decoraciones
/// específicas (jagged irregular / nube con bumps / corazón).
class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.color,
    required this.borderColor,
    required this.variant,
    required this.tailSide,
    required this.tailSize,
  });

  final Color color;
  final Color borderColor;
  final BubbleVariant variant;
  final _TailSide tailSide;
  final double tailSize;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(18);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    switch (variant) {
      case BubbleVariant.jagged:
        _drawJagged(canvas, size, fillPaint, strokePaint, radius);
        break;
      case BubbleVariant.cloud:
        _drawCloud(canvas, size, fillPaint, strokePaint, radius);
        break;
      case BubbleVariant.heart:
        _drawHeart(canvas, size, fillPaint, strokePaint);
        break;
    }
  }

  // ── Jagged: borde irregular tipo explosión sarcástica ───────────────────
  void _drawJagged(Canvas canvas, Size size, Paint fill, Paint stroke, Radius r) {
    final path = _buildJaggedPath(size, r, spikes: 14, depth: 4.0);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  Path _buildJaggedPath(Size size, Radius r, {required int spikes, required double depth}) {
    final rect = Offset.zero & size;
    final path = Path();
    final step = (size.width + size.height * 2) / spikes;
    final rnd = math.Random(42); // semilla estable: misma forma cada vez

    path.moveTo(rect.left + r.x, rect.top);
    var i = 0;
    while (i < spikes) {
      final t = (i * step) / (rect.width + rect.height * 2);
      Offset point;
      final nextT = ((i + 1) * step) / (rect.width + rect.height * 2);
      // Recorrer el rectángulo como si fuera una línea continua.
      if (t < (size.width / (size.width + size.height * 2))) {
        final x = rect.left + t * (size.width + size.height * 2);
        point = Offset(x, rect.top);
        final nextX = rect.left + nextT * (size.width + size.height * 2);
        final mid = Offset(
          (x + nextX) / 2 + (rnd.nextDouble() - 0.5) * depth * 2,
          rect.top + (rnd.nextDouble() - 0.5) * depth * 2 - depth,
        );
        path.lineTo(mid.dx, mid.dy);
      } else if (t < ((size.width + size.height) / (size.width + size.height * 2))) {
        final y = rect.top + (t * (size.width + size.height * 2) - size.width);
        point = Offset(rect.right, y);
        final nextY = rect.top + (nextT * (size.width + size.height * 2) - size.width);
        final mid = Offset(
          rect.right + (rnd.nextDouble() - 0.5) * depth * 2 + depth,
          (y + nextY) / 2 + (rnd.nextDouble() - 0.5) * depth * 2,
        );
        path.lineTo(mid.dx, mid.dy);
      } else if (t < ((size.width * 2 + size.height) / (size.width + size.height * 2))) {
        final x = rect.right - (t * (size.width + size.height * 2) - size.width - size.height);
        point = Offset(x, rect.bottom);
        final nextX = rect.right - (nextT * (size.width + size.height * 2) - size.width - size.height);
        final mid = Offset(
          (x + nextX) / 2 + (rnd.nextDouble() - 0.5) * depth * 2,
          rect.bottom + (rnd.nextDouble() - 0.5) * depth * 2 + depth,
        );
        path.lineTo(mid.dx, mid.dy);
      } else {
        final y = rect.bottom - (t * (size.width + size.height * 2) - size.width * 2 - size.height);
        point = Offset(rect.left, y);
        final nextY = rect.bottom - (nextT * (size.width + size.height * 2) - size.width * 2 - size.height);
        final mid = Offset(
          rect.left + (rnd.nextDouble() - 0.5) * depth * 2 - depth,
          (y + nextY) / 2 + (rnd.nextDouble() - 0.5) * depth * 2,
        );
        path.lineTo(mid.dx, mid.dy);
      }
      path.lineTo(point.dx, point.dy);
      i++;
    }
    path.close();
    return path;
  }

  // ── Cloud: burbuja con bumps irregulares (pensando) ─────────────────────
  void _drawCloud(Canvas canvas, Size size, Paint fill, Paint stroke, Radius r) {
    final path = Path();
    const bumps = 18;
    final rnd = math.Random(7);
    for (var i = 0; i <= bumps * 4; i++) {
      final t = i / (bumps * 4);
      final angle = t * math.pi * 2;
      // Elongación irregular: hace que la nube "respire".
      final wobble = 1 + (rnd.nextDouble() - 0.5) * 0.06;
      final cx = size.width / 2 + math.cos(angle) * size.width / 2 * wobble;
      final cy = size.height / 2 + math.sin(angle) * size.height / 2 * wobble;
      if (i == 0) {
        path.moveTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  // ── Heart: esquinas redondeadas grandes + un pequeño corazón abajo a la izq ─
  void _drawHeart(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, stroke);

    // Mini corazón decorativo en la esquina inferior izquierda
    final heartCenter = Offset(14, size.height - 14);
    final heartPath = Path()
      ..moveTo(heartCenter.dx, heartCenter.dy + 4)
      ..cubicTo(
        heartCenter.dx - 6, heartCenter.dy - 2,
        heartCenter.dx - 6, heartCenter.dy - 8,
        heartCenter.dx, heartCenter.dy - 4,
      )
      ..cubicTo(
        heartCenter.dx + 6, heartCenter.dy - 8,
        heartCenter.dx + 6, heartCenter.dy - 2,
        heartCenter.dx, heartCenter.dy + 4,
      )
      ..close();
    canvas.drawPath(heartPath, Paint()..color = borderColor.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.variant != variant;
}
