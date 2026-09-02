import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../models/meal_entry.dart';
import '../services/firebase_service.dart';

/// Tarjeta expandible al final del Diario que muestra el patrón histórico
/// de macros por comida del día (últimos 14 días).
///
/// Se renderiza con todos sus datos de forma lazy: la query a Firestore
/// solo se lanza cuando el usuario expande la tarjeta por primera vez,
/// sin impactar el tiempo de carga inicial del diario.
class MealMacroHistoryCard extends ConsumerStatefulWidget {
  final String uid;

  /// Comidas del día actual, agrupadas por tipo. Se usan para el insight
  /// comparativo entre el día actual y el promedio histórico.
  final Map<MealType, List<MealEntry>> todayGrouped;

  const MealMacroHistoryCard({
    super.key,
    required this.uid,
    required this.todayGrouped,
  });

  @override
  ConsumerState<MealMacroHistoryCard> createState() =>
      _MealMacroHistoryCardState();
}

class _MealMacroHistoryCardState extends ConsumerState<MealMacroHistoryCard> {
  late final FirebaseService _service = ref.read(firebaseServiceProvider);
  bool _expanded = false;
  bool _loading = false;
  bool _loaded = false;

  /// Promedio de macros por tipo de comida para los últimos 14 días.
  /// Key = MealType, Value = {calories, proteins, carbs, fats, count}.
  final Map<MealType, _MealAvg> _avgs = {};

