import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../models/recognized_food.dart';
import '../services/object_detection_service.dart';

/// Estado del globo: aún no se analizaron los macros o ya se emparejó con
/// el resultado de Gemini.
enum FoodBalloonState { pending, resolved }

/// Datos de un globo: combina la bounding box de ML Kit con un
/// [RecognizedFood] (cuando Gemini devuelve los macros) o un estado
/// pendiente mientras el backend procesa.
class FoodBalloonData {
  final DetectedFoodObject detected;
  final RecognizedFood? food;
  final FoodBalloonState state;

  const FoodBalloonData({
    required this.detected,
    required this.food,
    required this.state,
  });

  FoodBalloonData copyWith({RecognizedFood? food, FoodBalloonState? state}) {
    return FoodBalloonData(
      detected: detected,
      food: food ?? this.food,
      state: state ?? this.state,
    );
  }

  /// Etiqueta visible: el nombre del alimento o la clase de ML Kit como
  /// fallback mientras Gemini termina.
  String get displayLabel {
    if (state == FoodBalloonState.resolved && food != null) {
      return food!.name;
    }
    return detected.label;
  }
}

/// Overlay de globos flotantes premium sobre la foto capturada.
///
/// A diferencia de [ObjectBoxesOverlay] (que usa `CustomPaint` y es plano),
/// este widget renderiza componentes reales en el árbol de Flutter:
/// cada detección es un [Positioned] clickeable con su globo y macros.
///
/// Las coordenadas de la bounding box vienen en píxeles de la imagen
/// original; se mapean al rectángulo visible aplicando la misma
/// transformación `BoxFit.cover` que el `Image.file` que está debajo.
class FloatingFoodBalloons extends StatefulWidget {
  final List<FoodBalloonData> balloons;
  final double imageNaturalWidth;
  final double imageNaturalHeight;

  /// Callback cuando el usuario toca un globo.
  final void Function(int balloonIndex, FoodBalloonData balloon)? onBalloonTap;

  /// Índice del globo actualmente resaltado.
  final int? highlightedIndex;

  /// Ancho mínimo del globo.
  final double minBalloonWidth;

  /// Ancho máximo del globo.
  final double maxBalloonWidth;

  const FloatingFoodBalloons({
    super.key,
    required this.balloons,
    required this.imageNaturalWidth,
    required this.imageNaturalHeight,
    this.onBalloonTap,
    this.highlightedIndex,
    this.minBalloonWidth = 110,
    this.maxBalloonWidth = 156,
  });

  @override
  State<FloatingFoodBalloons> createState() => _FloatingFoodBalloonsState();
}

