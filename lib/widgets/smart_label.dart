import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../models/recognized_food.dart';
import '../models/pantry_item.dart';

/// Etiquetas inteligentes que identifican las comidas reconocidas por el
/// escáner de comida. Cada chip resume de un vistazo el tipo de alimento
/// (proteína, carbohidrato, etc.), su densidad calórica y si proviene
/// de la despensa del usuario (match) o fue identificado por Gemini sin
/// tener un producto guardado.
class SmartLabelStrip extends StatelessWidget {
  final RecognizedFood food;

  const SmartLabelStrip({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final tags = <_SmartTag>[];

    // 1) Origen: ¿está en la despensa?
    if (food.pantryItemId != null && food.pantryItemId!.isNotEmpty) {
      tags.add(_SmartTag(
        icon: Icons.inventory_2_rounded,
        label: 'EN DESPENSA',
        color: nk.ok,
        background: nk.ok.withValues(alpha: 0.14),
        border: nk.ok.withValues(alpha: 0.45),
      ));
    } else {
      tags.add(_SmartTag(
        icon: Icons.auto_awesome_rounded,
        label: 'IDENTIFICADO IA',
        color: nk.amberSoft,
        background: nk.amber.withValues(alpha: 0.16),
        border: nk.amber.withValues(alpha: 0.45),
      ));
    }

    // 2) Categoría macro: inferida por la proporción de macros por 100g.
    final category = _MacroCategory.fromMacros(
      proteins: food.proteinsPer100,
      carbs: food.carbsPer100,
      fats: food.fatsPer100,
    );
    tags.add(_SmartTag(
      icon: category.icon,
      label: category.label,
      color: _categoryColor(nk, category),
      background: _categoryColor(nk, category).withValues(alpha: 0.14),
      border: _categoryColor(nk, category).withValues(alpha: 0.45),
    ));

    // 3) Densidad calórica por 100g (heurística simple).
    final density = _CalorieDensity.fromKcal(food.caloriesPer100);
    tags.add(_SmartTag(
      icon: density.icon,
      label: density.label,
      color: density.color,
      background: density.color.withValues(alpha: 0.10),
      border: density.color.withValues(alpha: 0.35),
    ));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final t in tags) _SmartLabelChip(tag: t)],
    );
  }

  Color _categoryColor(NekoColors nk, _MacroCategory cat) {
    switch (cat) {
      case _MacroCategory.protein:
        return nk.protein;
      case _MacroCategory.carb:
        return nk.carbs;
      case _MacroCategory.fat:
        return nk.fat;
      case _MacroCategory.veg:
        return nk.ok;
      case _MacroCategory.dairy:
        return nk.cat;
      case _MacroCategory.mixed:
        return nk.amberSoft;
    }
  }
}

class _SmartLabelChip extends StatelessWidget {
  final _SmartTag tag;
  const _SmartLabelChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tag.background,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: tag.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 11, color: tag.color),
          const SizedBox(width: 4),
          Text(
            tag.label,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: tag.color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartTag {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final Color border;
  _SmartTag({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.border,
  });
}

/// Categorías macro inferidas a partir de la distribución de macros por 100g.
enum _MacroCategory {
  protein('PROTEÍNA', Icons.fitness_center_rounded),
  carb('CARBOHIDRATO', Icons.grain_rounded),
  fat('GRASA', Icons.water_drop_rounded),
  veg('VEGETAL', Icons.eco_rounded),
  dairy('LÁCTEO/HUEVO', Icons.egg_rounded),
  mixed('MIXTO', Icons.restaurant_menu_rounded);

  final String label;
  final IconData icon;
  const _MacroCategory(this.label, this.icon);

  static _MacroCategory fromMacros({
    required double proteins,
    required double carbs,
    required double fats,
  }) {
    final pKcal = proteins * 4;
    final cKcal = carbs * 4;
    final fKcal = fats * 9;
    final total = pKcal + cKcal + fKcal;
    if (total <= 0) return mixed;

    final pRatio = pKcal / total;
    final cRatio = cKcal / total;
    final fRatio = fKcal / total;

    if (proteins >= 10 && fats >= 8 && pRatio > 0.3 && fRatio > 0.3) {
      return dairy;
    }
    if (pKcal + cKcal + fKcal < 60) {
      return veg;
    }
    if (fRatio >= 0.55 && fats > 15) return fat;
    if (cRatio >= pRatio && cRatio >= fRatio) return carb;
    if (pRatio >= fRatio) return protein;
    return fat;
  }
}

/// Densidad calórica por 100g.
enum _CalorieDensity {
  light('LIGERA', Icons.eco_rounded, Color(0xFF7FC8A9)),
  medium('MODERADA', Icons.bolt_outlined, Color(0xFFE9C46A)),
  high('CALÓRICA', Icons.local_fire_department_rounded, Color(0xFFE76F51));

  final String label;
  final IconData icon;
  final Color color;
  const _CalorieDensity(this.label, this.icon, this.color);

  static _CalorieDensity fromKcal(double kcalPer100) {
    if (kcalPer100 < 80) return light;
    if (kcalPer100 < 250) return medium;
    return high;
  }
}

/// Categoriza un pantry item a partir de su campo `category` (string).
class PantryCategoryLabel {
  static ({String label, IconData icon, Color color}) resolve(
    PantryItem item,
    NekoColors nk,
  ) {
    final raw = item.category.toLowerCase();
    if (raw.contains('prot')) {
      return (
        label: 'PROTEÍNA',
        icon: Icons.fitness_center_rounded,
        color: nk.protein,
      );
    }
    if (raw.contains('carb') || raw.contains('grano')) {
      return (
        label: 'CARBOHIDRATO',
        icon: Icons.grain_rounded,
        color: nk.carbs,
      );
    }
    if (raw.contains('gras')) {
      return (
        label: 'GRASA',
        icon: Icons.water_drop_rounded,
        color: nk.fat,
      );
    }
    if (raw.contains('veg') || raw.contains('verdura') || raw.contains('fruta')) {
      return (
        label: 'VEGETAL',
        icon: Icons.eco_rounded,
        color: nk.ok,
      );
    }
    if (raw.contains('lácteo') ||
        raw.contains('lacteo') ||
        raw.contains('huevo') ||
        raw.contains('lácteos')) {
      return (
        label: 'LÁCTEO/HUEVO',
        icon: Icons.egg_rounded,
        color: nk.cat,
      );
    }
    return (
      label: 'OTRO',
      icon: Icons.restaurant_menu_rounded,
      color: nk.amberSoft,
    );
  }
}
