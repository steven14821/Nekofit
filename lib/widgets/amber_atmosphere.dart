import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/neko_palette.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// NEKOFIT — ATMÓSFERA "NOCHE ÁMBAR" (compartida por toda la app)
///
/// El konbini japonés a las 3 AM, quieto por fuera pero vivo por dentro:
///  · Base carbón cálido con barrido de neón ámbar/ember (modo oscuro)
///  · Scanlines sutiles de tienda (solo modo oscuro)
///  · Kanjis de tienda que se deslizan LENTO de arriba hacia abajo — el único
///    movimiento, a propósito: un poco de vida de fondo, sin distraer.
///
/// Modo claro ("lite"): base plana clara, sin gradientes ni scanlines; los
/// kanjis siguen deslizándose pero casi imperceptibles.
///
/// Se coloca DETRÁS del contenido de cada pantalla (primer hijo del Stack).
/// ═══════════════════════════════════════════════════════════════════════════
class AmberAtmosphere extends StatefulWidget {
  const AmberAtmosphere({super.key, this.child, this.density = 0.65});

  /// Contenido real de la pantalla, encima de la atmósfera.
  final Widget? child;

  /// Densidad de los kanjis que se deslizan (0..1). Más alto = más columnas.
  final double density;

  @override
  State<AmberAtmosphere> createState() => _AmberAtmosphereState();
}

class _AmberAtmosphereState extends State<AmberAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftCtrl;

  @override
  void initState() {
    super.initState();
    // Ciclo lento (~2 min) para que la deriva sea casi imperceptible.
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 130),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base — carbón cálido en dark, plano claro en light (lite).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF101014), Color(0xFF0A0A0D)],
                  )
                : null,
            color: isDark ? null : nk.bg,
          ),
        ),

        // 2. Barrido de neón de la máquina expendedora (solo dark).
        if (isDark) ...[
          Positioned(
            top: -80,
            right: -60,
            child: _Glow(size: 340, color: nk.amber.withValues(alpha: 0.10)),
          ),
          Positioned(
            top: 240,
            left: -110,
            child: _Glow(size: 300, color: nk.ember.withValues(alpha: 0.08)),
          ),
        ],

        // 3. Kanjis de tienda deslizándose de arriba hacia abajo.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _driftCtrl,
            builder: (_, _) => CustomPaint(
              painter: _KanjiDriftPainter(
                progress: _driftCtrl.value,
                density: widget.density,
                dark: isDark,
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // 4. Scanlines de tienda (solo dark, muy sutiles).
        if (isDark)
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanlinesPainter()),
            ),
          ),

        // 5. Contenido real.
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glow radial decorativo (barrido de neón de la máquina expendedora)
// ─────────────────────────────────────────────────────────────────────────────
class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanjis con deriva vertical (de arriba hacia abajo)
// ─────────────────────────────────────────────────────────────────────────────
class _KanjiDriftPainter extends CustomPainter {
  _KanjiDriftPainter({
    required this.progress,
    required this.density,
    required this.dark,
  });
  final double progress;
  final double density;
  final bool dark;

  static const List<String> _glyphs = [
    '在庫', '完売', '新鮮', '本日', '店長', '推奨', '減量',
    '特売', '入荷', '予約', '配達', '値引', '棚', '食',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final columnCount = (1 + density * 3).round().clamp(2, 5);
    final columnWidth = size.width / columnCount;
    final totalSpan = size.height + 320;
    const spacing = 96.0;
    // Dark: ámbar tenue. Light ("lite"): casi imperceptible, tinta suave.
    final color = dark
        ? const Color(0xFFF0B429)
        : const Color(0xFF8B8A82);

    for (var c = 0; c < columnCount; c++) {
      final x = c * columnWidth + columnWidth / 2;
      // Cada columna se mueve a su propia velocidad y fase.
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final phase = rng.nextDouble();
      final offset = ((progress * speed + phase) * totalSpan) % totalSpan;
      final alpha = dark ? 0.045 + (c % 3) * 0.02 : 0.030 + (c % 3) * 0.012;

      final tp = TextPainter(
        text: TextSpan(
          text: _glyphs[c % _glyphs.length],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final count = (size.height / spacing).ceil() + 2;
      for (var i = 0; i < count; i++) {
        // `y` crece con `offset` → los kanjis se deslizan hacia ABAJO
        // y reaparecen arriba al pasar el borde inferior.
        final y = (i * spacing + offset) % totalSpan - 100;
        if (y < -60 || y > size.height + 40) continue;

        final glyph = _glyphs[(c * 5 + i) % _glyphs.length];
        tp.text = TextSpan(
          text: glyph,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: alpha),
          ),
        );
        tp.layout();
        canvas.save();
        canvas.translate(x - tp.width / 2, y);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KanjiDriftPainter old) =>
      old.progress != progress || old.density != density || old.dark != dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scanlines sutiles de tienda — líneas horizontales cada 3px
// ─────────────────────────────────────────────────────────────────────────────
class _ScanlinesPainter extends CustomPainter {
  const _ScanlinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