class _FloatingFoodBalloonsState extends State<FloatingFoodBalloons>
    with TickerProviderStateMixin {
  final List<AnimationController> _entryControllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
    _runStaggeredEntry();
  }

  @override
  void didUpdateWidget(covariant FloatingFoodBalloons oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLen = oldWidget.balloons.length;
    final newLen = widget.balloons.length;
    if (oldLen != newLen) {
      _syncControllers();
      _runStaggeredEntry();
    } else {
      for (var i = 0; i < newLen; i++) {
        final wasResolved =
            oldWidget.balloons[i].state == FoodBalloonState.resolved;
        final isResolved =
            widget.balloons[i].state == FoodBalloonState.resolved;
        if (!wasResolved && isResolved && i < _entryControllers.length) {
          _entryControllers[i]
            ..reset()
            ..forward();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _entryControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    while (_entryControllers.length < widget.balloons.length) {
      _entryControllers.add(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        ),
      );
    }
    while (_entryControllers.length > widget.balloons.length) {
      _entryControllers.removeLast().dispose();
    }
  }

  void _runStaggeredEntry() {
    for (var i = 0; i < _entryControllers.length; i++) {
      final c = _entryControllers[i];
      c.value = 0;
      Future.delayed(Duration(milliseconds: 90 * i), () {
        if (mounted) c.forward();
      });
    }
  }

  // ── Transformación cover (idéntica a ObjectBoxesOverlay) ─────────────
  ({double scale, double offsetX, double offsetY}) _coverTransform(Size size) {
    if (widget.imageNaturalWidth <= 0 || widget.imageNaturalHeight <= 0) {
      return (scale: 1, offsetX: 0, offsetY: 0);
    }
    final scale = (size.width / widget.imageNaturalWidth) <
            (size.height / widget.imageNaturalHeight)
        ? size.height / widget.imageNaturalHeight
        : size.width / widget.imageNaturalWidth;
    final scaledW = widget.imageNaturalWidth * scale;
    final scaledH = widget.imageNaturalHeight * scale;
    return (
      scale: scale,
      offsetX: (size.width - scaledW) / 2,
      offsetY: (size.height - scaledH) / 2,
    );
  }

  Color _colorFor(FoodBalloonData b) {
    if (b.food != null && b.food!.pantryItemId != null) {
      return context.nk.cat;
    }
    if (b.food != null) {
      final p = b.food!.proteins;
      final c = b.food!.carbs;
      final f = b.food!.fats;
      final maxVal = math.max(p, math.max(c, f));
      if (maxVal == p) return context.nk.protein;
      if (maxVal == c) return context.nk.carbs;
      return context.nk.fat;
    }
    return context.nk.textDim;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.balloons.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final t = _coverTransform(viewport);

        // Posiciones calculadas por globo. `null` significa "fuera de
        // pantalla" (el bbox quedó recortado por el cover).
        final placements = <_BalloonPlacement?>[];
        for (var i = 0; i < widget.balloons.length; i++) {
          final b = widget.balloons[i];
          final raw = b.detected.boundingBox;
          final visible = Rect.fromLTRB(
            raw.left * t.scale + t.offsetX,
            raw.top * t.scale + t.offsetY,
            raw.right * t.scale + t.offsetX,
            raw.bottom * t.scale + t.offsetY,
          ).intersect(Offset.zero & viewport);
          if (visible.width < 24 || visible.height < 24) {
            placements.add(null);
            continue;
          }

          // Globo de tamaño fijo para que el cálculo del layout sea estable.
          final bw = math.min(
            widget.maxBalloonWidth,
            math.max(widget.minBalloonWidth, visible.width * 1.15),
          );
          const bh = 56.0;
          const pointerLen = 16.0;

          final anchor = Offset(visible.center.dx, visible.top);
          final spaceAbove = anchor.dy;
          final placeAbove = spaceAbove > bh + pointerLen + 6;
          final balloonCenterY = placeAbove
              ? anchor.dy - pointerLen - bh / 2
              : anchor.dy + pointerLen + bh / 2;

          var left = anchor.dx - bw / 2;
          left = left.clamp(8.0, math.max(8.0, viewport.width - bw - 8));

          placements.add(_BalloonPlacement(
            anchor: anchor,
            balloonRect: Rect.fromLTWH(
              left,
              balloonCenterY - bh / 2,
              bw,
              bh,
            ),
            placeAbove: placeAbove,
            color: _colorFor(b),
          ));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1) Halo sutil de las bboxes
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BboxHaloPainter(
                    balloons: widget.balloons,
                    transform: t,
                    placements: placements,
                    highlightedIndex: widget.highlightedIndex,
                    colorFor: _colorFor,
                  ),
                ),
              ),
            ),
            // 2) Globos clickeables
            for (var i = 0; i < widget.balloons.length; i++)
              if (placements[i] != null)
                _buildBalloonWidget(i, placements[i]!),
          ],
        );
      },
    );
  }

  Widget _buildBalloonWidget(int index, _BalloonPlacement p) {
    final b = widget.balloons[index];
    final entryAnim = _entryControllers[index];
    return AnimatedBuilder(
      animation: entryAnim,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(entryAnim.value);
        final dir = p.placeAbove ? -1.0 : 1.0;
        return Opacity(
          opacity: entryAnim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10 * dir),
            child: Transform.scale(
              scale: 0.6 + 0.4 * t,
              child: child,
            ),
          ),
        );
      },
      child: Positioned(
        left: p.balloonRect.left,
        top: p.balloonRect.top,
        width: p.balloonRect.width,
        height: p.balloonRect.height,
        child: _BalloonWithPointer(
          data: b,
          color: p.color,
          placement: p,
          highlighted: widget.highlightedIndex == index,
          onTap: () => widget.onBalloonTap?.call(index, b),
        ),
      ),
    );
  }
}

