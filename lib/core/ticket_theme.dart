import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// NEKOFIT — DESIGN SYSTEM "THERMAL TICKET"
/// Konbini japonés a las 3 AM, visto desde el recibo que te dan en la caja.
///
/// Reglas del sistema:
///  · Papel crudo, tinta negra, sello rojo. Nada de gradientes de moda.
///  · Radios casi nulos (2–6px): el papel no tiene esquinas redondeadas.
///  · Sombra dura y desplazada (sin blur): el ticket está APOYADO, no flotando.
///  · Tipografía monoespaciada para todo dato numérico. Sans solo para prosa.
///  · Jerarquía por peso, caja alta y tracking, no por color.
///
/// Coloca este archivo en: lib/core/ticket_theme.dart
/// ════════════════════════════════════════════════════════════════════════════

// ── COLOR ───────────────────────────────────────────────────────────────────
abstract class TicketColors {
  /// Papel térmico recién impreso.
  static const paper = Color(0xFFF5F0E6);

  /// Papel en sombra / zonas rebajadas.
  static const paperDeep = Color(0xFFE3DCCB);

  /// Papel aún más apagado (placeholders, rieles de progreso).
  static const paperDim = Color(0xFFD6CDB8);

  /// Tinta principal.
  static const ink = Color(0xFF1A1A1A);
  static const inkSoft = Color(0xFF4A463E);
  static const inkMuted = Color(0xFF7C766A);
  static const inkFaint = Color(0xFFA9A294);

  /// Sello del konbini. Se usa con avaricia: acento, alerta y firma de marca.
  static const stamp = Color(0xFFD7263D);
  static const stampDeep = Color(0xFF9E1727);

  // Macros — tintas de sello secundarias, todas legibles sobre papel.
  static const protein = Color(0xFFB03A2E);
  static const carbs = Color(0xFFB07D2B);
  static const fats = Color(0xFF7A6A2F);
  static const veg = Color(0xFF3E6B4F);

  // Semánticos de inventario.
  static const inStock = Color(0xFF3E6B4F);
  static const depleted = Color(0xFFD7263D);
  static const warn = Color(0xFFB07D2B);
}

// ── ESPACIADO / RADIOS ──────────────────────────────────────────────────────
abstract class TicketSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 40.0;
}

abstract class TicketRadii {
  static const paper = 4.0;
  static const chip = 2.0;
  static const stamp = 999.0;
}

// ── TIPOGRAFÍA ──────────────────────────────────────────────────────────────
/// Familias del sistema. Si tu `theme.dart` ya declara `AppFonts`, puedes
/// apuntar estas constantes a las tuyas; los nombres aquí son los recomendados.
///
/// pubspec.yaml sugerido:
///   fonts:
///     - family: JetBrainsMono   (Regular/Bold)  → datos, etiquetas, importes
///     - family: WorkSans        (Regular/Medium/SemiBold) → prosa del gato
abstract class TicketFonts {
  static const mono = 'JetBrainsMono';
  static const sans = 'WorkSans';
}

abstract class TicketType {
  /// Etiqueta de sección: caja alta, tracking amplio, pequeña.
  static const label = TextStyle(
    fontFamily: TicketFonts.mono,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: TicketColors.inkMuted,
  );

  /// Importe / cifra protagonista.
  static const amount = TextStyle(
    fontFamily: TicketFonts.mono,
    fontSize: 22,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: TicketColors.ink,
  );

  static const amountS = TextStyle(
    fontFamily: TicketFonts.mono,
    fontSize: 15,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: TicketColors.ink,
  );

  /// Línea de concepto del ticket.
  static const line = TextStyle(
    fontFamily: TicketFonts.mono,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: TicketColors.inkSoft,
  );

  static const micro = TextStyle(
    fontFamily: TicketFonts.mono,
    fontSize: 9,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: TicketColors.inkMuted,
  );

