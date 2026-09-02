import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Capas atmosféricas de NekoFit. Se compone detrás de cualquier pantalla.
///
/// Incluye:
/// 1. Kanji flotantes verticales (konbini columnar)
/// 2. Ticker horizontal LED de konbini
/// 3. Partículas de "vapor" subiendo
/// 4. Scanlines + grano washi (overlay)
/// 5. "営業中" parpadeante (opcional, en el header)
class AtmosphereBackground extends StatefulWidget {
  const AtmosphereBackground({super.key, this.child, this.showTicker = true});
  final Widget? child;
  final bool showTicker;

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scrollCtrl;
  late final AnimationController _vaporCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _neonCtrl;

  // Kanji decorativos que se mueven lento hacia arriba en columnas.
  static const List<String> _kanjiPool = [
    '在庫', '完売', '棚', '店', '食', '新鮮', '本日',
    'タンパク質', '店長', '推奨', '野菜', '減量', '筋肉',
    'セール', '国産', '安全', '朝どれ', '値引', '特売',
    '棚卸', '入荷', '予約', '配達', '本日限定', '新鮮',
  ];

  // Para el ticker. Los separadores son caracteres de bloque unicode (▪) que
  // se ven consistentes con tipografía monoespaciada, no emojis.
  static const String _tickerText =
      '▪ 営業中 ▪ 在庫あります ▪ 店長おすすめ: タンパク質30g ▪ 今日の特売: 鶏むね肉100g ¥98 ▪ '
      '新鮮野菜入荷 ▪ 減量中のみなさま、店長が見ています ▪ あなたの棚をスキャン中 ▪ '
      'ネコフィットはあなたの味方 ▪ 完売御礼 ▪ ';

  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAnimations();
  }

  void _startAnimations() {
    if (_isPaused) return;
    _scrollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 180),
    )..repeat();
    _vaporCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _neonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  void _pauseAnimations() {
    if (_isPaused) return;
    _isPaused = true;
    _scrollCtrl.stop();
    _vaporCtrl.stop();
    _scanCtrl.stop();
    _neonCtrl.stop();
  }

  void _resumeAnimations() {
    if (!_isPaused) return;
    _isPaused = false;
    _scrollCtrl.repeat();
    _vaporCtrl.repeat();
    _scanCtrl.repeat();
    _neonCtrl.repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseAnimations();
    } else if (state == AppLifecycleState.resumed) {
      _resumeAnimations();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _vaporCtrl.dispose();
    _scanCtrl.dispose();
    _neonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo base con gradiente sutil.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [Color(0xFF1B1538), Color(0xFF0A0716)],
            ),
          ),
        ),

        // 2. Kanji verticales flotando.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _scrollCtrl,
            builder: (_, _) => CustomPaint(
              painter: _KanjiColumnPainter(
                progress: _scrollCtrl.value,
                glyphs: _kanjiPool,
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // 3. Partículas de vapor.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _vaporCtrl,
            builder: (_, _) => CustomPaint(
              painter: _VaporPainter(progress: _vaporCtrl.value),
              size: Size.infinite,
            ),
          ),
        ),

        // 4. Contenido real.
        if (widget.child != null) widget.child!,

        // 5. Ticker inferior (encima del contenido).
        if (widget.showTicker)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _KonbiniTicker(text: _tickerText),
            ),
          ),

        // 6. Scanlines + grano (encima de todo, muy sutil).
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, _) => CustomPaint(
              painter: _ScanlineGrainPainter(progress: _scanCtrl.value),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanji vertical columns
// ─────────────────────────────────────────────────────────────────────────────
class _KanjiColumnPainter extends CustomPainter {
  _KanjiColumnPainter({required this.progress, required this.glyphs});
  final double progress;
  final List<String> glyphs;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    const columnCount = 5;
    final columnWidth = size.width / columnCount;

    final textStyle = GoogleFonts.bagelFatOne(
      textStyle: const TextStyle(
        fontSize: 22,
        color: Color(0xFFFFB347),
        fontWeight: FontWeight.w400,
      ),
    );

    for (var c = 0; c < columnCount; c++) {
      final x = c * columnWidth + columnWidth / 2;
      // Cada columna tiene un offset y velocidad distinta.
      final speedFactor = 0.6 + rng.nextDouble() * 0.8;
      final totalScroll = size.height + 400;
      final yOffset = (progress * totalScroll * speedFactor) % totalScroll;

      for (var i = 0; i < 14; i++) {
        final glyph = glyphs[(c * 7 + i) % glyphs.length];
        final y = i * 80 - yOffset;
        if (y < -40 || y > size.height + 40) continue;
        // Opacidad varía con la posición: se atenúa arriba y abajo.
        final edgeFade = (1 - ((y - 100) / size.height).clamp(0.0, 1.0)) * 0.10;
        final tp = TextPainter(
          text: TextSpan(
            text: glyph,
            style: textStyle.copyWith(
              color: const Color(0xFFFFB347).withValues(alpha: edgeFade),
            ),
          ),
          textDirection: TextDirection.rtl, // vertical-ish feel
        );
        tp.layout();
        // Dibuja rotado -90deg para sensación vertical.
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-math.pi / 2);
        canvas.translate(-tp.width / 2, -tp.height / 2);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KanjiColumnPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Vapor / smoke particles
// ─────────────────────────────────────────────────────────────────────────────
class _VaporPainter extends CustomPainter {
  _VaporPainter({required this.progress});
  final double progress;

  static const _seeds = <_VaporSeed>[
    _VaporSeed(0.08, 0.95, 0.6, 30, 18),
    _VaporSeed(0.22, 0.98, 0.5, 22, 14),
    _VaporSeed(0.40, 0.92, 0.7, 35, 22),
    _VaporSeed(0.55, 0.96, 0.55, 26, 16),
    _VaporSeed(0.72, 0.94, 0.45, 20, 12),
    _VaporSeed(0.88, 0.97, 0.65, 32, 20),
    _VaporSeed(0.15, 0.99, 0.4, 18, 10),
    _VaporSeed(0.65, 0.93, 0.5, 24, 15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _seeds) {
      // La partícula sube: posición y va de abajo (1.0) a arriba (-0.2).
      final t = (progress * s.speed + s.phaseOffset) % 1.0;
      final y = size.height * (1.0 - t);
      final wobble = math.sin(t * math.pi * 2 + s.phaseOffset * 6) * 18;
      final x = size.width * s.xRatio + wobble;
      final radius = s.baseRadius * (0.4 + t * 0.8);
      final alpha = (math.sin(t * math.pi) * 0.08).clamp(0.0, 0.08);

      paint.color = const Color(0xFFFFB347).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VaporPainter old) => old.progress != progress;
}

class _VaporSeed {
  final double xRatio;
  final double phaseOffset;
  final double speed;
  final double baseRadius;
  final double fade;
  const _VaporSeed(this.xRatio, this.phaseOffset, this.speed, this.baseRadius, this.fade);
}

// ─────────────────────────────────────────────────────────────────────────────
// Scanlines + grain
// ─────────────────────────────────────────────────────────────────────────────
class _ScanlineGrainPainter extends CustomPainter {
  _ScanlineGrainPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Scanlines horizontales.
    final linePaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Grano pseudoaleatorio (estático, generado por seed).
    final rng = math.Random(13);
    final grainPaint = Paint();
    for (var i = 0; i < 1200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * 0.05;
      grainPaint.color = Colors.white.withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), grainPaint);
    }
    // (La banda de scan móvil se eliminó: la quietud del konbini no admite
    // franjas de luz recorriendo la pantalla.)
  }

  @override
  bool shouldRepaint(covariant _ScanlineGrainPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticker LED de konbini
// ─────────────────────────────────────────────────────────────────────────────
class _KonbiniTicker extends StatefulWidget {
  const _KonbiniTicker({required this.text});
  final String text;

  @override
  State<_KonbiniTicker> createState() => _KonbiniTickerState();
}

class _KonbiniTickerState extends State<_KonbiniTicker>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollCtrl;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 140),
    )..repeat();
    _ctrl.addListener(_scroll);
  }

  void _scroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final next = (_ctrl.value * max * 1.4) % max;
    _scrollCtrl.jumpTo(next);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_scroll);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0716),
        border: const Border(top: BorderSide(color: AppColors.inStock, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.inStock.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Piloto neón parpadeante
          _BlinkingPilot(controller: _ctrl),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 20,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Text(
                    widget.text,
                    style: GoogleFonts.jetBrainsMono(
                      textStyle: const TextStyle(
                        color: AppColors.cat,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingPilot extends StatelessWidget {
  const _BlinkingPilot({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 28,
      color: const Color(0xFF0A0716),
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            final t = (math.sin(controller.value * math.pi * 4) + 1) / 2;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(const Color(0xFFFF4D8D), const Color(0xFFFF8FB1), t),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inStock.withValues(alpha: 0.5 + t * 0.5),
                    blurRadius: 8 + t * 6,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