class _BalloonPlacement {
  final Offset anchor;
  final Rect balloonRect;
  final bool placeAbove;
  final Color color;

  const _BalloonPlacement({
    required this.anchor,
    required this.balloonRect,
    required this.placeAbove,
    required this.color,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Globo con línea apuntadora (la línea se pinta en coords del padre)
// ═════════════════════════════════════════════════════════════════════════════

class _BalloonWithPointer extends StatefulWidget {
  final FoodBalloonData data;
  final Color color;
  final _BalloonPlacement placement;
  final bool highlighted;
  final VoidCallback onTap;

  const _BalloonWithPointer({
    required this.data,
    required this.color,
    required this.placement,
    required this.highlighted,
    required this.onTap,
  });

  @override
  State<_BalloonWithPointer> createState() => _BalloonWithPointerState();
}

class _BalloonWithPointerState extends State<_BalloonWithPointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.highlighted ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _BalloonWithPointer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted != oldWidget.highlighted) {
      widget.highlighted ? _highlight.forward() : _highlight.reverse();
    }
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.data.state == FoodBalloonState.pending;
    // El balloon está dentro de un Positioned de tamaño exacto.
    // El anchor está en coords del Stack padre, no del balloon.
    // Lo pintamos como un CustomPaint fuera de la geometría del balloon.
    final balloonRect = widget.placement.balloonRect;
    final anchor = widget.placement.anchor;

    return AnimatedBuilder(
      animation: _highlight,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Globo visual
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: AnimatedScale(
                  scale: widget.highlighted ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _BalloonVisual(
                    data: widget.data,
                    color: widget.color,
                    highlighted: widget.highlighted,
                    isPending: isPending,
                  ),
                ),
              ),
            ),
            // Línea apuntadora — la dibujamos en coords del balloon,
            // calculando el offset al anchor.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PointerPainter(
                    balloonRect: balloonRect,
                    anchor: anchor,
                    color: widget.color,
                    placeAbove: widget.placement.placeAbove,
                    highlight: _highlight.value,
                    isPending: isPending,
                  ),
                ),
              ),
            ),
            // Punto en el anchor (encima de la imagen)
            Positioned(
              left: anchor.dx - balloonRect.left - 3,
              top: anchor.dy - balloonRect.top - 3,
              width: 6,
              height: 6,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // El "1" no se usa: clipBehavior none permite que el punto
            // se salga del balloon widget.
          ],
        );
      },
    );
  }
}

class _PointerPainter extends CustomPainter {
  final Rect balloonRect; // coords del padre (viewport)
  final Offset anchor; // coords del padre (viewport)
  final Color color;
  final bool placeAbove;
  final double highlight;
  final bool isPending;

  _PointerPainter({
    required this.balloonRect,
    required this.anchor,
    required this.color,
    required this.placeAbove,
    required this.highlight,
    required this.isPending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // El CustomPaint tiene el tamaño del balloon widget.
    // Necesitamos dibujar una línea desde el balloon (en coords locales)
    // hasta el anchor (en coords del padre). Para eso convertimos todo
    // a coords locales del balloon:
    final localAnchor = anchor - balloonRect.topLeft;
    final localBalloonCenter = Offset(
      balloonRect.width / 2,
      placeAbove ? balloonRect.height : 0,
    );

    // Línea vertical principal
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.55 + 0.35 * highlight)
      ..strokeWidth = 1.2 + highlight * 0.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(localBalloonCenter, localAnchor, linePaint);

    // Puntilla tipo "cabeza de flecha" en el balloon
    final tipY = placeAbove ? balloonRect.height : 0.0;
    final tip = Path()
      ..moveTo(balloonRect.width / 2 - 4, tipY)
      ..lineTo(balloonRect.width / 2, tipY + (placeAbove ? 4 : -4))
      ..lineTo(balloonRect.width / 2 + 4, tipY)
      ..close();
    canvas.drawPath(
      tip,
      Paint()..color = color.withValues(alpha: 0.75 + 0.25 * highlight),
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) =>
      old.anchor != anchor ||
      old.balloonRect != balloonRect ||
      old.color != color ||
      old.placeAbove != placeAbove ||
      old.highlight != highlight ||
      old.isPending != isPending;
}

// ═════════════════════════════════════════════════════════════════════════════
// Globo visual (píldora)
// ═════════════════════════════════════════════════════════════════════════════

class _BalloonVisual extends StatelessWidget {
  final FoodBalloonData data;
  final Color color;
  final bool highlighted;
  final bool isPending;

