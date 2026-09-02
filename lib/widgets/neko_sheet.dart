import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';

/// Bottom sheet unificado de NekoFit con física de resorte profesional.
///
/// Implementa "Velocity Handoff": la animación de cierre o apertura hereda la
/// velocidad del gesto del usuario.
class NekoSheet {
  NekoSheet._();

  /// Abre una hoja con el estilo NekoFit.
  ///
  /// [triggerRect]: Si se proporciona, la hoja se "ancla" visualmente al elemento
  /// que la disparó, animando la escala desde esa posición.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Rect? triggerRect,
    bool showDragHandle = true,
    double maxHeightFactor = 0.92,
    Color? backgroundColor,
  }) {
    final shouldAnimate = context.shouldAnimate;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: shouldAnimate
          ? const Duration(milliseconds: 400)
          : Duration.zero,
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return _NekoPhysicalSheet(
          showDragHandle: showDragHandle,
          maxHeightFactor: maxHeightFactor,
          backgroundColor: backgroundColor ?? context.nk.surface,
          builder: builder,
          initialAnimation: anim,
          triggerRect: triggerRect,
        );
      },
    );
  }
}

class _NekoPhysicalSheet extends StatefulWidget {
  final WidgetBuilder builder;
  final bool showDragHandle;
  final double maxHeightFactor;
  final Color backgroundColor;
  final Animation<double> initialAnimation;
  final Rect? triggerRect;

  const _NekoPhysicalSheet({
    required this.builder,
    required this.showDragHandle,
    required this.maxHeightFactor,
    required this.backgroundColor,
    required this.initialAnimation,
    this.triggerRect,
  });

  @override
  State<_NekoPhysicalSheet> createState() => _NekoPhysicalSheetState();
}

class _NekoPhysicalSheetState extends State<_NekoPhysicalSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _screenHeight;
  late double _maxHeight;

  // Spring params now come from AppSprings.defaultSpring

  @override
  void initState() {
    super.initState();
    _screenHeight = MediaQuery.of(context).size.height;
    _maxHeight = _screenHeight * widget.maxHeightFactor;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    widget.initialAnimation.addListener(() {
      if (mounted) {
        _controller.value = widget.initialAnimation.value;
      }
    });

    if (widget.initialAnimation.value == 1.0) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final currentPos = _controller.value;

    if (velocity > 500 || (velocity > 0 && currentPos < 0.5)) {
      _animateTo(0.0, velocity / _screenHeight);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _animateTo(1.0, velocity / _screenHeight);
    }
  }

  void _animateTo(double target, double initialVelocity) {
    final simulation = AppSprings.defaultSpring.toSimulation(
      _controller.value,
      target,
      initialVelocity,
    );

    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double val = _controller.value;

        // 1. Cálculo de offset vertical
        // Si hay trigger, la hoja "cae" desde la base del botón hasta su posición final.
        // Esto crea la ilusión de que la hoja emerge del botón y se asienta abajo.
        double offset;
        if (widget.triggerRect != null) {
          final startY = widget.triggerRect!.bottom;
          final endY = _screenHeight - _maxHeight;
          offset = (startY - endY) * (1.0 - val);
        } else {
          offset = _screenHeight * (1.0 - val);
        }

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(0, offset),
                  child: Transform.scale(
                    scale: widget.triggerRect != null
                        ? 0.9 + (0.1 * val)
                        : 1.0,
                    alignment: Alignment.bottomCenter,
                    child: _NekoSheetContent(
                      showDragHandle: widget.showDragHandle,
                      maxHeight: _maxHeight,
                      backgroundColor: widget.backgroundColor,
                      builder: widget.builder,
                      onDragUpdate: (delta) {
                        double newValue = _controller.value - (delta / _screenHeight);
                        _controller.value = newValue.clamp(0.0, 1.2);
                      },
                      onDragEnd: _handleDragEnd,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NekoSheetContent extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showDragHandle;
  final double maxHeight;
  final Color backgroundColor;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  const _NekoSheetContent({
    required this.builder,
    required this.showDragHandle,
    required this.maxHeight,
    required this.backgroundColor,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onVerticalDragUpdate: (details) => onDragUpdate(details.primaryDelta ?? 0),
      onVerticalDragEnd: onDragEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.card * 2),
            ),
            border: Border(
              top: BorderSide(
                color: AppColors.cat.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDragHandle) ...[
                    const Center(child: _NekoDragHandle()),
                    const SizedBox(height: 14),
                  ],
                  builder(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NekoDragHandle extends StatelessWidget {
  const _NekoDragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
