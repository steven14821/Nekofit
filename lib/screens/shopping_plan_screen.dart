import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/haptics.dart';
import '../core/providers.dart';
import '../core/neko_palette.dart';
import '../l10n/app_localizations.dart';
import '../models/pantry_item.dart';
import '../models/user_context.dart';
import '../models/weekly_plan.dart';
import '../services/firebase_service.dart';
import '../services/inventory_estimator_service.dart';
import '../services/shopping_list_service.dart';
import '../services/weekly_plan_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/hanko_stamp.dart';
import '../widgets/neko_alert.dart';
import '../widgets/neko_cat_mascot.dart';
import '../widgets/neko_speech_bubble.dart';

/// Pantalla dual con tabs:
///  - "Esta semana" → plan generado por IA + checklist.
///  - "Para comprar" → lista inteligente (agotados + críticos + plan).
///
/// Se abre desde el icono de calendario en la Despensa. Noche Ámbar,
/// theme-aware (context.nk) con modo claro lite.
class ShoppingPlanScreen extends ConsumerStatefulWidget {
  const ShoppingPlanScreen({super.key});

  @override
  ConsumerState<ShoppingPlanScreen> createState() => _ShoppingPlanScreenState();
}

class _ShoppingPlanScreenState extends ConsumerState<ShoppingPlanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Plan
  WeeklyPlan? _plan;
  bool _loadingPlan = false;

  // Lista
  List<ShoppingItem> _shopping = [];
  bool _loadingList = false;

  // Datos
  List<PantryItem> _pantry = [];
  UserContext? _user;
  List<InventoryEstimate> _estimates = [];

  late final WeeklyPlanService _planService = ref.read(
    weeklyPlanServiceProvider,
  );
  late final ShoppingListService _listService = ref.read(
    shoppingListServiceProvider,
  );
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);
  final _estimator = InventoryEstimatorService();
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadPantryAndUser(), _loadListFromCache()]);
    await _generatePlan();
    await _regenerateList();
  }

  Future<void> _loadPantryAndUser() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      final pantrySnap = await _firebase.db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .get();
      final pantry = pantrySnap.docs
          .map((d) => PantryItem.fromMap(d.data(), d.id))
          .toList();

      final userSnap = await _firebase.db.collection('users').doc(uid).get();
      final user = userSnap.exists
          ? UserContext.fromMap({...?userSnap.data(), 'uid': uid})
          : null;

      final estimates = await _estimator.estimateAll(
        uid: uid,
        pantryItems: pantrySnap.docs.map((d) => d.data()).toList(),
      );

      if (!mounted) return;
      setState(() {
        _pantry = pantry;
        _user = user;
        _estimates = estimates;
      });
    } catch (_) {
      // Silenciar: la pantalla mostrará placeholders vacíos.
    }
  }

  Future<void> _generatePlan({bool force = false}) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null || _user == null) return;
    setState(() => _loadingPlan = true);
    try {
      final plan = await _planService.getPlan(
        uid: uid,
        user: _user!,
        pantry: _pantry,
        forceRegenerate: force,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loadingPlan = false;
      });
      if (force) {
        final l10n = AppLocalizations.of(context);
        NekoAlert.heart(context, l10n.planRegenerated);
        HankoStamp.show(context, kind: HankoStampKind.celebrate);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPlan = false);
      final l10n = AppLocalizations.of(context);
      NekoAlert.jagged(context, l10n.planGenerateError('$e'));
    }
  }

  Future<void> _loadListFromCache() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    final cached = await _listService.load(uid);
    if (!mounted) return;
    setState(() => _shopping = cached);
  }

  Future<void> _regenerateList() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingList = true);
    final generated = await _listService.generateSuggestedList(
      uid: uid,
      pantry: _pantry,
      plan: _plan,
      estimates: _estimates,
    );
    if (!mounted) return;
    setState(() {
      _shopping = generated;
      _loadingList = false;
    });
    await _listService.save(uid, _shopping);
  }

  /// Ajusta la cantidad sugerida de un ítem de la lista con un stepper
  /// (+/-). Persiste la lista completa (incluidos los checks actuales).
  Future<void> _adjustQuantity(ShoppingItem item, double delta) async {
    Haptics.tap();
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    final parsed = _parseQuantity(item.suggestedQuantity);
    if (parsed == null) return;
    final step = _stepFor(parsed.unit);
    final next = (parsed.value + delta)
        .clamp(step.toDouble(), 99999)
        .toDouble();
    final index = _shopping.indexOf(item);
    if (index == -1) return;
    final updated = item.copyWith(
      suggestedQuantity: _formatQuantity(next, parsed.unit),
    );
    setState(() => _shopping[index] = updated);
    await _listService.save(uid, _shopping);
  }

  Future<void> _toggleItem(int index) async {
    Haptics.select();
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _shopping[index] = _shopping[index].copyWith(
        checked: !_shopping[index].checked,
      );
    });
    await _listService.save(uid, _shopping);
    if (!mounted) return;

    if (_shopping[index].checked) {
      HankoStamp.show(context, kind: HankoStampKind.replenish);
    }
  }

  Future<void> _toggleMealDone(int dayIndex, int mealIndex) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null || _plan == null) return;
    Haptics.select();
    final updated = await _planService.toggleMealDone(
      uid: uid,
      plan: _plan!,
      dayIndex: dayIndex,
      mealIndex: mealIndex,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _plan = updated);
    NekoAlert.cloud(
      context,
      updated.days[dayIndex].meals[mealIndex].done
          ? l10n.planMealDone
          : l10n.planMealUndone,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final isDark = nk.mode == NekoThemeMode.dark;
    final accentTint = isDark
        ? nk.amber.withValues(alpha: 0.14)
        : nk.amber.withValues(alpha: 0.12);

    return Scaffold(
      backgroundColor: nk.bg,
      appBar: AppBar(
        title: Text(
          l10n.planTitle,
          style: _display(
            size: 19,
            weight: FontWeight.w700,
            color: nk.text,
            letterSpacing: -0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: nk.textDim),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.planRegenerateTooltip,
            onPressed: () => _generatePlan(force: true),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: nk.text,
          unselectedLabelColor: nk.textDim,
          labelStyle: _display(size: 13, weight: FontWeight.w700),
          unselectedLabelStyle: _display(size: 13, weight: FontWeight.w600),
          indicator: BoxDecoration(
            color: accentTint,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 6),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: l10n.planTabThisWeek),
            Tab(text: l10n.planTabToBuy),
          ],
        ),
      ),
      body: AmberAtmosphere(
        child: TabBarView(
          controller: _tab,
          children: [_buildPlanTab(), _buildShoppingTab()],
        ),
      ),
    );
  }

  // ── Tab 1: Plan semanal ────────────────────────────────────────────────
  Widget _buildPlanTab() {
    if (_loadingPlan && _plan == null) {
      return const _LoadingState(label: 'Generando plan con tu gato…');
    }
    if (_plan == null || _plan!.days.isEmpty) {
      return const _EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Sin plan todavía',
        message: 'Pulsa el botón de refrescar para generar el plan con IA.',
      );
    }

    final plan = _plan!;
    return RefreshIndicator(
      onRefresh: () => _generatePlan(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: plan.days.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildPlanHeader(plan);
          final day = plan.days[index - 1];
          return _DayCard(
            day: day,
            onToggleMeal: (mIdx) => _toggleMealDone(index - 1, mIdx),
          );
        },
      ),
    );
  }

  Widget _buildPlanHeader(WeeklyPlan plan) {
    final nk = context.nk;
    final goals = _user?.macroGoals ?? const {};
    final computedKcal =
        (goals['calories'] as num?)?.toDouble() ??
        (((goals['proteins'] ?? goals['protein'] ?? 0) as num).toDouble() * 4 +
            ((goals['carbs'] ?? 0) as num).toDouble() * 4 +
            ((goals['fats'] ?? 0) as num).toDouble() * 9);
    final dailyGoalKcal = computedKcal > 500 ? computedKcal : 2000.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        children: [
          const NekoCatMascot(
            mood: CatMood.thinking,
            size: 56,
            showLabel: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan de la semana',
                  style: _display(
                    size: 16,
                    weight: FontWeight.w700,
                    color: nk.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${plan.avgDailyCalories.toStringAsFixed(0)} kcal/día · meta ${dailyGoalKcal.toStringAsFixed(0)}',
                  style: _mono(size: 11.5, color: nk.textDim),
                ),
                const SizedBox(height: 6),
                Text(
                  '${plan.days.length} días · ${plan.totalCalories.toStringAsFixed(0)} kcal en total',
                  style: _mono(size: 10, color: nk.textFaint),
                ),
              ],
            ),
          ),
          if (plan.source == 'cache')
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.cached, size: 14, color: nk.textFaint),
            ),
          if (plan.source == 'fallback')
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.cloud_off, size: 14, color: nk.warn),
            ),
        ],
      ),
    );
  }

  // ── Tab 2: Lista de compras ────────────────────────────────────────────
  Widget _buildShoppingTab() {
    if (_loadingList && _shopping.isEmpty) {
      return const _LoadingState(
        label: 'Cruzando despensa, plan y predicciones…',
      );
    }
    if (_shopping.isEmpty) {
      return _EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Lista vacía',
        message:
            'Tu despensa está al día. Vuelve cuando algo se agote o se acerque.',
        action: ElevatedButton.icon(
          onPressed: _regenerateList,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Recalcular'),
        ),
      );
    }

    final byCategory = <String, List<ShoppingItem>>{};
    for (final item in _shopping) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }

    final totalCount = _shopping.length;
    final checkedCount = _shopping.where((i) => i.checked).length;

    return RefreshIndicator(
      onRefresh: _regenerateList,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildListHeader(totalCount, checkedCount),
          const SizedBox(height: 16),
          for (final entry in byCategory.entries) ...[
            _CategorySection(
              category: entry.key,
              items: entry.value,
              onToggle: (i) => _toggleItem(_shopping.indexOf(i)),
              onQuantityChange: (item, delta) => _adjustQuantity(item, delta),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildListHeader(int total, int checked) {
    final nk = context.nk;
    final progress = total == 0 ? 0.0 : checked / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_basket_rounded, size: 22, color: nk.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lista inteligente',
                  style: _display(
                    size: 16,
                    weight: FontWeight.w700,
                    color: nk.text,
                  ),
                ),
              ),
              Text(
                '$checked / $total',
                style: _mono(size: 15, weight: FontWeight.w700, color: nk.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: nk.surfaceHigh,
              color: nk.amber,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets auxiliares
// ═══════════════════════════════════════════════════════════════════════════

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onToggleMeal});

  final PlannedDay day;
  final void Function(int mealIndex) onToggleMeal;

  static const _dayNames = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final dayName = _dayNames[day.date.weekday - 1];
    final doneCount = day.meals.where((m) => m.done).length;
    final accentTint = isDark
        ? nk.amber.withValues(alpha: 0.14)
        : nk.amber.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.date.day.toString(),
                        style: _mono(
                          size: 14,
                          weight: FontWeight.w800,
                          color: nk.text,
                        ),
                      ),
                      Text(
                        dayName,
                        style: _body(
                          size: 8,
                          weight: FontWeight.w700,
                          color: nk.textDim,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.totalCalories.toStringAsFixed(0)} kcal',
                        style: _mono(
                          size: 15,
                          weight: FontWeight.w700,
                          color: nk.text,
                        ),
                      ),
                      Text(
                        '$doneCount / ${day.meals.length} hechas',
                        style: _mono(size: 11, color: nk.textDim),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: nk.divider),
          for (var i = 0; i < day.meals.length; i++)
            _MealRow(meal: day.meals[i], onTap: () => onToggleMeal(i)),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.onTap});

  final PlannedMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              meal.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: meal.done ? nk.amber : nk.textDim,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        meal.slot.toUpperCase(),
                        style: _mono(
                          size: 9.5,
                          weight: FontWeight.w700,
                          color: nk.textDim,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meal.title,
                          style: _body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: meal.done ? nk.textDim : nk.text,
                            decoration: meal.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: nk.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (meal.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meal.description,
                      style: _body(size: 12, color: nk.textDim),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _macroChip(
                        nk,
                        '${meal.calories.toStringAsFixed(0)} kcal',
                        nk.text,
                      ),
                      const SizedBox(width: 6),
                      _macroChip(
                        nk,
                        'P ${meal.proteins.toStringAsFixed(0)}',
                        nk.protein,
                      ),
                      const SizedBox(width: 6),
                      _macroChip(
                        nk,
                        'C ${meal.carbs.toStringAsFixed(0)}',
                        nk.carbs,
                      ),
                      const SizedBox(width: 6),
                      _macroChip(
                        nk,
                        'G ${meal.fats.toStringAsFixed(0)}',
                        nk.fat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(NekoColors nk, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: _mono(size: 10, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.items,
    required this.onToggle,
    required this.onQuantityChange,
  });

  final String category;
  final List<ShoppingItem> items;
  final void Function(ShoppingItem) onToggle;
  final void Function(ShoppingItem item, double delta) onQuantityChange;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final color = nk.amber;
    return Container(
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.toUpperCase(),
                  style: _mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.where((i) => i.checked).length} / ${items.length}',
                  style: _mono(size: 11, color: nk.textDim),
                ),
              ],
            ),
          ),
          for (final item in items)
            _ShoppingRow(
              item: item,
              onTap: () => onToggle(item),
              onQuantityChanged: (delta) => onQuantityChange(item, delta),
            ),
        ],
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.item,
    required this.onTap,
    required this.onQuantityChanged,
  });

  final ShoppingItem item;
  final VoidCallback onTap;
  final ValueChanged<double> onQuantityChanged;

  Color _reasonColor(NekoColors nk) {
    switch (item.reason) {
      case 'agotado':
        return nk.danger;
      case 'critico':
        return nk.warn;
      case 'plan':
        return nk.amber;
      default:
        return nk.textDim;
    }
  }

  String get _reasonLabel {
    switch (item.reason) {
      case 'agotado':
        return 'AGOTADO';
      case 'critico':
        return 'CRÍTICO';
      case 'plan':
        return 'PLAN';
      default:
        return 'MANUAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final reasonColor = _reasonColor(nk);
    final qty = _parseQuantity(item.suggestedQuantity);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            Icon(
              item.checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: item.checked ? nk.amber : nk.textDim,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: _body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: item.checked ? nk.textDim : nk.text,
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: nk.textDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: reasonColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _reasonLabel,
                          style: _mono(
                            size: 8.5,
                            weight: FontWeight.w800,
                            color: reasonColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (qty != null)
                        _QuantityStepper(
                          value: qty.value,
                          unit: qty.unit,
                          onChanged: onQuantityChanged,
                        )
                      else if (item.suggestedQuantity.isNotEmpty)
                        Text(
                          item.suggestedQuantity,
                          style: _mono(size: 11, color: nk.textDim),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stepper compacto de cantidades: [−] 250 g [+].
/// Solo se muestra cuando la cantidad sugerida es numérica (parseable).
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final double value;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final step = _stepFor(unit);

    return Container(
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: () => onChanged(-step),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            child: Text(
              _formatQuantity(value, unit),
              textAlign: TextAlign.center,
              style: _mono(size: 11, weight: FontWeight.w700, color: nk.text),
            ),
          ),
          _StepperButton(icon: Icons.add_rounded, onTap: () => onChanged(step)),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Icon(icon, size: 15, color: nk.textDim),
      ),
    );
  }
}

/// Parsea una cantidad sugerida tipo "250 g", "1 und", "1,5 kg" → (valor, unidad).
({double value, String unit})? _parseQuantity(String raw) {
  final m = RegExp(
    r'^([0-9]+(?:[.,][0-9]+)?)\s*([a-zA-Z%]+)?$',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  if (v == null) return null;
  return (value: v, unit: m.group(2) ?? '');
}

/// Formatea (250, 'g') → "250 g" manteniendo el estilo del original.
String _formatQuantity(double v, String unit) {
  final s = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceAll('.', ',');
  return unit.isEmpty ? s : '$s $unit';
}

/// Paso del stepper: gramos/mililitros en saltos de 10, el resto de 1 en 1.
double _stepFor(String unit) {
  switch (unit.toLowerCase()) {
    case 'g':
    case 'ml':
      return 10;
    default:
      return 1;
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: nk.amber),
          ),
          const SizedBox(height: 16),
          NekoSpeechBubble(message: label, variant: BubbleVariant.cloud),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: nk.textDim),
            const SizedBox(height: 16),
            Text(
              title,
              style: _display(
                size: 17,
                weight: FontWeight.w700,
                color: nk.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _body(size: 13, color: nk.textDim),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tipografía Noche Ámbar (mismas fuentes que Home/Diario/Mascota)
// ═══════════════════════════════════════════════════════════════════════════
TextStyle _display({
  double size = 14,
  FontWeight weight = FontWeight.w700,
  Color color = const Color(0xFFF4EFE6),
  double? letterSpacing,
  double? height,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color color = const Color(0xFF6B6459),
  double letterSpacing = 0,
  double? height,
}) => GoogleFonts.jetBrainsMono(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _body({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = const Color(0xFFF4EFE6),
  double letterSpacing = 0,
  double? height,
  TextDecoration? decoration,
  Color? decorationColor,
}) => GoogleFonts.dmSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
  decoration: decoration,
  decorationColor: decorationColor,
);
