import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../models/meal_entry.dart';
import '../models/pantry_item.dart';
import '../models/recipe_ingredient.dart';
import '../services/ai_exceptions.dart';

/// Sheet para crear una receta a partir de items de la despensa.
///
/// El usuario elige uno o varios ingredientes (de la despensa o agregados
/// libremente con macros estimadas por Gemini IA), indica los gramos y un nombre.
/// Al guardar, devuelve un "meal bundle" (lista de MealEntry) que el caller
/// persiste en `users/{uid}/meals`.
class RecipeBuilderSheet extends ConsumerStatefulWidget {
  final List<PantryItem> pantryItems;
  final MealType mealType;
  final Future<bool> Function(
    List<RecipeIngredient> ingredients, {
    required String name,
  })
  onSave;

  const RecipeBuilderSheet({
    super.key,
    required this.pantryItems,
    required this.mealType,
    required this.onSave,
  });

  @override
  ConsumerState<RecipeBuilderSheet> createState() => _RecipeBuilderSheetState();
}

class _RecipeBuilderSheetState extends ConsumerState<RecipeBuilderSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final List<RecipeIngredient> _ingredients = [];
  bool _saving = false;
  bool _estimatingAi = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  double get _totalCalories =>
      _ingredients.fold<double>(0, (s, i) => s + i.calories);

  Future<void> _pickIngredient() async {
    if (widget.pantryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu despensa está vacía. Agrega productos primero o usa "+ Ingrediente libre (IA)".',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<PantryItem>(
      context: context,
      backgroundColor: context.nk.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PantryPickerSheet(
        items: widget.pantryItems,
        alreadyAdded: _ingredients.map((i) => i.source.id).toSet(),
      ),
    );
    if (picked != null) {
      setState(() {
        _ingredients.add(RecipeIngredient(source: picked, grams: 100));
      });
    }
  }

  /// Abre un diálogo para ingresar un ingrediente que no está en la despensa
  /// y calcula sus macros por 100g con Gemini IA.
  Future<void> _addFreeIngredient() async {
    final result = await showDialog<_FreeIngredientInput>(
      context: context,
      builder: (ctx) => const _FreeIngredientDialog(),
    );
    if (result == null || result.name.isEmpty) return;

    setState(() => _estimatingAi = true);
    try {
      final macros = await ref
          .read(geminiVisionServiceProvider)
          .estimateIngredientMacros(name: result.name, grams: result.grams);
      if (!mounted) return;
      setState(() {
        _ingredients.add(
          RecipeIngredient.fromAi(
            name: result.name,
            grams: result.grams,
            caloriesPer100: macros['calories'] ?? 150,
            proteinsPer100: macros['proteins'] ?? 10,
            carbsPer100: macros['carbs'] ?? 10,
            fatsPer100: macros['fats'] ?? 5,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      String friendly;
      if (e is AIException && e.userMessage != null) {
        friendly = e.userMessage!;
      } else {
        final msg = e.toString().toLowerCase();
        if (msg.contains('429') || msg.contains('quota')) {
          friendly = 'La IA está ocupada. Espera un momento y vuelve a intentar.';
        } else if (msg.contains('network') || msg.contains('connection')) {
          friendly = 'Sin conexión. Verifica tu red.';
        } else {
          friendly = 'No pude estimar los macros. Intenta de nuevo.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _estimatingAi = false);
    }
  }

  void _updateGrams(int index, double grams) {
    setState(() {
      _ingredients[index] = _ingredients[index].copyWith(grams: grams);
    });
  }

  void _remove(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  Future<void> _save() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ingrediente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_ingredients.any((i) => i.grams <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los ingredientes deben tener gramos > 0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ponle un nombre a tu receta.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await widget.onSave(
        List<RecipeIngredient>.from(_ingredients),
        name: name,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la receta. Intenta de nuevo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.nk.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.nk.textDim.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(),
                Divider(color: context.nk.textFaint, height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      AppSpacing.m,
                      AppSpacing.l,
                      120,
                    ),
                    children: [
                      // Nombre
                      TextField(
                        controller: _nameCtrl,
                        style: TextStyle(
                          color: context.nk.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nombre de la receta',
                          hintStyle: TextStyle(
                            color: context.nk.textDim,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.restaurant_menu_rounded,
                            color: context.nk.cat,
                          ),
                          filled: true,
                          fillColor: context.nk.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      // Lista ingredientes
                      Row(
                        children: [
                          Text(
                            'INGREDIENTES',
                            style: TextStyle(
                              fontFamily: AppFonts.mono,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: context.nk.textDim,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          if (_ingredients.isNotEmpty)
                            Text(
                              '${_totalCalories.toStringAsFixed(0)} kcal totales',
                              style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.nk.cat,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_ingredients.isEmpty)
                        _buildEmptyIngredients()
                      else
                        ..._ingredients.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ing = entry.value;
                          return _buildIngredientRow(idx, ing);
                        }),
                      const SizedBox(height: 8),
                      _buildAddIngredientButton(),
                    ],
                  ),
                ),
                _buildSaveBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, 8, AppSpacing.l, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.nk.cat.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 18,
              color: context.nk.cat,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Crear receta',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.nk.text,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.nk.cat.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(
              widget.mealType.displayName.toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: context.nk.cat,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyIngredients() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.nk.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: context.nk.textFaint.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 32,
            color: context.nk.textFaint.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            'Sin ingredientes todavía',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13,
              color: context.nk.textDim,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agrega desde tu despensa',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              color: context.nk.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(int index, RecipeIngredient ing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.nk.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: context.nk.cat.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: ing.isAiEstimated
                      ? 'Macros estimados por Gemini IA'
                      : 'Producto de tu despensa',
                  child: Text(
                    ing.source.name,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.nk.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _remove(index),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.nk.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: context.nk.danger.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Semantics(
                      label: 'Ajustar cantidad de ${ing.source.name}',
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: context.nk.cat,
                          inactiveTrackColor: context.nk.surfaceHigh,
                          thumbColor: context.nk.cat,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          trackHeight: 4,
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: ing.grams.clamp(10, 500),
                          min: 10,
                          max: 500,
                          divisions: 49,
                          onChanged: (v) => _updateGrams(index, v),
                        ),
                      ),
                    ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '${ing.grams.toStringAsFixed(0)} g',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.nk.cat,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _tinyMacro(
                '${ing.calories.toStringAsFixed(0)} kcal',
                context.nk.cat,
              ),
              _tinyMacro(
                'P ${ing.proteins.toStringAsFixed(1)}g',
                context.nk.protein,
              ),
              _tinyMacro(
                'C ${ing.carbs.toStringAsFixed(1)}g',
                context.nk.carbs,
              ),
              _tinyMacro(
                'G ${ing.fats.toStringAsFixed(1)}g',
                context.nk.fat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tinyMacro(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAddIngredientButton() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickIngredient,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'De despensa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.nk.cat,
              side: BorderSide(color: context.nk.cat.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _estimatingAi ? null : _addFreeIngredient,
            icon: _estimatingAi
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.nk.amber,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text(
              'Libre (IA)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.nk.amber,
              side: BorderSide(color: context.nk.amber.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        12,
        AppSpacing.l,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.nk.surface,
        border: Border(
          top: BorderSide(color: context.nk.cat.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: context.nk.textDim,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_totalCalories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.nk.cat,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _saving
                      ? [Colors.grey, Colors.grey]
                      : [context.nk.cat, context.nk.catShadow],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: context.nk.cat.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Guardar receta',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-sheet para elegir un item de la despensa.
class _PantryPickerSheet extends StatefulWidget {
  final List<PantryItem> items;
  final Set<String> alreadyAdded;
  const _PantryPickerSheet({required this.items, required this.alreadyAdded});

  @override
  State<_PantryPickerSheet> createState() => _PantryPickerSheetState();
}

class _PantryPickerSheetState extends State<_PantryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where(
          (i) =>
              i.name.toLowerCase().contains(_query.toLowerCase()) &&
              !widget.alreadyAdded.contains(i.id),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.nk.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.l, 8, AppSpacing.l, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.nk.textDim.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Elige un ingrediente',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.nk.text,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: context.nk.text),
              decoration: InputDecoration(
                hintText: 'Buscar…',
                hintStyle: TextStyle(color: context.nk.textDim),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.nk.textDim,
                ),
                filled: true,
                fillColor: context.nk.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.alreadyAdded.length == widget.items.length
                            ? 'Ya agregaste todos los productos.'
                            : 'No hay coincidencias.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.nk.textDim),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return Material(
                          color: context.nk.surface,
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                            onTap: () => Navigator.of(context).pop(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: context.nt.ofCategory(item.category),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        color: context.nk.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${item.calories.toStringAsFixed(0)} kcal/100g',
                                    style: TextStyle(
                                      fontFamily: AppFonts.mono,
                                      fontSize: 10,
                                      color: context.nk.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Datos ingresados por el usuario para un ingrediente libre.
class _FreeIngredientInput {
  final String name;
  final double grams;

  const _FreeIngredientInput({required this.name, required this.grams});
}

/// Diálogo para ingresar nombre y porción en gramos de un ingrediente libre.
class _FreeIngredientDialog extends StatefulWidget {
  const _FreeIngredientDialog();

  @override
  State<_FreeIngredientDialog> createState() => _FreeIngredientDialogState();
}

class _FreeIngredientDialogState extends State<_FreeIngredientDialog> {
  final _nameCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final grams = double.tryParse(_gramsCtrl.text.trim()) ?? 100;
    if (name.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_FreeIngredientInput(name: name, grams: grams > 0 ? grams : 100));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.nk.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: context.nk.amber, size: 22),
          SizedBox(width: 8),
          Text(
            'Ingrediente libre (IA)',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.nk.text,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemini estimará los macros automáticamente.',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                color: context.nk.textDim,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: TextStyle(color: context.nk.text),
              decoration: InputDecoration(
                labelText: 'Nombre del alimento',
                hintText: 'Ej. Aguacate hass, Almendras...',
                labelStyle: TextStyle(color: context.nk.textDim),
                hintStyle: TextStyle(color: context.nk.textFaint),
                filled: true,
                fillColor: context.nk.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gramsCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
style: TextStyle(color: context.nk.text),
            decoration: InputDecoration(
              labelText: 'Cantidad en gramos',
              suffixText: 'g',
              labelStyle: TextStyle(color: context.nk.textDim),
                filled: true,
                fillColor: context.nk.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: context.nk.textDim),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.nk.amber,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Estimar y agregar'),
        ),
      ],
    );
  }
}