  /// Titular impreso a golpe de matriz.
  static const headline = TextStyle(
    fontFamily: TicketFonts.mono,
    fontSize: 20,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: TicketColors.ink,
  );

  /// Prosa (frases del gato, descripciones).
  static const body = TextStyle(
    fontFamily: TicketFonts.sans,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: TicketColors.inkSoft,
  );
}

// ── SOMBRA DURA ─────────────────────────────────────────────────────────────
abstract class TicketShadow {
  static const List<BoxShadow> hard = [
    BoxShadow(color: Color(0x1A1A1A14), offset: Offset(3, 3), blurRadius: 0),
  ];
  static const List<BoxShadow> hardStrong = [
    BoxShadow(color: Color(0x331A1A1A), offset: Offset(4, 4), blurRadius: 0),
  ];
}

// ════════════════════════════════════════════════════════════════════════════
// FONDO: papel con grano + halo de fluorescente
// ════════════════════════════════════════════════════════════════════════════
class TicketPaper extends StatelessWidget {
  final Widget child;
  const TicketPaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.25,
            colors: [Color(0xFFFBF8F1), TicketColors.paper, Color(0xFFEDE6D8)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: const _GrainPainter(),
          child: child,
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Grano determinista: mismas motas en cada repintado, sin coste de estado.
    final rng = math.Random(7);
    final paint = Paint()..color = TicketColors.ink.withValues(alpha: 0.035);
    final count = (size.width * size.height / 2600).clamp(60, 900).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height,
          1,
          1,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════════════════
// TARJETA-TICKET
// ════════════════════════════════════════════════════════════════════════════
class TicketCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color borderColor;
  final Color background;
  final VoidCallback? onTap;
  final bool perforatedTop;
  final bool perforatedBottom;
  final bool elevated;

  const TicketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TicketSpace.l),
    this.margin,
    this.borderColor = TicketColors.ink,
    this.background = TicketColors.paper,
    this.onTap,
    this.perforatedTop = false,
    this.perforatedBottom = false,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TicketRadii.paper),
        border: Border.all(color: borderColor.withValues(alpha: 0.85), width: 1.2),
        boxShadow: elevated ? TicketShadow.hard : null,
      ),
      child: child,
    );

    if (perforatedTop || perforatedBottom) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (perforatedTop) const PerforatedEdge(flip: true),
          body,
          if (perforatedBottom) const PerforatedEdge(),
        ],
      );
    }

    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TicketRadii.paper),
          splashColor: TicketColors.stamp.withValues(alpha: 0.08),
          highlightColor: TicketColors.stamp.withValues(alpha: 0.05),
          child: body,
        ),
      );
    }

    return margin == null ? body : Padding(padding: margin!, child: body);
  }
}

