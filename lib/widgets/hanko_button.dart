import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/haptics.dart';

/// Sello circular estilo hanko japonés. Reabastecer (verde) o agotar (rosa).
///
/// Animación:
/// - Al pulsar: scale-down rápido (feedback táctil).
/// - Al cambiar de estado (ej. de agotado a reabastecido): scale-in elástico.
/// - Haptic feedback ligero en cada toque.
class HankoButton extends StatefulWidget {
  const HankoButton.replenish({
    super.key,
    required this.onPressed,
    this.tooltip = 'Reabastecer y actualizar fecha de compra',
  })  : _variant = _HankoVariant.replenish;

  const HankoButton.deplete({
    super.key,
    required this.onPressed,
    this.tooltip = 'Marcar como agotado',
  })  : _variant = _HankoVariant.deplete;

  final VoidCallback onPressed;
  final String tooltip;
  final _HankoVariant _variant;

  @override
  State<HankoButton> createState() => _HankoButtonState();
}

enum _HankoVariant { replenish, deplete }

class _HankoButtonState extends State<HankoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant HankoButton old) {
    super.didUpdateWidget(old);
    if (old._variant != widget._variant) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    final nt = Theme.of(context).extension<NekoTheme>()!;
    return widget._variant == _HankoVariant.replenish
        ? nt.inStock
        : nt.depleted;
  }

  IconData get _icon => widget._variant == _HankoVariant.replenish
      ? Icons.autorenew_rounded
      : Icons.remove_rounded;

  void _handleTap() {
    Haptics.tap();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedScale(
            scale: _isPressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadii.stamp),
                border: Border.all(color: _color.withValues(alpha: 0.55), width: 1.5),
              ),
              child: Icon(_icon, color: _color, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