  Future<void> _loadHistory() async {
    if (_loaded || _loading) return;
    setState(() => _loading = true);
    try {
      final since = DateTime.now().subtract(const Duration(days: 14));
      final snap = await _service.db
          .collection('users')
          .doc(widget.uid)
          .collection('meals')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      // Agrupar por (tipo, fecha) para promediar correctamente por día
      // Key: 'mealType_yyyy-MM-dd' → lista de macros de esa comida en ese día
      final byTypDay = <String, List<MealEntry>>{};
      for (final doc in snap.docs) {
        final entry = MealEntry.fromMap(doc.data(), doc.id);
        final dayKey =
            '${entry.mealType.name}_${entry.createdAt.toLocal().toString().substring(0, 10)}';
        byTypDay.putIfAbsent(dayKey, () => []).add(entry);
      }

      // Acumular sumas por tipo de comida
      final sums = <MealType, _MealAvg>{};
      for (final MealType t in MealType.values) {
        sums[t] = _MealAvg();
      }

      for (final entry in byTypDay.entries) {
        final typeStr = entry.key.split('_').first;
        final type = MealType.fromString(typeStr);
        final meals = entry.value;
        final avg = sums[type]!;
        avg.count++;
        avg.calories += meals.fold(0, (s, m) => s + m.calories);
        avg.proteins += meals.fold(0, (s, m) => s + m.proteins);
        avg.carbs += meals.fold(0, (s, m) => s + m.carbs);
        avg.fats += meals.fold(0, (s, m) => s + m.fats);
      }

      // Convertir sumas → promedios
      final result = <MealType, _MealAvg>{};
      for (final t in MealType.values) {
        final s = sums[t]!;
        if (s.count > 0) {
          result[t] = _MealAvg()
            ..count = s.count
            ..calories = s.calories / s.count
            ..proteins = s.proteins / s.count
            ..carbs = s.carbs / s.count
            ..fats = s.fats / s.count;
        }
      }

      if (mounted) {
        setState(() {
          _avgs.addAll(result);
          _loaded = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Genera el insight del gato usando lógica local.
  String _buildInsight() {
    // Buscar el patrón más relevante basado en proporciones promedio
    for (final type in [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ]) {
      final avg = _avgs[type];
      if (avg == null || avg.calories < 5) continue;

      final total = avg.proteins * 4 + avg.carbs * 4 + avg.fats * 9;
      if (total <= 0) continue;

      final proRatio = (avg.proteins * 4) / total;
      final fatRatio = (avg.fats * 9) / total;

      if (type == MealType.breakfast) {
        if (proRatio >= 0.35) {
          return '¡Tu desayuno es potente en proteína (${(proRatio * 100).round()}%)! 💪 Sigue así.';
        }
        if (proRatio < 0.15) {
          return 'Tu desayuno suele ser bajo en proteína (${(proRatio * 100).round()}%). ¿Mejoramos? 🥚';
        }
      }

      if (type == MealType.snack && fatRatio > 0.5) {
        return 'El snack aporta mucha grasa (${(fatRatio * 100).round()}%). Quizás un yogur. 🐱';
      }
    }

    // Comprobar si la cena concentra demasiadas kcal vs total del día
    final dinnerAvg = _avgs[MealType.dinner];
    final totalAvgKcal = _avgs.values.fold<double>(0, (s, a) => s + a.calories);
    if (dinnerAvg != null && totalAvgKcal > 0) {
      final dinnerFrac = dinnerAvg.calories / totalAvgKcal;
      if (dinnerFrac >= 0.45) {
        return 'La cena es tu comida más grande (${(dinnerFrac * 100).round()}% del día). ¿Redistribuimos? 🌙';
      }
    }

    if (_avgs.isEmpty) {
      return 'Aún no hay suficientes datos. ¡Sigue registrando! 🐾';
    }

    return 'Tus comidas están bien distribuidas. ¡Buen trabajo! ⭐';
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final totalDays = _avgs.isNotEmpty
        ? _avgs.values.map((a) => a.count).reduce((a, b) => a > b ? a : b)
        : 0;
    final hasData = totalDays >= 3;

    return Container(
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera tocable
          InkWell(
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadHistory();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: nk.protein.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      size: 17,
                      color: nk.protein,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patrón de tus comidas',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: nk.text,
                          ),
                        ),
                        Text(
                          'Promedio últimos 14 días',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9.5,
                            color: nk.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: nk.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contenido expandible
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: _loading
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: nk.amber,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : !hasData
                        ? _noDataHint(nk)
                        : _buildContent(nk),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _noDataHint(NekoColors nk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text('😴', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aún no hay suficientes datos (mínimo 3 días). ¡Sigue registrando!',
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

  Widget _buildContent(NekoColors nk) {
    final mealOrder = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: nk.border, height: 1),
        const SizedBox(height: 12),
        // Filas de comidas
        ...mealOrder.map((type) {
          final avg = _avgs[type];
          if (avg == null || avg.calories < 1) return const SizedBox.shrink();
          return _MealRow(type: type, avg: avg, nk: nk);
        }),
        const SizedBox(height: 14),
        // Insight del gato
        _InsightBubble(text: _buildInsight(), nk: nk),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fila de comida con mini stacked bar de macros
// ─────────────────────────────────────────────────────────────────────────────

class _MealRow extends StatelessWidget {
  final MealType type;
  final _MealAvg avg;
  final NekoColors nk;

  const _MealRow({required this.type, required this.avg, required this.nk});

  @override
  Widget build(BuildContext context) {
    final totalKcal = avg.proteins * 4 + avg.carbs * 4 + avg.fats * 9;
    final proRatio = totalKcal > 0 ? (avg.proteins * 4) / totalKcal : 0.0;
    final carbRatio = totalKcal > 0 ? (avg.carbs * 4) / totalKcal : 0.0;
    final fatRatio = totalKcal > 0 ? (avg.fats * 9) / totalKcal : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Etiqueta del tipo
          SizedBox(
            width: 68,
            child: Text(
              type.displayName,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: nk.textDim,
              ),
            ),
          ),
          // Stacked bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (proRatio > 0)
                          Expanded(
                            flex: (proRatio * 100).round(),
                            child: Container(color: nk.protein),
                          ),
                        if (carbRatio > 0)
                          Expanded(
                            flex: (carbRatio * 100).round(),
                            child: Container(color: nk.carbs),
                          ),
                        if (fatRatio > 0)
                          Expanded(
                            flex: (fatRatio * 100).round(),
                            child: Container(color: nk.fat),
                          ),
                        if ((proRatio + carbRatio + fatRatio) < 0.98)
                          Expanded(
                            flex: ((1 - proRatio - carbRatio - fatRatio) * 100)
                                .round()
                                .clamp(0, 100),
                            child: Container(color: nk.border),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'P ${(proRatio * 100).round()}%',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: nk.protein,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'C ${(carbRatio * 100).round()}%',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: nk.carbs,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'G ${(fatRatio * 100).round()}%',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: nk.fat,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Kcal promedio
          Text(
            '~${avg.calories.round()} kcal',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: nk.amber,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Burbuja de insight del gato
// ─────────────────────────────────────────────────────────────────────────────

class _InsightBubble extends StatelessWidget {
  final String text;
  final NekoColors nk;

  const _InsightBubble({required this.text, required this.nk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nk.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nk.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🐱', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                color: nk.textDim,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno de acumulación de promedios
// ─────────────────────────────────────────────────────────────────────────────

class _MealAvg {
  int count = 0;
  double calories = 0;
  double proteins = 0;
  double carbs = 0;
  double fats = 0;
}
