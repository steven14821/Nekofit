import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/object_detection_service.dart';

/// Overlay de reconocimiento de objetos: dibuja los bounding boxes de los
/// alimentos detectados sobre una imagen mostrada con `BoxFit.cover`.
///
/// Los rects vienen en píxeles de la imagen original; este widget calcula
/// la transformación cover para dibujarlos exactamente sobre el objeto.
class ObjectBoxesOverlay extends StatelessWidget {
  final List<DetectedFoodObject> objects;
  final double imageWidth;
  final double imageHeight;

  const ObjectBoxesOverlay({
    super.key,
    required this.objects,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (objects.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _BoxPainter(objects, imageWidth, imageHeight),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final List<DetectedFoodObject> objects;
  final double imageWidth;
  final double imageHeight;

  _BoxPainter(this.objects, this.imageWidth, this.imageHeight);

  // Paleta para diferenciar cada objeto detectado.
  static const List<Color> _palette = [
    AppColors.cat,
    AppColors.catProteins,
    AppColors.catCarbs,
    AppColors.catVeg,
    AppColors.catDairy,
    AppColors.accent,
  ];

  ({double scale, double offsetX, double offsetY}) _coverTransform(Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      return (scale: 1, offsetX: 0, offsetY: 0);
    }
    final scale = (size.width / imageWidth) < (size.height / imageHeight)
        ? size.height / imageHeight
        : size.width / imageWidth;
    final scaledW = imageWidth * scale;
    final scaledH = imageHeight * scale;
    return (
      scale: scale,
      offsetX: (size.width - scaledW) / 2,
      offsetY: (size.height - scaledH) / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = _coverTransform(size);
    for (final obj in objects) {
      final r = obj.boundingBox;
      final rect = Rect.fromLTRB(
        r.left * t.scale + t.offsetX,
        r.top * t.scale + t.offsetY,
        r.right * t.scale + t.offsetX,
        r.bottom * t.scale + t.offsetY,
      ).intersect(Offset.zero & size);

      if (rect.width < 4 || rect.height < 4) continue;

      final color = _palette[obj.index % _palette.length];
      _drawBox(canvas, rect, color, obj);
    }
  }

  void _drawBox(Canvas canvas, Rect rect, Color color, DetectedFoodObject obj) {
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Relleno translúcido
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );

    // Borde
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)),
      borderPaint,
    );

    // Esquinas tipo brackets
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final len = 10.0;
    final tl = rect.topLeft;
    final tr = rect.topRight;
    final bl = rect.bottomLeft;
    final br = rect.bottomRight;

    canvas.drawPath(
      Path()
        ..moveTo(tl.dx, tl.dy + len)
        ..lineTo(tl.dx, tl.dy)
        ..lineTo(tl.dx + len, tl.dy),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tr.dx - len, tr.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(tr.dx, tr.dy + len),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(bl.dx, bl.dy - len)
        ..lineTo(bl.dx, bl.dy)
        ..lineTo(bl.dx + len, bl.dy),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(br.dx - len, br.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(br.dx, br.dy - len),
      cornerPaint,
    );

    // Etiqueta: nombre + confianza
    final confidence = (obj.confidence * 100).clamp(0, 100).round();
    final labelText = '${obj.label}  $confidence%';
    final tp = TextPainter(
      text: TextSpan(
        text: labelText.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padX = 8.0;
    const padY = 4.0;
    final chipW = tp.width + padX * 2;
    final chipH = tp.height + padY * 2;

    // Si la caja llega al borde superior, dibujamos la etiqueta abajo.
    final labelTop = rect.top - chipH - 4 < 0 ? rect.bottom + 4 : rect.top - chipH - 4;
    final chipRect = Rect.fromLTWH(rect.left, labelTop, chipW, chipH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
      Paint()..color = color,
    );
    tp.paint(canvas, chipRect.topLeft + const Offset(padX, padY));
  }

  @override
  bool shouldRepaint(covariant _BoxPainter oldDelegate) =>
      oldDelegate.objects != objects ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight;
}
