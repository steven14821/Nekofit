import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

import '../core/haptics.dart';
import '../core/neko_palette.dart';
import 'neko_cat_mascot.dart';
import 'neko_speech_bubble.dart';

/// Paso del tour: spotlight sobre una zona + burbuja de diálogo + mascota.
class NekoTourStep {
  const NekoTourStep({
    required this.message,
    this.targetKey,
    this.padding = const EdgeInsets.all(8),
    this.bubbleVariant = BubbleVariant.cloud,
    this.bubbleAlignment = NekoTourAlignment.bottomRight,
    this.icon,
    this.title,
  });

  /// Texto principal del paso.
  final String message;

  /// Opcional: clave global del widget que se quiere iluminar (spotlight).
  /// Si es null, el tour ocupa toda la pantalla sin spotlight.
  final GlobalKey? targetKey;

  /// Padding alrededor del target para el spotlight.
  final EdgeInsets padding;

  /// Variante de la burbuja manga.
  final BubbleVariant bubbleVariant;

  /// Dónde se coloca la burbuja respecto al spotlight.
  final NekoTourAlignment bubbleAlignment;

  /// Icono opcional junto al texto.
  final IconData? icon;

  /// Título en mayúsculas (eyebrow) sobre el mensaje.
  final String? title;
}

enum NekoTourAlignment { topLeft, topRight, bottomLeft, bottomRight, center }

/// Helper estático para lanzar tours contextuales. Se persiste por
/// (usuario, tourId) en SharedPreferences para no repetirlos.
class NekoTour {
  NekoTour._();

  /// Lanza el tour sobre [context] si el usuario no lo completó antes.
  /// Si [force] es true, ignora el flag de "ya visto".
  /// Entradas de overlay activas, para garantizar UN solo tour a la vez.
  static final List<OverlayEntry> _activeEntries = [];

  /// Cierra la carrera entre dos llamadas concurrentes a [show].
  static bool _busy = false;

  static Future<void> show({
    required BuildContext context,
    required String tourId,
    required List<NekoTourStep> steps,
    bool force = false,
  }) async {
    // Un solo tour activo a la vez: evita dobles lanzamientos cuando dos
    // instancias de una pantalla compiten por mostrarlo (p. ej. la pestaña
    // del Diario viva en el Offstage + un push desde Estadísticas).
    if (_busy || _activeEntries.isNotEmpty) return;
    _busy = true;
    try {
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('tour_$tourId') == true) return;
      }
      if (!context.mounted) return;

      final overlay = Overlay.of(context, rootOverlay: true);
      OverlayEntry? entry;

      final controller = _NekoTourController(
        steps: steps,
        onFinish: () async {
          _removeEntry(entry);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('tour_$tourId', true);
        },
      );

      entry = OverlayEntry(
        builder: (_) => _NekoTourHost(
          controller: controller,
          onDismiss: () {
            controller.skip();
            _removeEntry(entry);
            SharedPreferences.getInstance().then(
              (p) => p.setBool('tour_$tourId', true),
            );
          },
        ),
      );
      _activeEntries.add(entry);
      overlay.insert(entry);
      controller.start();
    } finally {
      _busy = false;
    }
  }

  static void _removeEntry(OverlayEntry? entry) {
    if (entry == null || !entry.mounted) return;
    entry.remove();
    _activeEntries.remove(entry);
  }

  /// Descarta cualquier tour activo. Lo usa la pantalla anfitriona al
  /// destruirse (p. ej. back a mitad del tour): si no, el overlay quedaría
  /// flotando y un nuevo tour se apilaría encima al reentrar.
  static void dismissAll() {
    for (final e in _activeEntries) {
      if (e.mounted) e.remove();
    }
    _activeEntries.clear();
  }

  /// Resetea todos los tours (útil desde una pantalla de debug).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      if (k.startsWith('tour_')) prefs.remove(k);
    }
  }
}

class _NekoTourController {
  _NekoTourController({required this.steps, required this.onFinish});

  final List<NekoTourStep> steps;
  final VoidCallback onFinish;

  int _index = -1;
  final ValueNotifier<int> index$ = ValueNotifier(0);

  void start() {
    Haptics.tap();
    _index = 0;
    index$.value = 0;
  }

  void next() {
    if (_index < steps.length - 1) {
      Haptics.select();
      _index++;
      index$.value = _index;
    } else {
      Haptics.success();
      onFinish();
    }
  }

  void skip() {
    onFinish();
  }
}

class _NekoTourHost extends StatelessWidget {
  const _NekoTourHost({required this.controller, required this.onDismiss});

  final _NekoTourController controller;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.index$,
      builder: (context, idx, _) {
        if (idx >= controller.steps.length) {
          return const SizedBox.shrink();
        }
        final step = controller.steps[idx];
        return _NekoTourStepLayer(
          step: step,
          stepIndex: idx,
          totalSteps: controller.steps.length,
          onNext: controller.next,
          onDismiss: onDismiss,
        );
      },
    );
  }
}

