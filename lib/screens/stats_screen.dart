import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';
import '../models/meal_entry.dart';
import '../widgets/steps_section.dart';
import 'diary_screen.dart';

/// Período visible en la pantalla de estadísticas.
///
/// - [duration]: ventana de tiempo que se pide a Firestore.
/// - [bucketCount]: cuántas barras tiene la gráfica (días o meses).
enum RangeOption {
  week(Duration(days: 7), 7),
  month(Duration(days: 30), 30),
  year(Duration(days: 365), 12);

  final Duration duration;
  final int bucketCount;

  const RangeOption(this.duration, this.bucketCount);

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case RangeOption.week:
        return l10n.statsWeek;
      case RangeOption.month:
        return l10n.statsMonth;
      case RangeOption.year:
        return l10n.statsYear;
    }
  }
}

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);

  RangeOption _range = RangeOption.week;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<_DayStats> _weekData = [];
  List<_DayStats> _prevData = [];
  List<MealEntry> _meals = [];
  List<MealEntry> _prevMeals = [];
  List<MealEntry> _streakMeals = [];
  Map<String, dynamic>? _goals;
  bool _loading = true;
  bool _error = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadStreak();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Query de comidas de la ventana del rango actual, en vivo.
  Stream<QuerySnapshot<Map<String, dynamic>>> _buildMealsStream() {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    // Traemos también el período anterior (misma longitud) para poder
    // comparar deltas. Se separan en memoria al recibir el snapshot.
    final start = DateTime.now().subtract(_range.duration * 2);
    return _firebase.db
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _subscribe() {
    _sub?.cancel();
    _error = false;
    _sub = _buildMealsStream().listen(
      (snap) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        final all = snap.docs
            .map((d) => MealEntry.fromMap(d.data(), d.id))
            .toList();
        final now = DateTime.now();
        final boundary = now.subtract(_range.duration);
        final current = all
            .where((m) => m.createdAt.isAfter(boundary))
            .toList();
        final previous = all
            .where((m) => !m.createdAt.isAfter(boundary))
            .toList();
        setState(() {
          _meals = current;
          _prevMeals = previous;
          _weekData = _aggregate(current, now, l10n);
          _prevData = _aggregate(previous, boundary, l10n);
          _loading = false;
        });
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = true;
        });
      },
    );
  }

  Future<void> _loadGoals() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      final userDoc = await _firebase.db.collection('users').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _goals = (userDoc.data()?['macroGoals'] as Map<String, dynamic>?);
      });
    } catch (_) {}
  }

  /// Estadísticas de cumplimiento de meta a partir de comidas crudas.
  ///
  /// - [onTarget]: días con registros que no superaron la meta.
  /// - [loggedDays]: días con al menos un registro.
  /// - [streak]: días consecutivos on-target terminando hoy (o ayer, si hoy
  ///   aún no tiene registros). Un día sin datos o sobre la meta corta la racha.
  ({int onTarget, int loggedDays, int streak}) _goalStats(
    List<MealEntry> meals,
    double goal,
  ) {
    final perDay = <String, double>{};
    for (final m in meals) {
      final key = DateFormat('yyyy-MM-dd').format(m.createdAt.toLocal());
      perDay[key] = (perDay[key] ?? 0) + m.calories;
    }

    final onTarget = perDay.values.where((kcal) => kcal <= goal).length;

    var cursor = DateTime.now();
    if (!perDay.containsKey(DateFormat('yyyy-MM-dd').format(cursor))) {
      // El día de hoy aún está en curso: la racha arranca desde ayer.
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    for (var i = 0; i < 60; i++) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      final kcal = perDay[key];
      if (kcal == null || kcal > goal) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (onTarget: onTarget, loggedDays: perDay.length, streak: streak);
  }

  /// Carga la ventana de 60 días usada para la racha actual.
  ///
  /// Es una ventana fija e independiente del rango visible: así la racha
  /// no se corta artificialmente en el borde de la semana/mes y no hay que
  /// descargar el período entero solo para contar días consecutivos.
  Future<void> _loadStreak() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      final start = DateTime.now().subtract(const Duration(days: 60));
      final snap = await _firebase.db
          .collection('users')
          .doc(uid)
          .collection('meals')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('createdAt', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _streakMeals = snap.docs
            .map((d) => MealEntry.fromMap(d.data(), d.id))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await _loadGoals();
    if (!mounted) return;
    await _loadStreak();
    if (!mounted) return;
    setState(() => _refreshKey++);
    _subscribe();
  }

  /// Abre el Diario Alimentario en la fecha de la barra tocada.
  void _openDiaryFor(DateTime date) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DiaryScreen(initialDate: date)));
  }

  /// Muestra un resumen mensual profesional cuando se toca una barra en vista de año.
  void _showMonthlySummary(_DayStats month) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final monthName = _monthLabel(l10n, month.date);
    final isCurrentMonth = month.date.year == DateTime.now().year && month.date.month == DateTime.now().month;
    
    // Calcular promedios diarios del mes
    final daysInMonth = DateTime(month.date.year, month.date.month + 1, 0).day;
    final daysWithMeals = _meals.where((m) {
      final d = m.createdAt.toLocal();
      return d.year == month.date.year && d.month == month.date.month;
    }).map((m) => m.createdAt.toLocal().day).toSet().length;
    
    final avgCal = daysWithMeals > 0 ? month.calories / daysWithMeals : 0.0;
    final avgProt = daysWithMeals > 0 ? month.proteins / daysWithMeals : 0.0;
    final avgCarbs = daysWithMeals > 0 ? month.carbs / daysWithMeals : 0.0;
    final avgFats = daysWithMeals > 0 ? month.fats / daysWithMeals : 0.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: nk.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: nk.textFaint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: nk.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month_rounded, color: nk.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$monthName ${month.date.year}',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: nk.text,
                          ),
                        ),
                        Text(
                          isCurrentMonth ? 'Mes actual' : 'Mes anterior',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 11,
                            color: nk.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Total del mes
              _buildMonthStatCard(
                nk: nk,
                icon: Icons.local_fire_department_rounded,
                iconColor: nk.amber,
                label: 'CALORÍAS TOTALES',
                value: '${month.calories.round()}',
                unit: 'kcal',
                subtitle: 'Promedio: ${avgCal.round()} kcal/día',
              ),
              const SizedBox(height: 12),
              
              // Macros
              Row(
                children: [
                  Expanded(child: _buildMonthMacroCard(nk, 'PROTEÍNA', '${month.proteins.round()}g', avgProt, nk.protein)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMonthMacroCard(nk, 'CARBOS', '${month.carbs.round()}g', avgCarbs, nk.carbs)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMonthMacroCard(nk, 'GRASAS', '${month.fats.round()}g', avgFats, nk.fat)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Resumen
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: nk.surfaceHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUMEN',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: nk.textFaint,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(nk, 'Total comidas', month.mealCount.toString()),
                    _buildSummaryRow(nk, 'Días con datos', '$daysWithMeals de $daysInMonth'),
                    _buildSummaryRow(nk, 'Promedio comidas/día', '${(month.mealCount / math.max(1, daysWithMeals)).toStringAsFixed(1)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Botón ver diario
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openDiaryFor(DateTime(month.date.year, month.date.month, 1));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nk.amber,
                    foregroundColor: nk.mode == NekoThemeMode.dark ? const Color(0xFF1A1206) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Ver en Diario',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra un resumen semanal profesional cuando se toca una barra en la
  /// vista de mes (cada barra es una semana calendario).
  void _showWeeklySummary(_DayStats week) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final weekStart = week.date;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final today = DateTime.now();
    final isCurrentWeek = !today.isBefore(weekStart) && !today.isAfter(weekEnd);

    // Días con registros dentro de la semana (a nivel de día, no de bucket).
    final inWeek = _meals.where((m) {
      final d = m.createdAt.toLocal();
      return !d.isBefore(weekStart) && d.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();
    final daysWithMeals = inWeek
        .map((m) => DateFormat('yyyy-MM-dd').format(m.createdAt.toLocal()))
        .toSet()
        .length;

    final avgCal = daysWithMeals > 0 ? week.calories / daysWithMeals : 0.0;
    final avgProt = daysWithMeals > 0 ? week.proteins / daysWithMeals : 0.0;
    final avgCarbs = daysWithMeals > 0 ? week.carbs / daysWithMeals : 0.0;
    final avgFats = daysWithMeals > 0 ? week.fats / daysWithMeals : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: nk.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: nk.textFaint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: nk.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_view_week_rounded,
                      color: nk.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${weekStart.day} ${_monthLabel(l10n, weekStart)} – '
                          '${weekEnd.day} ${_monthLabel(l10n, weekEnd)}',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: nk.text,
                          ),
                        ),
                        Text(
                          isCurrentWeek ? 'Semana actual' : 'Semana anterior',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 11,
                            color: nk.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Total de la semana
              _buildMonthStatCard(
                nk: nk,
                icon: Icons.local_fire_department_rounded,
                iconColor: nk.amber,
                label: 'CALORÍAS DE LA SEMANA',
                value: '${week.calories.round()}',
                unit: 'kcal',
                subtitle: 'Promedio: ${avgCal.round()} kcal/día',
              ),
              const SizedBox(height: 12),

              // Macros
              Row(
                children: [
                  Expanded(
                    child: _buildMonthMacroCard(
                        nk, 'PROTEÍNA', '${week.proteins.round()}g', avgProt, nk.protein),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMonthMacroCard(
                        nk, 'CARBOS', '${week.carbs.round()}g', avgCarbs, nk.carbs),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMonthMacroCard(
                        nk, 'GRASAS', '${week.fats.round()}g', avgFats, nk.fat),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Resumen
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: nk.surfaceHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUMEN',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: nk.textFaint,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(nk, 'Total comidas', week.mealCount.toString()),
                    _buildSummaryRow(nk, 'Días con datos', '$daysWithMeals de 7'),
                    _buildSummaryRow(
                      nk,
                      'Promedio comidas/día',
                      '${(week.mealCount / math.max(1, daysWithMeals)).toStringAsFixed(1)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botón ver diario
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openDiaryFor(weekStart);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nk.amber,
                    foregroundColor: nk.mode == NekoThemeMode.dark
                        ? const Color(0xFF1A1206)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Ver en Diario',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthStatCard({
    required NekoColors nk,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, fontWeight: FontWeight.w600, color: nk.textFaint, letterSpacing: 1)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 28, fontWeight: FontWeight.w700, color: nk.text)),
                    const SizedBox(width: 4),
                    Text(unit, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: nk.textFaint)),
                  ],
                ),
                Text(subtitle, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: nk.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthMacroCard(NekoColors nk, String label, String total, double avg, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, fontWeight: FontWeight.w600, color: nk.textFaint, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(total, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text('${avg.round()}/día', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: nk.textFaint)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(NekoColors nk, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: AppFonts.sans, fontSize: 13, color: nk.textDim)),
          Text(value, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13, fontWeight: FontWeight.w600, color: nk.text)),
        ],
      ),
    );
  }

  void _setRange(RangeOption range) {
    if (range == _range) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _range = range;
      // Re-emboqueta con los datos que ya tenemos para no parpadear;
      // el nuevo snapshot del stream lo reemplaza en seguida.
      final now = DateTime.now();
      final boundary = now.subtract(_range.duration);
      final current = _meals
          .where((m) => m.createdAt.isAfter(boundary))
          .toList();
      final previous = _meals
          .where((m) => !m.createdAt.isAfter(boundary))
          .toList();
      _weekData = _aggregate(current, now, l10n);
      _prevData = _aggregate(previous, boundary, l10n);
      _prevMeals = previous;
    });
    _subscribe();
  }

  /// Agrupa las comidas por día (semana), por semana calendario (mes) o por
  /// mes (año), siempre completando los buckets vacíos del período para que
  /// la gráfica muestre el rango completo.
  List<_DayStats> _aggregate(List<MealEntry> meals, DateTime now, AppLocalizations l10n) {
    final isYear = _range == RangeOption.year;
    final isMonth = _range == RangeOption.month;
    final buckets = <String, _DayStats>{};

    if (isYear) {
      // Buckets por mes.
      for (int i = _range.bucketCount - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i);
        final key = DateFormat('yyyy-MM').format(date);
        buckets[key] = _DayStats(
          date: date,
          label: _monthLabel(l10n, date).toUpperCase(),
        );
      }
      for (final meal in meals) {
        final key = DateFormat('yyyy-MM').format(meal.createdAt.toLocal());
        final b = buckets[key];
        if (b != null) _addToBucket(b, meal);
      }
    } else if (isMonth) {
      // Buckets por semana calendario (lunes a domingo) dentro de la ventana.
      final start = now.subtract(Duration(days: _range.bucketCount - 1));
      for (var day = start;
          !day.isAfter(now);
          day = day.add(const Duration(days: 1))) {
        final weekStart = day.subtract(Duration(days: day.weekday - 1));
        final key = DateFormat('yyyy-MM-dd').format(weekStart);
        if (buckets.containsKey(key)) continue;
        final weekEnd = weekStart.add(const Duration(days: 6));
        buckets[key] = _DayStats(
          date: weekStart,
          label: '${weekStart.day}–${weekEnd.day}',
        );
      }
      for (final meal in meals) {
        final local = meal.createdAt.toLocal();
        final weekStart = local.subtract(Duration(days: local.weekday - 1));
        final key = DateFormat('yyyy-MM-dd').format(weekStart);
        final b = buckets[key];
        if (b != null) _addToBucket(b, meal);
      }
    } else {
      // Buckets diarios (semana).
      for (int i = _range.bucketCount - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        buckets[key] = _DayStats(
          date: date,
          label: _weekdayLabel(l10n, date).toUpperCase(),
        );
      }
      for (final meal in meals) {
        final key = DateFormat('yyyy-MM-dd').format(meal.createdAt.toLocal());
        final b = buckets[key];
        if (b != null) _addToBucket(b, meal);
      }
    }

    return buckets.values.toList();
  }

  void _addToBucket(_DayStats b, MealEntry meal) {
    b.calories += meal.calories;
    b.proteins += meal.proteins;
    b.carbs += meal.carbs;
    b.fats += meal.fats;
    b.mealCount++;
  }

  String _monthLabel(AppLocalizations l10n, DateTime date) {
    switch (date.month) {
      case 1:
        return l10n.statsMonthJan;
      case 2:
        return l10n.statsMonthFeb;
      case 3:
        return l10n.statsMonthMar;
      case 4:
        return l10n.statsMonthApr;
      case 5:
        return l10n.statsMonthMay;
      case 6:
        return l10n.statsMonthJun;
      case 7:
        return l10n.statsMonthJul;
      case 8:
        return l10n.statsMonthAug;
      case 9:
        return l10n.statsMonthSep;
      case 10:
        return l10n.statsMonthOct;
      case 11:
        return l10n.statsMonthNov;
      default:
        return l10n.statsMonthDec;
    }
  }

  String _weekdayLabel(AppLocalizations l10n, DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return l10n.statsWeekdayMon;
      case DateTime.tuesday:
        return l10n.statsWeekdayTue;
      case DateTime.wednesday:
        return l10n.statsWeekdayWed;
      case DateTime.thursday:
        return l10n.statsWeekdayThu;
      case DateTime.friday:
        return l10n.statsWeekdayFri;
      case DateTime.saturday:
        return l10n.statsWeekdaySat;
      default:
        return l10n.statsWeekdaySun;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    if (_loading) {
      return Scaffold(
        backgroundColor: nk.bg,
        body: Center(child: CircularProgressIndicator(color: nk.amber)),
      );
    }

    return Scaffold(
      backgroundColor: nk.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _error
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: nk.amber,
                      child: KeyedSubtree(
                        key: ValueKey(_refreshKey),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildSummaryCards(),
                            const SizedBox(height: 20),
                            const StepsSection(),
                            const SizedBox(height: 20),
                            _buildWeeklyChart(),
                            const SizedBox(height: 20),
                            _buildRecentMeals(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: nk.textDim, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.statsError,
              textAlign: TextAlign.center,
              style: TextStyle(color: nk.textDim, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: nk.amber,
                foregroundColor: nk.mode == NekoThemeMode.dark
                    ? const Color(0xFF1A1206)
                    : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = false;
                });
                _subscribe();
                _loadGoals();
                _loadStreak();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: nk.text),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.statsTitle,
                style: TextStyle(
                  color: nk.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildRangeSelector(),
          ),
        ],
      ),
    );
  }

  /// Selector de rango en pills (mismo lenguaje que los tabs de la despensa).
  Widget _buildRangeSelector() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        children: RangeOption.values.map((option) {
          final selected = _range == option;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setRange(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? nk.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  option.localizedLabel(l10n),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? (nk.mode == NekoThemeMode.dark
                              ? const Color(0xFF1A1206)
                              : Colors.white)
                        : nk.textDim,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final totalCal = _weekData.fold(0.0, (s, d) => s + d.calories);
    final totalProt = _weekData.fold(0.0, (s, d) => s + d.proteins);
    final totalCarbs = _weekData.fold(0.0, (s, d) => s + d.carbs);
    final totalFats = _weekData.fold(0.0, (s, d) => s + d.fats);

    // Promedio solo sobre los días que realmente tienen registros:
    // dividir entre el total de días del período inflaría el promedio
    // cuando el usuario no ha logueado todos los días. Se cuenta a nivel
    // de día (no de bucket) porque el mes se agrupa por semanas.
    final loggedDays = _meals
        .map((m) => DateFormat('yyyy-MM-dd').format(m.createdAt.toLocal()))
        .toSet()
        .length;
    final avgCal = loggedDays > 0 ? totalCal / loggedDays : 0.0;

    // Período anterior (misma longitud) para las comparativas ▲/▼.
    final prevTotalCal = _prevData.fold(0.0, (s, d) => s + d.calories);
    final prevTotalProt = _prevData.fold(0.0, (s, d) => s + d.proteins);
    final prevTotalCarbs = _prevData.fold(0.0, (s, d) => s + d.carbs);
    final prevTotalFats = _prevData.fold(0.0, (s, d) => s + d.fats);
    final prevLoggedDays = _prevMeals
        .map((m) => DateFormat('yyyy-MM-dd').format(m.createdAt.toLocal()))
        .toSet()
        .length;
    final prevAvgCal = prevLoggedDays > 0 ? prevTotalCal / prevLoggedDays : 0.0;

    // Meta y racha.
    final calGoal = ((_goals?['calories'] as num?) ?? 2000.0).toDouble();
    final goalStats = _goalStats(_meals, calGoal);
    final streak = _goalStats(_streakMeals, calGoal).streak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statsPeriodSummary,
          style: TextStyle(
            color: nk.textDim,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatCard(
              l10n.statsCalPerDay,
              '${avgCal.toInt()}',
              'kcal',
              nk.amber,
              delta: _pctChange(avgCal, prevAvgCal),
              goodWhenUp: false,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              l10n.profileProtein,
              '${totalProt.toInt()}',
              'g',
              nk.protein,
              delta: _pctChange(totalProt, prevTotalProt),
              goodWhenUp: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatCard(
              l10n.profileCarbs,
              '${totalCarbs.toInt()}',
              'g',
              nk.carbs,
              delta: _pctChange(totalCarbs, prevTotalCarbs),
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              l10n.profileFats,
              '${totalFats.toInt()}',
              'g',
              nk.fat,
              delta: _pctChange(totalFats, prevTotalFats),
              goodWhenUp: false,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildGoalTile(
              icon: Icons.flag_rounded,
              color: nk.ok,
              label: l10n.statsOnTargetDays,
              value: '${goalStats.onTarget}',
              unit: l10n.statsOnTargetUnit(loggedDays),
              progress: loggedDays > 0 ? goalStats.onTarget / loggedDays : 0.0,
            ),
            const SizedBox(width: 8),
            _buildGoalTile(
              icon: Icons.local_fire_department_rounded,
              color: nk.amber,
              label: l10n.statsCurrentStreak,
              value: '$streak',
              unit: l10n.statsDays,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loggedDays == 0
              ? l10n.statsNoRecords
              : _range == RangeOption.year
              ? l10n.statsYearSummary(loggedDays, calGoal.toInt())
              : l10n.statsPeriodSummaryDetail(
                  loggedDays,
                  _range == RangeOption.month ? 30 : _weekData.length,
                  calGoal.toInt()),
          style: TextStyle(color: nk.textDim, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String unit,
    Color color, {
    double? delta,
    bool? goodWhenUp,
  }) {
    final nk = context.nk;
    final deltaChip = delta != null
        ? _buildDeltaChip(delta, goodWhenUp: goodWhenUp)
        : null;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: nk.textDim, fontSize: 12),
                  ),
                ),
                if (deltaChip != null) ...[const SizedBox(width: 4), deltaChip],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(color: nk.textDim, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Cambio porcentual entre el período actual y el anterior.
  /// Devuelve null cuando no hay base de comparación (período anterior vacío).
  double? _pctChange(double current, double previous) {
    if (previous <= 0) return null;
    return ((current - previous) / previous) * 100;
  }

  /// Chip compacto ▲/▼ con el % de cambio.
  ///
  /// [goodWhenUp]: true → subir es bueno (verde al subir, gris al bajar),
  /// false → bajar es bueno (verde al bajar), null → neutro (siempre gris).
  Widget? _buildDeltaChip(double pct, {bool? goodWhenUp}) {
    if (pct.abs() < 0.5) return null;
    final nk = context.nk;
    final up = pct > 0;
    final Color color;
    if (goodWhenUp == null) {
      color = nk.textDim;
    } else {
      color = (up == goodWhenUp) ? nk.ok : nk.textDim;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${up ? '▲' : '▼'}${pct.abs().toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Calcula un intervalo "bonito" para el eje Y (100, 200, 500, 1000…)
  /// según el máximo del gráfico.
  double _niceStep(double maxY) {
    final rough = maxY / 4;
    if (rough <= 0) return 1.0;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    final nice = norm <= 1
        ? 1.0
        : norm <= 2
        ? 2.0
        : norm <= 5
        ? 5.0
        : 10.0;
    return nice * mag;
  }

  /// Tile compacto para métricas de meta (días on-target / racha).
  /// Icono + valor grande + barra de progreso opcional.
  Widget _buildGoalTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
    double? progress,
  }) {
    final nk = context.nk;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: nk.textDim, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(color: nk.textDim, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 4,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAxisValue(double value) {
    if (value >= 10000) return '${(value / 1000).round()}k';
    return '${value.toInt()}';
  }

  Widget _buildWeeklyChart() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final calGoal = ((_goals?['calories'] as num?) ?? 2000.0).toDouble();

    // La meta solo tiene sentido contra barras de la misma escala: diaria
    // en semana, semanal en mes. En el año las barras son totales mensuales.
    final showGoal = _range != RangeOption.year;
    final goalRef = _range == RangeOption.month ? calGoal * 7 : calGoal;
    final maxData = _weekData.fold<double>(
      0,
      (m, d) => d.calories > m ? d.calories : m,
    );
    final maxY = showGoal
        ? (maxData > goalRef ? maxData : goalRef) * 1.25
        : (maxData > 0 ? maxData * 1.2 : 100.0);
    final leftInterval = _niceStep(maxY);
    final barWidth = switch (_range) {
      RangeOption.week => 20.0,
      RangeOption.month => 26.0,
      RangeOption.year => 26.0,
    };
    // En el mes las barras ya son semanas (4-5), así que se etiquetan todas.
    final bottomStep = 1;

    final title = switch (_range) {
      RangeOption.week => l10n.statsCaloriesWeek,
      RangeOption.month => l10n.statsCaloriesMonth,
      RangeOption.year => l10n.statsCaloriesYear,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: nk.textDim,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: nk.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: nk.border),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  // Tap corto en una barra → abre el diario en esa fecha.
                  // En vista de año muestra resumen mensual y en mes, semanal.
                  if (event is FlTapUpEvent &&
                      response != null &&
                      response.spot != null) {
                    final idx = response.spot!.touchedBarGroupIndex;
                    if (idx >= 0 && idx < _weekData.length) {
                      if (_range == RangeOption.year) {
                        _showMonthlySummary(_weekData[idx]);
                      } else if (_range == RangeOption.month) {
                        _showWeeklySummary(_weekData[idx]);
                      } else {
                        _openDiaryFor(_weekData[idx].date);
                      }
                    }
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} kcal',
                      TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: leftInterval,
                    getTitlesWidget: (value, meta) {
                      if (showGoal && (value - goalRef).abs() < 1) {
                        return Text(
                          l10n.statsGoal,
                          style: TextStyle(color: nk.amber, fontSize: 10),
                        );
                      }
                      if (value % leftInterval == 0) {
                        return Text(
                          _formatAxisValue(value),
                          style: TextStyle(color: nk.textDim, fontSize: 10),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 &&
                          idx < _weekData.length &&
                          idx % bottomStep == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _weekData[idx].label,
                            style: TextStyle(color: nk.textDim, fontSize: 11),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: leftInterval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: nk.divider.withValues(alpha: 0.6),
                  strokeWidth: 1,
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: showGoal
                    ? [
                        HorizontalLine(
                          y: goalRef,
                          color: nk.amber.withValues(alpha: 0.5),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ]
                    : [],
              ),
              barGroups: _weekData.asMap().entries.map((entry) {
                final idx = entry.key;
                final data = entry.value;
                final isOver = data.calories > goalRef;
                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: data.calories,
                      color: isOver ? nk.fat : nk.amber,
                      width: barWidth,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: showGoal,
                        toY: goalRef,
                        color: nk.surfaceHigh.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMeals() {
    if (_meals.isEmpty) {
      return const SizedBox();
    }

    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statsRecentMeals,
          style: TextStyle(
            color: nk.textDim,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...(_meals.take(10).map((meal) => _buildMealItem(meal))),
      ],
    );
  }

  Widget _buildMealItem(MealEntry meal) {
    final nk = context.nk;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _mealTypeColor(meal.mealType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _mealTypeIcon(meal.mealType),
              color: _mealTypeColor(meal.mealType),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.foodName,
                  style: TextStyle(color: nk.text, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${meal.grams.toInt()}g · ${DateFormat('HH:mm').format(meal.createdAt)}',
                  style: TextStyle(color: nk.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${meal.calories.toInt()} kcal',
            style: TextStyle(
              color: nk.amber,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _mealTypeColor(MealType type) {
    final nk = context.nk;
    switch (type) {
      case MealType.breakfast:
        return nk.warn;
      case MealType.lunch:
        return nk.ok;
      case MealType.dinner:
        return const Color(0xFF7E57C2);
      case MealType.snack:
        return nk.amber;
    }
  }

  IconData _mealTypeIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_rounded;
      case MealType.lunch:
        return Icons.restaurant_rounded;
      case MealType.dinner:
        return Icons.nights_stay_rounded;
      case MealType.snack:
        return Icons.fastfood_rounded;
    }
  }
}

class _DayStats {
  final DateTime date;
  final String label;
  double calories = 0;
  double proteins = 0;
  double carbs = 0;
  double fats = 0;
  int mealCount = 0;

  _DayStats({required this.date, required this.label});
}
