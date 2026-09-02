import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/meal_entry.dart';
import '../models/pantry_item.dart';
import '../services/firebase_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/meal_macro_history_card.dart';
import '../widgets/neko_speech_bubble.dart';
import '../widgets/neko_skeleton.dart';
import '../widgets/neko_tour.dart';
import 'food_scanner_screen.dart';

/// Diario Alimentario — réplica del diseño HTML "Noche Ámbar".
///
/// Konbini japonés a las 3 AM: date-nav con chevrons, resumen del día con
/// macros, timeline vertical con puntos (🌅☀️🌙🍙) y tarjetas de comida, y
/// ticket térmico "RESUMEN DEL DÍA" con la nota del gato.
///
/// Los datos son en vivo: lee `users/{uid}/meals` del día seleccionado y
/// agrupa por tipo de comida. Tocar un alimento abre el sheet de edición
/// (gramos, macros, eliminar) y los botones Añadir abren el escáner.
class DiaryScreen extends ConsumerStatefulWidget {
  /// Fecha con la que abre el diario. Si es null, abre en hoy.
  /// Lo usa Estadísticas para saltar a un día concreto desde la gráfica.
  final DateTime? initialDate;

  const DiaryScreen({super.key, this.initialDate});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);

  /// Flag de "se guardó una comida y se alimentó a la mascota" durante esta
  /// sesión de la pantalla. Permite devolver feedback al llamador cuando el
  /// usuario llegó aquí desde `PetScreen`.
  bool _didFeedPet = false;

  // ── Navegación de fechas ──
  late DateTime _selectedDate;

  // ── Tour contextual (primera vez) ──
  final _dateNavKey = GlobalKey();
  final _daySummaryKey = GlobalKey();
  final _addMealKey = GlobalKey();
  bool _tourLaunched = false;
  int _tourAttempts = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
  }

  @override
  void dispose() {
    // Si el usuario sale a mitad del tour (p. ej. back desde Estadísticas),
    // quitar el overlay para que no quede flotando ni se duplique al reentrar.
    NekoTour.dismissAll();
    super.dispose();
  }

  /// Lanza el tour contextual la primera vez que el usuario entra al diario.
  /// Espera a que el timeline real esté renderizado (los streams de Firestore
  /// emiten) antes de iluminar los targets.
  void _maybeStartTour() {
    if (!mounted || _tourLaunched) return;
    // No lanzar si la pestaña está oculta en el Offstage de la navegación
    // principal: la instancia de la pestaña vive desde el arranque y, si
    // lanzara aquí, el tour aparecería sobre la pestaña activa (Home).
    // Reintentamos cada frame; al activar la pestaña, el guard se abre solo.
    final offstage = context.findAncestorWidgetOfExactType<Offstage>();
    if (offstage != null && offstage.offstage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
      return;
    }
    final targetsReady =
        _dateNavKey.currentContext != null &&
        _daySummaryKey.currentContext != null &&
        _addMealKey.currentContext != null;
    if (!targetsReady) {
      if (_tourAttempts++ > 300) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
      return;
    }
    _tourLaunched = true;
    final l10n = AppLocalizations.of(context);
    NekoTour.show(
      context: context,
      tourId: 'diary_v1',
      steps: [
        NekoTourStep(
          title: l10n.diaryTour1,
          message: l10n.diaryTour1Msg,
          bubbleVariant: BubbleVariant.cloud,
          bubbleAlignment: NekoTourAlignment.bottomLeft,
          icon: Icons.calendar_month_outlined,
          targetKey: _dateNavKey,
          padding: const EdgeInsets.all(8),
        ),
        NekoTourStep(
          title: l10n.diaryTour2,
          message: l10n.diaryTour2Msg,
          bubbleVariant: BubbleVariant.heart,
          bubbleAlignment: NekoTourAlignment.bottomLeft,
          icon: Icons.bar_chart_rounded,
          targetKey: _daySummaryKey,
          padding: const EdgeInsets.all(8),
        ),
        NekoTourStep(
          title: l10n.diaryTour3,
          message: l10n.diaryTour3Msg,
          bubbleVariant: BubbleVariant.cloud,
          bubbleAlignment: NekoTourAlignment.topRight,
          icon: Icons.add_circle_outline_rounded,
          targetKey: _addMealKey,
          padding: const EdgeInsets.all(8),
        ),
      ],
    );
  }

  DateTime get _dayStart =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  DateTime get _dayEnd => _dayStart.add(const Duration(days: 1));
  bool get _isToday =>
      _selectedDate.year == DateTime.now().year &&
      _selectedDate.month == DateTime.now().month &&
      _selectedDate.day == DateTime.now().day;

  void _goToPreviousDay() {
    setState(
      () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
    );
  }

  void _goToNextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDate.isBefore(
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    )) {
      setState(
        () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
      );
    }
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
  }

  Future<void> _openScannerForMeal(MealType mealType) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final pantrySnapshot = await _firebase.db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .where('isAvailable', isEqualTo: true)
        .get();
    final pantryItems = pantrySnapshot.docs
        .map((d) => PantryItem.fromMap(d.data(), d.id))
        .toList();

    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FoodScannerScreen(
          pantryItems: pantryItems,
          initialMealType: mealType,
        ),
      ),
    );
    if (saved == true && mounted) {
      _didFeedPet = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).diaryAddSnack),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final nk = context.nk;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: nk.mode == NekoThemeMode.dark
                ? ColorScheme.dark(
                    primary: nk.amber,
                    onPrimary: const Color(0xFF1A1206),
                    surface: nk.surface,
                    onSurface: nk.text,
                  )
                : ColorScheme.light(
                    primary: nk.amber,
                    onPrimary: Colors.white,
                    surface: nk.surface,
                    onSurface: nk.text,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _openEditMealSheet(MealEntry meal) {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _EditMealSheet(uid: uid, meal: meal),
    );
  }

  // ── Header ──
  Widget _buildHeader(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        children: [
          Text(
            l10n.diaryTitle,
            style: _display(nk, size: 22, weight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Text(l10n.diarySubtitle,
              style: _mono(nk, size: 9, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  // ── Navegador de fechas ──
  Widget _buildDateNavigator() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      key: _dateNavKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        children: [
          _navChevron(Icons.chevron_left_rounded, _goToPreviousDay),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(
                    _fullDate(_selectedDate),
                    style: _display(nk, size: 15, weight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: _isToday ? null : _goToToday,
                    child: Text(
                      _isToday ? l10n.diaryToday : l10n.diaryBackToToday,
                      style: _mono(
                        nk,
                        size: 9,
                        weight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: _isToday ? nk.amber : nk.cat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _navChevron(
            Icons.chevron_right_rounded,
            _isToday ? null : _goToNextDay,
          ),
        ],
      ),
    );
  }

  Widget _navChevron(IconData icon, VoidCallback? onTap) {
    final nk = context.nk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: nk.border),
        ),
        child: Icon(
          icon,
          size: 15,
          color: onTap == null ? nk.textFaint : nk.textDim,
        ),
      ),
    );
  }

  // ── Resumen del día ──
  Widget _buildDaySummary({
    required double totalCal,
    required double totalPro,
    required double totalCarbs,
    required double totalFats,
  }) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      key: _daySummaryKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: nk.mode == NekoThemeMode.dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1AF0B429), Colors.transparent],
              )
            : null,
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.amber.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.diaryDayTotal,
                style: _mono(nk, size: 9, letterSpacing: 0.16),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatNumber(totalCal)} kcal',
                style: _display(nk, size: 20, weight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              _macroTag('P ${totalPro.round()}g', nk.protein),
              _macroTag('C ${totalCarbs.round()}g', nk.carbs),
              _macroTag('G ${totalFats.round()}g', nk.fat),
            ],
          ),
        ],
      ),
    );
  }

  // ── Timeline ──
  Widget _buildTimeline(
    Map<MealType, List<MealEntry>> grouped,
    String catName,
  ) {
    return Column(
      children: [
        for (var i = 0; i < _allMealSlots.length; i++) ...[
          _buildSlot(
            _allMealSlots[i],
            grouped[_allMealSlots[i].type] ?? const [],
            isLast: i == _allMealSlots.length - 1,
            addKey: i == _allMealSlots.length - 1 ? _addMealKey : null,
            catName: catName,
          ),
          if (i < _allMealSlots.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSlot(
    _MealSlot slot,
    List<MealEntry> meals, {
    required bool isLast,
    GlobalKey? addKey,
    required String catName,
  }) {
    final nk = context.nk;
    final hasMeals = meals.isNotEmpty;
    final time = hasMeals ? _formatTime(meals.first.createdAt) : '--:--';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rail: punto + línea punteada + hora ──
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nk.surface,
                    border: Border.all(
                      color: hasMeals
                          ? nk.amber.withValues(alpha: 0.55)
                          : nk.border,
                      width: 1.5,
                    ),
                    boxShadow: (hasMeals && nk.mode == NekoThemeMode.dark)
                        ? [
                            BoxShadow(
                              color: nk.amber.withValues(alpha: 0.22),
                              blurRadius: 16,
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: Icon(slot.icon, size: 15, color: nk.textDim),
                  ),
                ),
                if (isLast)
                  const Expanded(child: SizedBox.shrink())
                else
                  Expanded(
                    child: CustomPaint(
                      painter: _VerticalDashedPainter(nk.divider),
                      child: const SizedBox(width: 1),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(time, style: _mono(nk, size: 9, color: nk.textFaint)),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: hasMeals
                ? _mealCard(slot, meals, addKey: addKey)
                : _emptyCard(slot, addKey: addKey, catName: catName),
          ),
        ],
      ),
    );
  }

  Widget _mealCard(_MealSlot slot, List<MealEntry> meals, {GlobalKey? addKey}) {
    final nk = context.nk;
    final cal = meals.fold<double>(0, (s, m) => s + m.calories);
    final pro = meals.fold<double>(0, (s, m) => s + m.proteins);
    final carb = meals.fold<double>(0, (s, m) => s + m.carbs);
    final fat = meals.fold<double>(0, (s, m) => s + m.fats);
    final hasIA = meals.any(
      (m) => m.imageUrl != null && m.imageUrl!.isNotEmpty,
    );
    final title = meals.map((m) => m.foodName).join(' + ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera: tipo + nombre + kcal + botón añadir
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.type.displayName.toUpperCase(),
                      style: _mono(
                        nk,
                        size: 9.5,
                        letterSpacing: 0.14,
                        color: nk.textFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _display(nk, size: 15, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                '${_formatNumber(cal)} kcal',
                style: _mono(
                  nk,
                  size: 12,
                  weight: FontWeight.w700,
                  color: nk.amber,
                ),
              ),
              const SizedBox(width: 8),
              KeyedSubtree(
                key: addKey,
                child: GestureDetector(
                  onTap: () => _openScannerForMeal(slot.type),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: nk.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(Icons.add, size: 14, color: nk.amber),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ítems de la comida (tap → editar)
          for (var i = 0; i < meals.length; i++) ...[
            GestureDetector(
              onTap: () => _openEditMealSheet(meals[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        meals[i].foodName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mono(nk, size: 11, color: nk.textDim),
                      ),
                    ),
                    Text(
                      '−${_formatNumber(meals[i].grams)} g',
                      style: _mono(nk, size: 11, color: nk.textFaint),
                    ),
                  ],
                ),
              ),
            ),
            if (i < meals.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: CustomPaint(
                  painter: _DashedLinePainter(nk.divider),
                  child: const SizedBox(height: 1, width: double.infinity),
                ),
              ),
          ],
          const SizedBox(height: 8),
          // Pie: macros
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _macroTag('P ${pro.round()}g', nk.protein),
              _macroTag('C ${carb.round()}g', nk.carbs),
              _macroTag('G ${fat.round()}g', nk.fat),
              if (hasIA) _ghostTag('(IA)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(
    _MealSlot slot, {
    GlobalKey? addKey,
    required String catName,
  }) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.type.displayName.toUpperCase(),
                  style: _mono(nk, size: 9.5, letterSpacing: 0.14),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.diaryEmptySlot(catName),
                  style: _body(nk, size: 12.5, color: nk.textFaint),
                ),
              ],
            ),
          ),
          KeyedSubtree(
            key: addKey,
            child: GestureDetector(
              onTap: () => _openScannerForMeal(slot.type),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: nk.mode == NekoThemeMode.dark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF0B429), Color(0xFFFF6B3D)],
                        )
                      : null,
                  color: nk.mode == NekoThemeMode.dark ? null : nk.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: nk.mode == NekoThemeMode.dark
                          ? const Color(0xFF1A1206)
                          : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.diaryAdd,
                      style: _display(
                        nk,
                        size: 12,
                        weight: FontWeight.w600,
                        color: nk.mode == NekoThemeMode.dark
                            ? const Color(0xFF1A1206)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroTag(String text, Color color) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: _mono(
          nk,
          size: 9.5,
          weight: FontWeight.w700,
          letterSpacing: 0.08,
          color: color,
        ),
      ),
    );
  }

  Widget _ghostTag(String text) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: _mono(nk, size: 9.5, letterSpacing: 0.08, color: nk.textDim),
      ),
    );
  }

  // ── Fechas ──
  String _fullDate(DateTime date) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${days[date.weekday - 1]} ${date.day} de ${months[date.month - 1]}';
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final uid = _firebase.currentUser?.uid;
    if (uid == null) {
      return Scaffold(backgroundColor: nk.bg, body: const NekoSkeletonList());
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firebase.db.collection('users').doc(uid).snapshots(),
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data() as Map<String, dynamic>?;
        final goals = profileData?['macroGoals'] as Map<String, dynamic>?;
        final kcalGoal = (goals?['calories'] as num?)?.toDouble() ?? 2000.0;
        final proGoal = (goals?['proteins'] as num?)?.toDouble() ?? 0;
        // Nombre de la mascota del usuario (para el ticket y los slots vacíos).
        final rawCatName = profileData?['catName'] as String?;
        final catName = (rawCatName == null || rawCatName.trim().isEmpty)
            ? 'Mochi'
            : rawCatName.trim();

        return StreamBuilder<QuerySnapshot>(
          stream: _firebase.db
              .collection('users')
              .doc(uid)
              .collection('meals')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(_dayStart),
              )
              .where('createdAt', isLessThan: Timestamp.fromDate(_dayEnd))
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, mealsSnap) {
            final allMeals = (mealsSnap.data?.docs ?? [])
                .map(
                  (d) =>
                      MealEntry.fromMap(d.data() as Map<String, dynamic>, d.id),
                )
                .toList();

            final grouped = <MealType, List<MealEntry>>{};
            for (final m in allMeals) {
              grouped.putIfAbsent(m.mealType, () => []).add(m);
            }

            final totalCal = allMeals.fold<double>(0, (s, m) => s + m.calories);
            final totalPro = allMeals.fold<double>(0, (s, m) => s + m.proteins);
            final totalCarbs = allMeals.fold<double>(0, (s, m) => s + m.carbs);
            final totalFats = allMeals.fold<double>(0, (s, m) => s + m.fats);
            final deducted = allMeals
                .where(
                  (m) => m.pantryItemId != null && m.pantryItemId!.isNotEmpty,
                )
                .length;

            // El PopScope solo debe interceptar el back cuando el diario fue
            // PUSHEADO (p. ej. desde PetScreen, para devolver _didFeedPet).
            // Cuando es la pestaña raíz (Offstage en MainNavigation) su
            // PopScope queda registrado con la ruta COMPLETA: `canPop: false`
            // bloqueaba el back del sistema desde cualquier pestaña y forzaba
            // un pop de la ruta raíz (pantalla rota). `!canPop()` deja el
            // default del sistema en el caso raíz.
            final canPopRoute = Navigator.of(context).canPop();
            return PopScope(
              canPop: !canPopRoute,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) Navigator.of(context).pop(_didFeedPet);
              },
              child: Scaffold(
                backgroundColor: nk.bg,
                body: Stack(
                  children: [
                    // Atmósfera compartida: glows ámbar/ember + kanjis deslizantes + scanlines
                    const Positioned.fill(child: AmberAtmosphere()),
                    SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(context),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── Navegación de fecha ──
                                  _buildDateNavigator(),
                                  const SizedBox(height: 12),
                                  // ── Resumen del día ──
                                  _buildDaySummary(
                                    totalCal: totalCal,
                                    totalPro: totalPro,
                                    totalCarbs: totalCarbs,
                                    totalFats: totalFats,
                                  ),
                                  const SizedBox(height: 20),
                                  // ── Timeline ──
                                  _buildTimeline(grouped, catName),
                                  const SizedBox(height: 24),
                                  // ── Ticket del gato ──
                                  _ResumenTicket(
                                    uid: uid,
                                    catName: catName,
                                    date: _selectedDate,
                                    mealsCount: allMeals.length,
                                    registered: grouped.length,
                                    remainingKcal: (kcalGoal - totalCal).clamp(
                                      0,
                                      kcalGoal,
                                    ),
                                    remainingPro: (proGoal - totalPro).clamp(
                                      0,
                                      proGoal,
                                    ),
                                    deducted: deducted,
                                  ),
                                  const SizedBox(height: 16),
                                  // ── Patrón histórico de comidas ──
                                  MealMacroHistoryCard(
                                    uid: uid,
                                    todayGrouped: grouped,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tipografía del diseño (igual que Home Dashboard) ─────────────────────────

TextStyle _display(
  NekoColors nk, {
  double size = 14,
  FontWeight weight = FontWeight.w700,
  Color? color,
  double? letterSpacing,
  double? height,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: weight,
  color: color ?? nk.text,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _mono(
  NekoColors nk, {
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double letterSpacing = 0,
  double? height,
}) => GoogleFonts.jetBrainsMono(
  fontSize: size,
  fontWeight: weight,
  color: color ?? nk.textFaint,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _body(
  NekoColors nk, {
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => GoogleFonts.dmSans(
  fontSize: size,
  fontWeight: weight,
  color: color ?? nk.text,
);

/// Formatea un número con separador de miles en punto: 7412 → "7.412".
String _formatNumber(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ═════════════════════════════════════════════════════════════════════════════
// Ticket "RESUMEN DEL DÍA" — nota del gato en ticket térmico
// ═════════════════════════════════════════════════════════════════════════════

class _ResumenTicket extends ConsumerWidget {
  final String uid;
  final String catName;
  final DateTime date;
  final int mealsCount;
  final int registered;
  final double remainingKcal;
  final double remainingPro;
  final int deducted;

  const _ResumenTicket({
    required this.uid,
    required this.catName,
    required this.date,
    required this.mealsCount,
    required this.registered,
    required this.remainingKcal,
    required this.remainingPro,
    required this.deducted,
  });

  static const _paper = Color(0xFFF6F1E6);
  static const _ink = Color(0xFF1B1A17);
  static const _muted = Color(0xFF6A6255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firebaseServiceProvider).db;
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .where('isAvailable', isEqualTo: true)
          .snapshots(),
      builder: (context, pantrySnap) {
        final names = (pantrySnap.data?.docs ?? [])
            .map(
              (d) =>
                  ((d.data() as Map<String, dynamic>)['name'] ?? '') as String,
            )
            .where((n) => n.isNotEmpty)
            .take(2)
            .toList();
        return _buildTicket(context.nk, names, AppLocalizations.of(context));
      },
    );
  }

  Widget _buildTicket(
    NekoColors nk,
    List<String> pantryNames,
    AppLocalizations l10n,
  ) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    // En claro el papel casi se funde con el fondo (#F7F6F2 ≈ #F6F1E6):
    // papel más profundo + borde visible + sombra de elevación suave.
    final paper = nk.mode == NekoThemeMode.dark
        ? _paper
        : const Color(0xFFF0EADC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _TicketNotchPainter(paper),
            child: const SizedBox.expand(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: paper,
            border: nk.mode == NekoThemeMode.dark
                ? null
                : Border.all(color: const Color(0xFFCFCBC1)),
            boxShadow: nk.mode == NekoThemeMode.dark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0x14000000),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.diarySummary,
                    style: _mono(
                      nk,
                      size: 10,
                      weight: FontWeight.w700,
                      letterSpacing: 0.16,
                      color: _muted,
                    ),
                  ),
                  Text(
                    '$dd/$mm',
                    style: _mono(
                      nk,
                      size: 10,
                      weight: FontWeight.w700,
                      letterSpacing: 0.16,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomPaint(
                painter: _DashedLinePainter(_muted.withValues(alpha: 0.5)),
                child: const SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 10),
              // Cita
              Text(
                '“${_quote(pantryNames, l10n)}”',
                style: _mono(nk, size: 12.5, color: _ink, height: 1.55),
              ),
              const SizedBox(height: 10),
              CustomPaint(
                painter: _DashedLinePainter(_muted.withValues(alpha: 0.5)),
                child: const SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 8),
              // Pie
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.diaryItemsDeducted(deducted),
                    style: _mono(
                      nk,
                      size: 10,
                      letterSpacing: 0.12,
                      color: _muted,
                    ),
                  ),
                  Text(
                    mealsCount > 0 ? catName.toUpperCase() : l10n.diaryFasting,
                    style: _mono(
                      nk,
                      size: 10,
                      letterSpacing: 0.12,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _TicketNotchPainter(paper),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  String _quote(List<String> pantryNames, AppLocalizations l10n) {
    final buf = StringBuffer();
    if (registered == 0) {
      buf.write(l10n.diaryQuoteNothing);
    } else {
      buf.write(l10n.diaryQuoteMeals(registered));
    }
    if (remainingKcal > 0) {
      buf.write(l10n.diaryQuoteRemainingKcal(remainingKcal.round()));
      if (remainingPro > 0) {
        buf.write(l10n.diaryQuoteRemainingPro(remainingPro.round()));
      }
      buf.write('. ');
    } else {
      buf.write(l10n.diaryQuoteMet);
    }
    if (pantryNames.isEmpty) {
      buf.write(l10n.diaryQuotePantryEmpty);
    } else {
      buf.write(l10n.diaryQuotePantryNames(pantryNames.join(' y ')));
    }
    buf.write(l10n.diaryQuoteEnd);
    return buf.toString();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Painters y helpers de atmósfera
// ═════════════════════════════════════════════════════════════════════════════

/// Línea punteada horizontal (separadores del ticket y de las tarjetas).
class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

/// Línea punteada vertical (rail del timeline).
class _VerticalDashedPainter extends CustomPainter {
  final Color color;

  const _VerticalDashedPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDashedPainter old) =>
      old.color != color;
}

/// Bordes dentados del ticket (alternancia papel/transparente).
class _TicketNotchPainter extends CustomPainter {
  final Color paper;

  const _TicketNotchPainter(this.paper);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = paper;
    const dash = 8.0;
    const gap = 8.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, dash, size.height), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketNotchPainter old) => old.paper != paper;
}

// ═════════════════════════════════════════════════════════════════════════════
// Configuración visual de cada bloque de comida
// ═════════════════════════════════════════════════════════════════════════════

class _MealSlot {
  final MealType type;
  final IconData icon;
  const _MealSlot(this.type, this.icon);
}

const _allMealSlots = [
  _MealSlot(MealType.breakfast, Icons.wb_sunny_rounded),
  _MealSlot(MealType.lunch, Icons.restaurant_rounded),
  _MealSlot(MealType.dinner, Icons.nights_stay_rounded),
  _MealSlot(MealType.snack, Icons.fastfood_rounded),
];

// ═════════════════════════════════════════════════════════════════════════════
// Sheet para editar una comida existente
// ═════════════════════════════════════════════════════════════════════════════

class _EditMealSheet extends ConsumerStatefulWidget {
  final String uid;
  final MealEntry meal;
  const _EditMealSheet({required this.uid, required this.meal});

  @override
  ConsumerState<_EditMealSheet> createState() => _EditMealSheetState();
}

class _EditMealSheetState extends ConsumerState<_EditMealSheet> {
  late MealType _selectedType;
  late final TextEditingController _gramsCtrl;
  late final TextEditingController _nameCtrl;
  bool _saving = false;
  bool _deleting = false;

  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);

  @override
  void initState() {
    super.initState();
    _selectedType = widget.meal.mealType;
    _gramsCtrl = TextEditingController(
      text: widget.meal.grams.toStringAsFixed(0),
    );
    _nameCtrl = TextEditingController(text: widget.meal.foodName);
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Restaura gramos a la despensa. Devuelve `false` si falla.
  Future<bool> _restoreToPantry(String pantryItemId, double gramsToAdd) async {
    try {
      final doc = await _firebase.db
          .collection('users')
          .doc(widget.uid)
          .collection('pantry')
          .doc(pantryItemId)
          .get();

      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      final quantityStr = data['quantity'] as String? ?? '';
      final baseUnit = data['baseUnit'] as String? ?? 'g';
      final isAvailable = data['isAvailable'] as bool? ?? true;

      final currentQty =
          double.tryParse(
            quantityStr
                .replaceAll(RegExp(r'[^0-9.,]'), '')
                .replaceAll(',', '.'),
          ) ??
          0;

      final newQty = currentQty + gramsToAdd;

      await _firebase.db
          .collection('users')
          .doc(widget.uid)
          .collection('pantry')
          .doc(pantryItemId)
          .update({
            'quantity': '${newQty.round()} $baseUnit',
            if (!isAvailable) 'isAvailable': true,
          });
      return true;
    } catch (e) {
      debugPrint('EditMealSheet: error restaurando despensa: $e');
      return false;
    }
  }

  /// Resta gramos de la despensa. Devuelve `false` si falla.
  Future<bool> _deductFromPantry(
    String pantryItemId,
    double consumedGrams,
  ) async {
    try {
      final doc = await _firebase.db
          .collection('users')
          .doc(widget.uid)
          .collection('pantry')
          .doc(pantryItemId)
          .get();

      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      final quantityStr = data['quantity'] as String? ?? '';
      final baseUnit = data['baseUnit'] as String? ?? 'g';

      final currentQty =
          double.tryParse(
            quantityStr
                .replaceAll(RegExp(r'[^0-9.,]'), '')
                .replaceAll(',', '.'),
          ) ??
          0;

      final remaining = currentQty - consumedGrams;

      if (remaining <= 0) {
        await _firebase.db
            .collection('users')
            .doc(widget.uid)
            .collection('pantry')
            .doc(pantryItemId)
            .update({'quantity': '0 $baseUnit', 'isAvailable': false});
      } else {
        await _firebase.db
            .collection('users')
            .doc(widget.uid)
            .collection('pantry')
            .doc(pantryItemId)
            .update({'quantity': '${remaining.round()} $baseUnit'});
      }
      return true;
    } catch (e) {
      debugPrint('EditMealSheet: error descontando despensa: $e');
      return false;
    }
  }

  Future<void> _save() async {
    final newGrams = double.tryParse(_gramsCtrl.text.trim());
    if (newGrams == null || newGrams <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¿Cuántos gramos comiste?')));
      return;
    }

    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).diaryWhatsEaten),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final oldGrams = widget.meal.grams;
      final diffGrams = newGrams - oldGrams;

      // Calcular macros con los nuevos gramos usando los valores por 100g originales
      final factor = newGrams / 100.0;
      final oldFactor = oldGrams > 0 ? oldGrams / 100.0 : 0;
      final calPer100 = oldFactor > 0 ? widget.meal.calories / oldFactor : 0;
      final proPer100 = oldFactor > 0 ? widget.meal.proteins / oldFactor : 0;
      final carbPer100 = oldFactor > 0 ? widget.meal.carbs / oldFactor : 0;
      final fatPer100 = oldFactor > 0 ? widget.meal.fats / oldFactor : 0;

      // Actualizar la comida
      await _firebase.db
          .collection('users')
          .doc(widget.uid)
          .collection('meals')
          .doc(widget.meal.id)
          .update({
            'mealType': _selectedType.name,
            'foodName': newName,
            'grams': newGrams,
            'calories': calPer100 * factor,
            'proteins': proPer100 * factor,
            'carbs': carbPer100 * factor,
            'fats': fatPer100 * factor,
          });

      // Recalcular notificaciones inteligentes (best-effort).
      await ref
          .read(notificationServiceProvider)
          .scheduleContextualNotifications();

      // Ajustar la despensa según la diferencia
      bool pantryOk = true;
      if (widget.meal.pantryItemId != null &&
          widget.meal.pantryItemId!.isNotEmpty) {
        if (diffGrams > 0) {
          // Comió más → restar la diferencia
          pantryOk = await _deductFromPantry(
            widget.meal.pantryItemId!,
            diffGrams,
          );
        } else if (diffGrams < 0) {
          // Comió menos → devolver la diferencia
          pantryOk = await _restoreToPantry(
            widget.meal.pantryItemId!,
            diffGrams.abs(),
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pantryOk
                ? l10n.diaryEditSnackOk
                : l10n.diaryEditSnackPartial,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nk.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: nk.border),
        ),
        title: Text(
          l10n.diaryDeleteMeal,
          style: _display(nk, size: 16, weight: FontWeight.w700),
        ),
        content: Text(
          l10n.diaryDeleteMealConfirm(widget.meal.foodName),
          style: _body(nk, size: 13, color: nk.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: _body(nk, size: 13, color: nk.textFaint),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.diaryDeleteConfirm,
              style: _display(
                nk,
                size: 13,
                weight: FontWeight.w700,
                color: nk.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      // Eliminar la comida primero
      await _firebase.db
          .collection('users')
          .doc(widget.uid)
          .collection('meals')
          .doc(widget.meal.id)
          .delete();

      // Restaurar a la despensa
      bool pantryOk = true;
      if (widget.meal.pantryItemId != null &&
          widget.meal.pantryItemId!.isNotEmpty &&
          widget.meal.grams > 0) {
        pantryOk = await _restoreToPantry(
          widget.meal.pantryItemId!,
          widget.meal.grams,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pantryOk ? l10n.diaryDeleteSnackOk : l10n.diaryDeleteSnackPartial,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final macros = _buildMacroPreview();
    return Container(
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: nk.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Header
            Row(
              children: [
                Text(
                  l10n.diaryEditMeal,
                  style: _display(nk, size: 17, weight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _deleting ? null : _delete,
                  icon: _deleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: nk.danger,
                          ),
                        )
                      : Icon(
                          Icons.delete_outline_rounded,
                          color: nk.danger,
                          size: 20,
                        ),
                  tooltip: l10n.diaryDeleteMeal,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nombre
            TextField(
              controller: _nameCtrl,
              style: _body(nk, size: 14),
              decoration: InputDecoration(
                labelText: l10n.diaryWhatsEaten,
                labelStyle: _mono(nk, size: 11, color: nk.textFaint),
                prefixIcon: Icon(
                  Icons.restaurant_rounded,
                  size: 18,
                  color: nk.textFaint,
                ),
                filled: true,
                fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: nk.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: nk.amber.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selector de tipo de comida
            Text(
              l10n.diaryMealTypeLabel,


              style: _mono(nk, size: 10, letterSpacing: 0.14),
            ),
            const SizedBox(height: 8),
            Row(
              children: MealType.values.map((type) {
                final isSelected = _selectedType == type;
                final slot = _allMealSlots.firstWhere((s) => s.type == type);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: type == MealType.breakfast ? 0 : 4,
                      right: type == MealType.snack ? 0 : 4,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? nk.amber.withValues(alpha: 0.12)
                              : nk.surfaceHigh.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? nk.amber.withValues(alpha: 0.5)
                                : nk.border,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(slot.icon, size: 15, color: nk.textDim),
                            const SizedBox(height: 4),
                            Text(
                              type.displayName,
                              style: _mono(
                                nk,
                                size: 9,
                                weight: FontWeight.w700,
                                color: isSelected ? nk.amber : nk.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Gramos
            Row(
              children: [
                Icon(Icons.scale_rounded, size: 16, color: nk.textFaint),
                const SizedBox(width: 8),
                Text(
                  l10n.diaryQuantityLabel,
                  style: _mono(nk, size: 10, letterSpacing: 0.14),
                ),
                const Spacer(),
                SizedBox(
                  width: 110,
                  height: 38,
                  child: TextField(
                    controller: _gramsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: _mono(
                      nk,
                      size: 14,
                      weight: FontWeight.w700,
                      color: nk.text,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                      suffixText: 'g',
                      suffixStyle: _mono(nk, size: 12, color: nk.textFaint),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: nk.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: nk.amber.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preview de macros
            if (macros != null) ...[macros, const SizedBox(height: 16)],

            // Botones
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: nk.textDim,
                    side: BorderSide(color: nk.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancelar',
                    style: _body(nk, size: 13, color: nk.textDim),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: nk.mode == NekoThemeMode.dark
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF0B429), Color(0xFFFF6B3D)],
                              )
                            : null,
                        color: nk.mode == NekoThemeMode.dark ? null : nk.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _saving ? null : _save,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_saving)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: nk.mode == NekoThemeMode.dark
                                        ? const Color(0xFF1A1206)
                                        : Colors.white,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: nk.mode == NekoThemeMode.dark
                                      ? const Color(0xFF1A1206)
                                      : Colors.white,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                _saving ? l10n.diarySaving : l10n.diarySave,
                                style: _display(
                                  nk,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: nk.mode == NekoThemeMode.dark
                                      ? const Color(0xFF1A1206)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildMacroPreview() {
    final nk = context.nk;
    final newGrams =
        double.tryParse(_gramsCtrl.text.trim()) ?? widget.meal.grams;
    final oldGrams = widget.meal.grams;
    if (oldGrams == 0) return null;

    final factor = newGrams / 100.0;
    final oldFactor = oldGrams / 100.0;
    final calPer100 = widget.meal.calories / oldFactor;
    final proPer100 = widget.meal.proteins / oldFactor;
    final carbPer100 = widget.meal.carbs / oldFactor;
    final fatPer100 = widget.meal.fats / oldFactor;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: nk.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroPill(
            '${(calPer100 * factor).toStringAsFixed(0)} kcal',
            nk.amber,
          ),
          _macroPill(
            'P ${(proPer100 * factor).toStringAsFixed(1)}g',
            nk.protein,
          ),
          _macroPill(
            'C ${(carbPer100 * factor).toStringAsFixed(1)}g',
            nk.carbs,
          ),
          _macroPill('G ${(fatPer100 * factor).toStringAsFixed(1)}g', nk.fat),
        ],
      ),
    );
  }

  Widget _macroPill(String text, Color color) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: _mono(nk, size: 9, weight: FontWeight.w700, color: color),
      ),
    );
  }
}