class _NekoTourStepLayer extends StatefulWidget {
  const _NekoTourStepLayer({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onDismiss,
  });

  final NekoTourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onDismiss;

  @override
  State<_NekoTourStepLayer> createState() => _NekoTourStepLayerState();
}

class _NekoTourStepLayerState extends State<_NekoTourStepLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _NekoTourStepLayer old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Rect? _resolveTarget() {
    final key = widget.step.targetKey;
    if (key == null) return null;
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      return topLeft & renderObject.size;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final mediaSize = MediaQuery.of(context).size;
    final target = _resolveTarget();

    return FadeTransition(
      opacity: _ctrl,
      child: Stack(
        children: [
          // 1) Capa oscura con hueco (spotlight). Más suave en claro.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  target: target,
                  padding: widget.step.padding,
                  overlayColor: Colors.black
                      .withValues(alpha: isDark ? 0.72 : 0.50),
                ),
              ),
            ),
          ),

          // 2) Mascota en esquina inferior derecha (siempre visible durante el tour).
          Positioned(
            right: 12,
            bottom: 28 + mediaSize.height * 0.18,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
              ),
              child: const NekoCatMascot(
                mood: CatMood.idle,
                size: 96,
                showLabel: false,
              ),
            ),
          ),

          // 3) Burbuja de diálogo + controles.
          _buildBubbleLayer(mediaSize, target),
        ],
      ),
    );
  }

  Widget _buildBubbleLayer(Size mediaSize, Rect? target) {
    final step = widget.step;

    // Posición base de la burbuja según alignment.
    Offset bubbleOrigin;
    EdgeInsets margin = const EdgeInsets.all(20);

    switch (step.bubbleAlignment) {
      case NekoTourAlignment.topLeft:
        bubbleOrigin = const Offset(20, 80);
        break;
      case NekoTourAlignment.topRight:
        bubbleOrigin = Offset(mediaSize.width - 20, 80);
        margin = const EdgeInsets.only(right: 20);
        break;
      case NekoTourAlignment.bottomLeft:
        bubbleOrigin = Offset(20, mediaSize.height - 240);
        break;
      case NekoTourAlignment.bottomRight:
        bubbleOrigin = Offset(mediaSize.width - 20, mediaSize.height - 240);
        margin = const EdgeInsets.only(right: 20);
        break;
      case NekoTourAlignment.center:
        bubbleOrigin = Offset(mediaSize.width / 2, mediaSize.height / 2);
        break;
    }

    return Positioned(
      left: bubbleOrigin.dx,
      top: bubbleOrigin.dy,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: margin,
        child: Align(
          alignment: _alignmentFor(step.bubbleAlignment),
          child: _buildBubbleCard(step),
        ),
      ),
    );
  }

  Widget _buildBubbleCard(NekoTourStep step) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final accent = _accentFor(nk, step.bubbleVariant);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: nk.border),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0x66191918),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (step.title != null) ...[
            Text(
              step.title!.toUpperCase(),
              style: _mono(
                size: 10,
                weight: FontWeight.w700,
                color: accent,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step.icon != null) ...[
                Icon(step.icon, size: 18, color: accent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  step.message,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    height: 1.45,
                    color: nk.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${widget.stepIndex + 1} / ${widget.totalSteps}',
                style: _mono(
                  size: 11,
                  color: nk.textDim,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: nk.textDim,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Saltar'),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: nk.amber,
                  foregroundColor:
                      isDark ? const Color(0xFF1A1206) : Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: Text(
                  widget.stepIndex == widget.totalSteps - 1 ? 'Listo' : 'Siguiente',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Alignment _alignmentFor(NekoTourAlignment a) {
    switch (a) {
      case NekoTourAlignment.topLeft:
        return Alignment.topLeft;
      case NekoTourAlignment.topRight:
        return Alignment.topRight;
      case NekoTourAlignment.bottomLeft:
        return Alignment.bottomLeft;
      case NekoTourAlignment.bottomRight:
        return Alignment.bottomRight;
      case NekoTourAlignment.center:
        return Alignment.center;
    }
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

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.padding,
    required this.overlayColor,
  });

  final Rect? target;
  final EdgeInsets padding;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = overlayColor;
    if (target == null) {
      canvas.drawRect(Offset.zero & size, overlay);
      return;
    }
    final t = target!.inflate(padding.top);
    final spot = RRect.fromRectAndRadius(t, const Radius.circular(16));
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(spot)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      overlay,
    );

    // Borde fino neutro (blanco 20%): delimita el hueco sin acento de color.
    canvas.drawRRect(
      spot,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.target != target || old.padding != padding || old.overlayColor != overlayColor;
}

// ═══════════════════════════════════════════════════════════════════════════
// Tipografía Noche Ámbar
// ═══════════════════════════════════════════════════════════════════════════
TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color color = const Color(0xFF6B6459),
  double letterSpacing = 0,
  double? height,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