// ── BORDE DENTADO (perforación de ticket) ───────────────────────────────────
class PerforatedEdge extends StatelessWidget {
  final bool flip;
  final Color color;
  const PerforatedEdge({super.key, this.flip = false, this.color = TicketColors.paper});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7,
      child: CustomPaint(painter: _ZigZagPainter(flip: flip, color: color)),
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  final bool flip;
  final Color color;
  const _ZigZagPainter({required this.flip, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 9.0;
    final path = Path();
    if (flip) {
      path.moveTo(0, size.height);
      for (double x = 0; x < size.width; x += step) {
        path.lineTo(x + step / 2, 0);
        path.lineTo(x + step, size.height);
      }
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      for (double x = 0; x < size.width; x += step) {
        path.lineTo(x + step / 2, size.height);
        path.lineTo(x + step, 0);
      }
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = TicketColors.ink.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ZigZagPainter old) => old.flip != flip || old.color != color;
}

// ── LÍNEA PUNTEADA ──────────────────────────────────────────────────────────
class DottedRule extends StatelessWidget {
  final double dash;
  final double gap;
  final Color? color;
  const DottedRule({super.key, this.dash = 3, this.gap = 4, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DottedRulePainter(
          dash: dash,
          gap: gap,
          color: color ?? TicketColors.ink.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _DottedRulePainter extends CustomPainter {
  final double dash, gap;
  final Color color;
  const _DottedRulePainter({required this.dash, required this.gap, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── LÍNEA DE TICKET: concepto ....... importe ───────────────────────────────
class TicketRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const TicketRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: labelStyle ?? TicketType.line),
        const SizedBox(width: 6),
        const Expanded(child: Padding(padding: EdgeInsets.only(bottom: 4), child: DottedRule())),
        const SizedBox(width: 6),
        Text(
          value,
          style: (valueStyle ?? TicketType.amountS).copyWith(color: valueColor),
        ),
      ],
    );
  }
}

// ── SELLO / CHIP ────────────────────────────────────────────────────────────
class StampChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;
  final bool rotated;

  const StampChip({
    super.key,
    required this.text,
    this.color = TicketColors.stamp,
    this.filled = false,
    this.icon,
    this.rotated = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TicketRadii.chip),
        border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: filled ? TicketColors.paper : color),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: TicketType.micro.copyWith(
              color: filled ? TicketColors.paper : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return rotated ? Transform.rotate(angle: -0.045, child: chip) : chip;
  }
}

// ── BARRA DE PROGRESO SEGMENTADA (impresión de bloques) ─────────────────────
class SegmentBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final int segments;
  final double height;

  const SegmentBar({
    super.key,
    required this.value,
    this.color = TicketColors.ink,
    this.segments = 20,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final filled = (value.clamp(0.0, 1.0) * segments).round();
    return SizedBox(
      height: height,
      child: Row(
        children: List.generate(segments, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
              decoration: BoxDecoration(
                color: i < filled ? color : TicketColors.paperDim,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── CÓDIGO DE BARRAS DECORATIVO ─────────────────────────────────────────────
class BarcodeStrip extends StatelessWidget {
  final String caption;
  final double height;
  final int seed;
  const BarcodeStrip({super.key, this.caption = '', this.height = 34, this.seed = 42});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _BarcodePainter(seed)),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            caption,
            style: TicketType.micro.copyWith(letterSpacing: 3, color: TicketColors.inkFaint),
          ),
        ],
      ],
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final int seed;
  const _BarcodePainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()..color = TicketColors.ink.withValues(alpha: 0.8);
    double x = 0;
    while (x < size.width) {
      final w = 1.0 + rng.nextInt(3);
      if (rng.nextDouble() > 0.38) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1 + rng.nextInt(2);
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.seed != seed;
}

// ── ENCABEZADO DE TICKET (cabecera de tienda) ───────────────────────────────
class TicketHeader extends StatelessWidget {
  final String store;
  final String subtitle;
  final Widget? trailing;

  const TicketHeader({
    super.key,
    required this.store,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.toUpperCase(),
                style: TicketType.headline.copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: TicketType.micro),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ── BOTÓN "TECLA DE CAJA REGISTRADORA" ──────────────────────────────────────
class RegisterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? kicker;
  final VoidCallback onTap;
  final bool primary;

  const RegisterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.kicker,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? TicketColors.paper : TicketColors.ink;
    final bg = primary ? TicketColors.ink : TicketColors.paper;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TicketRadii.paper),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(TicketRadii.paper),
            border: Border.all(color: TicketColors.ink, width: 1.2),
            boxShadow: TicketShadow.hardStrong,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: primary ? TicketColors.stamp : TicketColors.ink),
                  const Spacer(),
                  Icon(Icons.north_east_rounded, size: 12, color: fg.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 14),
              if (kicker != null) ...[
                Text(kicker!, style: TicketType.micro.copyWith(color: fg.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
              ],
              Text(
                label.toUpperCase(),
                style: TicketType.label.copyWith(
                  color: fg,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
