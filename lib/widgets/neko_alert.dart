import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/haptics.dart';
import 'neko_speech_bubble.dart';

/// Helper estático para mostrar burbujas manga como reemplazo premium del
/// `SnackBar` genérico. Se monta en el `Overlay` global con animación
/// de entrada/salida y posicionamiento inferior centrado.
///
/// Ejemplos:
/// ```dart
/// NekoAlert.jagged(context, 'Te pasaste 200 kcal del macro de hoy.');
/// NekoAlert.cloud(context, 'Analizando tu plato…');
/// NekoAlert.heart(context, '¡Racha de 7 días! 🔥');
/// ```
class NekoAlert {
  NekoAlert._();

  static OverlayEntry? _current;

  static void jagged(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 3200),
    IconData icon = Icons.warning_amber_rounded,
  }) =>
      _show(context, message, BubbleVariant.jagged, duration, icon);

  static void cloud(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 3200),
    IconData icon = Icons.psychology_alt_outlined,
  }) =>
      _show(context, message, BubbleVariant.cloud, duration, icon);

  static void heart(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 3200),
    IconData icon = Icons.favorite_rounded,
  }) =>
      _show(context, message, BubbleVariant.heart, duration, icon);

  static void _show(
    BuildContext context,
    String message,
    BubbleVariant variant,
    Duration duration,
    IconData icon,
  ) {
    // Dismiss el actual si está montado.
    _current?.remove();
    _current = null;

    // Haptic feedback según variante.
    switch (variant) {
      case BubbleVariant.jagged:
        Haptics.warn();
        break;
      case BubbleVariant.heart:
        Haptics.success();
        break;
      case BubbleVariant.cloud:
        Haptics.tap();
        break;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _NekoAlertHost(
        message: message,
        variant: variant,
        icon: icon,
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

class _NekoAlertHost extends StatefulWidget {
  const _NekoAlertHost({
    required this.message,
    required this.variant,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final BubbleVariant variant;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_NekoAlertHost> createState() => _NekoAlertHostState();
}

class _NekoAlertHostState extends State<_NekoAlertHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.shouldAnimate) {
        _ctrl.forward();
      } else {
        _ctrl.value = 1.0;
      }
    });

    Future.delayed(widget.duration, () {
      if (!mounted) return;
      _ctrl.reverse().whenComplete(() {
        if (mounted) widget.onDismissed();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 80 + MediaQuery.of(context).padding.bottom,
      child: IgnorePointer(
        ignoring: false,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            child: Center(
              child: NekoSpeechBubble(
                message: widget.message,
                variant: widget.variant,
                icon: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// `Haptics` y `AppColors` ya se usan arriba (Haptics.warn/success/tap y
// NekoSpeechBubble consume AppColors transitivamente).
