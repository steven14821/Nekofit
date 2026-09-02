import 'package:flutter/material.dart';
import '../core/neko_palette.dart';
import '../models/pantry_item.dart';
import 'smart_label.dart';

/// Placeholder consistente para productos de la despensa sin foto.
///
/// Muestra el ícono de la categoría (proteína / carbohidrato / grasa /
/// vegetal / lácteo) sobre un fondo con el color de la categoría — la misma
/// lógica de "Smart Label" que ya clasifica los alimentos en el escáner.
/// Así un producto sin foto se lee como parte de la misma familia visual
/// que uno con foto, en vez de verse "roto" al lado de los demás.
class PantryImagePlaceholder extends StatelessWidget {
  final PantryItem item;

  /// Si es null, el placeholder se expande para llenar el espacio disponible.
  final double? size;

  final double borderRadius;

  const PantryImagePlaceholder({
    super.key,
    required this.item,
    this.size = 56,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = PantryCategoryLabel.resolve(item, context.nk);

    final content = Container(
      decoration: BoxDecoration(
        color: resolved.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: resolved.color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          resolved.icon,
          color: resolved.color,
          size: size != null ? size! * 0.42 : 26,
        ),
      ),
    );

    if (size == null) return content;
    return SizedBox(width: size, height: size, child: content);
  }
}
