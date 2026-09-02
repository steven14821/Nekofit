import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/neko_palette.dart';
import '../core/theme.dart';
import '../models/pantry_item.dart';

/// Sheet modal que compara el producto actual con otros de la misma categoría
/// usando tres métricas de valor nutricional:
///
/// 1. Proteína / precio   (g proteína por cada unidad monetaria) — solo si hay precio.
/// 2. Calorías / precio   (kcal por cada unidad monetaria)       — solo si hay precio.
/// 3. Score nutricional   (proteínas − grasas × 0.5, por 100g)  — siempre.
///
/// El producto actual se resalta en ámbar/verde. El ganador lleva 🏆.
class ProductComparatorSheet extends StatelessWidget {
  /// El ítem que el usuario está visualizando actualmente.
  final PantryItem current;

  /// Todos los ítems de la misma categoría (incluye [current]).
  final List<PantryItem> peers;

  const ProductComparatorSheet({
    super.key,
    required this.current,
    required this.peers,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;

    // Solo mostrar ítems con datos válidos (proteínas > 0 o calorías > 0)
    final valid = peers
        .where((p) => p.calories > 0 || p.proteins > 0)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (valid.isEmpty) {
      return _emptyState(nk);
    }

    final hasPriceData = valid.any((p) => (p.price ?? 0) > 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: nk.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: nk.textFaint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _buildHeader(nk),
              Divider(color: nk.border, height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    // Score nutricional — siempre visible
                    _MetricSection(
                      title: 'SCORE NUTRICIONAL',
                      subtitle: 'Proteínas − Grasas × 0.5  (por 100g)',
                      icon: Icons.star_rounded,
                      iconColor: nk.amber,
                      items: valid,
                      current: current,
                      getValue: (p) => p.proteins - p.fats * 0.5,
                      higherIsBetter: true,
                      unit: 'pts',
                    ),
                    if (hasPriceData) ...[
                      const SizedBox(height: 24),
                      _MetricSection(
                        title: 'PROTEÍNA / PRECIO',
                        subtitle: 'g de proteína por unidad monetaria',
                        icon: Icons.fitness_center_rounded,
                        iconColor: nk.protein,
                        items: valid,
                        current: current,
                        getValue: (p) =>
                            (p.price ?? 0) > 0 ? p.proteins / p.price! : 0,
                        higherIsBetter: true,
                        unit: 'g/\$',
                      ),
                      const SizedBox(height: 24),
                      _MetricSection(
                        title: 'CALORÍAS / PRECIO',
                        subtitle: 'kcal por unidad monetaria',
                        icon: Icons.bolt_rounded,
                        iconColor: nk.cat,
                        items: valid,
                        current: current,
                        getValue: (p) =>
                            (p.price ?? 0) > 0 ? p.calories / p.price! : 0,
                        higherIsBetter: true,
                        unit: 'kcal/\$',
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      _noPriceHint(nk),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(NekoColors nk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: nk.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.balance_rounded, size: 18, color: nk.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparar similares',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: nk.text,
                  ),
                ),
                Text(
                  current.category,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    color: nk.textFaint,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(NekoColors nk) {
    return Container(
      decoration: BoxDecoration(
        color: nk.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.balance_rounded, size: 48, color: nk.textFaint),
          const SizedBox(height: 16),
          Text(
            'Sin productos para comparar',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: nk.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega más productos a la categoría "${current.category}".',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13,
              color: nk.textDim,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _noPriceHint(NekoColors nk) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: nk.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nk.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: nk.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Agrega el precio a los productos para ver las métricas de valor económico.',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                color: nk.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección de métrica con barras de ranking
// ─────────────────────────────────────────────────────────────────────────────

class _MetricSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<PantryItem> items;
  final PantryItem current;
  final double Function(PantryItem) getValue;
  final bool higherIsBetter;
  final String unit;

  const _MetricSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.current,
    required this.getValue,
    required this.higherIsBetter,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;

    // Calcular valores y ordenar
    final scored = items
        .map((p) => (item: p, value: getValue(p)))
        .where((e) => e.value > 0)
        .toList();

    if (scored.isEmpty) return const SizedBox.shrink();

    final maxVal = scored.map((e) => e.value).reduce(math.max);
    scored.sort((a, b) => higherIsBetter
        ? b.value.compareTo(a.value)
        : a.value.compareTo(b.value));

    final winnerId = scored.first.item.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de sección
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: nk.textFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 10,
                      color: nk.textFaint.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Filas de productos
        ...scored.map((entry) => _ProductBar(
              item: entry.item,
              value: entry.value,
              maxValue: maxVal,
              unit: unit,
              isCurrent: entry.item.id == current.id,
              isWinner: entry.item.id == winnerId,
              barColor: iconColor,
              nk: nk,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra horizontal de un producto
// ─────────────────────────────────────────────────────────────────────────────

class _ProductBar extends StatelessWidget {
  final PantryItem item;
  final double value;
  final double maxValue;
  final String unit;
  final bool isCurrent;
  final bool isWinner;
  final Color barColor;
  final NekoColors nk;

  const _ProductBar({
    required this.item,
    required this.value,
    required this.maxValue,
    required this.unit,
    required this.isCurrent,
    required this.isWinner,
    required this.barColor,
    required this.nk,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final displayColor = isCurrent ? nk.amber : barColor;
    final displayValue = value < 10
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isWinner)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('🏆', style: TextStyle(fontSize: 12)),
                ),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? nk.text : nk.textDim,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrent)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: nk.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ESTE',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: nk.amber,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '$displayValue $unit',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: displayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Barra de valor
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(
                      color: displayColor.withValues(
                          alpha: isCurrent ? 1.0 : 0.65),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
