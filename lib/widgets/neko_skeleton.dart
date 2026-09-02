import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Widget de carga con efecto shimmer (skeleton loader).
/// Reemplaza CircularProgressIndicator plano con algo más premium.
class NekoSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const NekoSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.baseColor = AppColors.surfaceHigh,
    this.highlightColor = AppColors.surface,
  });

  /// Skeleton de tarjeta de producto (despensa).
  const NekoSkeleton.card({super.key})
      : width = double.infinity,
        height = 80,
        borderRadius = AppRadii.card,
        baseColor = AppColors.surfaceHigh,
        highlightColor = AppColors.surface;

  /// Skeleton de línea de texto.
  const NekoSkeleton.line({super.key, double? width})
      : width = width ?? double.infinity,
        height = 14,
        borderRadius = 6,
        baseColor = AppColors.surfaceHigh,
        highlightColor = AppColors.surface;

  /// Skeleton de círculo (avatar, icono).
  const NekoSkeleton.circle({super.key, double size = 40})
      : width = size,
        height = size,
        borderRadius = 999,
        baseColor = AppColors.surfaceHigh,
        highlightColor = AppColors.surface;

  @override
  State<NekoSkeleton> createState() => _NekoSkeletonState();
}

class _NekoSkeletonState extends State<NekoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            ),
          ),
        );
      },
    );
  }
}

/// Group de skeletons para listar contenido cargando.
class NekoSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;
  final Widget Function(BuildContext, int)? builder;

  const NekoSkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
    this.spacing = 10,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (i) {
        if (builder != null) return builder!(context, i);
        return Padding(
          padding: EdgeInsets.only(bottom: i < itemCount - 1 ? spacing : 0),
          child: const NekoSkeleton.card(),
        );
      }),
    );
  }
}