  const _BalloonVisual({
    required this.data,
    required this.color,
    required this.highlighted,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = data.food?.calories ?? 0;
    final p = data.food?.proteins ?? 0;
    final c = data.food?.carbs ?? 0;
    final f = data.food?.fats ?? 0;
    final grams = data.food?.estimatedGrams ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: context.nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: highlighted ? 1.0 : 0.5),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: highlighted ? 0.30 : 0.14),
            blurRadius: highlighted ? 18 : 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.nk.text.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // Banda lateral coloreada (identidad de macro)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(color: color),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Fila 1: dot de estado + nombre
                  Row(
                    children: [
                      if (isPending)
                        SizedBox(
                          width: 9,
                          height: 9,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      else
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data.displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: context.nk.text,
                            letterSpacing: -0.1,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Fila 2: kcal prominente + gramos
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isPending ? '···' : kcal.toStringAsFixed(0),
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(width: 2),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: context.nk.textFaint,
                          letterSpacing: 0.4,
                          height: 1.0,
                        ),
                      ),
                      if (data.food != null) ...[
                        SizedBox(width: 6),
                        Container(
                          width: 1.5,
                          height: 9,
                          color: context.nk.border,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${grams.toStringAsFixed(0)}g',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: context.nk.textFaint,
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Fila 3: micro-macros (solo si resuelto)
                  if (data.food != null) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        _miniMacro(context, 'P', p, context.nk.protein),
                        SizedBox(width: 6),
                        _miniMacro(context, 'C', c, context.nk.carbs),
                        SizedBox(width: 6),
                        _miniMacro(context, 'G', f, context.nk.fat),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Brillo superior sutil (glass-morphism)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMacro(BuildContext context, String letter, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          letter,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.0,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(width: 2),
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: context.nk.textDim,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Halo sutil de las bboxes
// ═════════════════════════════════════════════════════════════════════════════

class _BboxHaloPainter extends CustomPainter {
  final List<FoodBalloonData> balloons;
  final ({double scale, double offsetX, double offsetY}) transform;
  final List<_BalloonPlacement?> placements;
  final int? highlightedIndex;
  final Color Function(FoodBalloonData) colorFor;

  _BboxHaloPainter({
    required this.balloons,
    required this.transform,
    required this.placements,
    required this.highlightedIndex,
    required this.colorFor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < balloons.length; i++) {
      if (placements[i] == null) continue;
      final b = balloons[i];
      final raw = b.detected.boundingBox;
      final r = Rect.fromLTRB(
        raw.left * transform.scale + transform.offsetX,
        raw.top * transform.scale + transform.offsetY,
        raw.right * transform.scale + transform.offsetX,
        raw.bottom * transform.scale + transform.offsetY,
      ).intersect(Offset.zero & size);
      if (r.width < 4 || r.height < 4) continue;

      final color = colorFor(b);
      final isHighlighted = highlightedIndex == i;
      final fillAlpha = isHighlighted ? 0.10 : 0.04;

      // Relleno translúcido
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()
          ..color = color.withValues(alpha: fillAlpha)
          ..style = PaintingStyle.fill,
      );

      // Esquinas tipo brackets si está resaltado
      if (isHighlighted) {
        final cornerPaint = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        const len = 8.0;
        final tl = r.topLeft;
        final tr = r.topRight;
        final bl = r.bottomLeft;
        final br = r.bottomRight;
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
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BboxHaloPainter old) =>
      old.balloons != balloons ||
      old.transform.scale != transform.scale ||
      old.transform.offsetX != transform.offsetX ||
      old.transform.offsetY != transform.offsetY ||
      old.highlightedIndex != highlightedIndex ||
      old.placements != placements;
}
