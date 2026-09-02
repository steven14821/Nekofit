import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../services/health_connect_service.dart';

/// Panel de actividad (Health Connect): pasos, distancia y calorías activas.
///
/// - [compact]: solo muestra el resumen de hoy en una tarjeta (Home).
/// - false: resumen + gráfica semanal de pasos (Estadísticas).
///
/// Se encarga de detectar si Health Connect está instalado, pedir permiso
/// cuando hace falta y refrescar los datos al volver a la pantalla.
class StepsSection extends ConsumerStatefulWidget {
  final bool compact;

  const StepsSection({super.key, this.compact = false});

  @override
  ConsumerState<StepsSection> createState() => _StepsSectionState();
}

class _StepsSectionState extends ConsumerState<StepsSection> {
  late final HealthConnectService _service = ref.read(
    healthConnectServiceProvider,
  );
  List<DailyActivity> _days = [];
  bool _loading = true;
  bool _available = false;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    _available = await _service.isAvailable;
    _authorized = await _service.hasPermissions();
    if (_available && _authorized) {
      _days = await _service.lastNDays(7);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _connect() async {
    final granted = await _service.requestPermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se otorgó acceso a Health Connect. Intenta de nuevo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: nk.cat),
            ),
            const SizedBox(width: 12),
            Text(
              'Cargando actividad…',
              style: TextStyle(color: nk.textDim, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!_available) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: _boxDecoration(),
        child: _messageRow(
          Icons.directions_walk_rounded,
          'Health Connect no está instalado.\nInstala la app para sincronizar tus pasos.',
        ),
      );
    }

    if (!_authorized) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            Expanded(
              child: _messageRow(
                Icons.directions_walk_rounded,
                'Conecta Health Connect para ver tus pasos, distancia y calorías activas.',
              ),
            ),
            const SizedBox(width: 12),
            _connectButton(),
          ],
        ),
      );
    }

    return widget.compact ? _buildCompact() : _buildFull();
  }

  Widget _buildCompact() {
    final nk = context.nk;
    final today = _days.isEmpty ? null : _days.last;
    final steps = today?.steps.toInt() ?? 0;
    final km = today?.distanceKm ?? 0.0;
    final kcal = today?.activeKcal.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: nk.cat.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_walk_rounded, color: nk.cat, size: 22),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatInt(steps),
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: nk.text,
                  ),
                ),
                Text(
                  'pasos hoy',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: nk.textDim,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${km.toStringAsFixed(2)} km · ${_formatInt(kcal)} kcal',
            style: TextStyle(color: nk.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFull() {
    final nk = context.nk;
    final totalSteps = _days.fold<double>(0, (s, d) => s + d.steps);
    final avgSteps = _days.isEmpty ? 0.0 : totalSteps / _days.length;
    final totalKm = _days.fold<double>(0, (s, d) => s + d.distanceKm);
    final totalKcal = _days.fold<double>(0, (s, d) => s + d.activeKcal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_walk_rounded, color: nk.cat, size: 16),
            const SizedBox(width: 6),
            Text(
              'ACTIVIDAD (7 DÍAS)',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: nk.textDim,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _statCard(
              'Pasos hoy',
              _formatInt(_days.isEmpty ? 0 : _days.last.steps.toInt()),
              'pasos',
              nk.cat,
            ),
            const SizedBox(width: 8),
            _statCard(
              'Promedio',
              _formatInt(avgSteps.toInt()),
              'pasos/día',
              nk.protein,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _statCard('Distancia', totalKm.toStringAsFixed(1), 'km', nk.carbs),
            const SizedBox(width: 8),
            _statCard(
              'Calorías activas',
              _formatInt(totalKcal.toInt()),
              'kcal',
              nk.fat,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStepsChart(),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, Color color) {
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
            Text(label, style: TextStyle(color: nk.textDim, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(color: nk.textDim, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsChart() {
    final nk = context.nk;
    if (_days.every((d) => d.steps <= 0)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _boxDecoration(),
        child: Text(
          'Aún no hay datos de pasos esta semana. Camina un poco y vuelve.',
          style: TextStyle(color: nk.textDim, fontSize: 12),
        ),
      );
    }

    final maxSteps = _days.fold<double>(0, (m, d) => d.steps > m ? d.steps : m);
    final niceMax = (maxSteps * 1.2)
        .clamp(1000.0, double.infinity)
        .roundToDouble();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: niceMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} pasos',
                  const TextStyle(color: Colors.white, fontSize: 12),
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
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  if (value % 1000 == 0) {
                    return Text(
                      '${(value / 1000).toStringAsFixed(0)}k',
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
                  if (idx >= 0 && idx < _days.length) {
                    return Text(
                      DateFormat('EEE', 'es').format(_days[idx].day),
                      style: TextStyle(color: nk.textDim, fontSize: 11),
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
            horizontalInterval: 1000,
            getDrawingHorizontalLine: (value) => FlLine(
              color: nk.divider.withValues(alpha: 0.6),
              strokeWidth: 1,
            ),
          ),
          barGroups: _days.asMap().entries.map((entry) {
            final idx = entry.key;
            final data = entry.value;
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: data.steps,
                  color: idx == _days.length - 1
                      ? nk.cat
                      : nk.cat.withValues(alpha: 0.55),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _connectButton() {
    final nk = context.nk;
    return FilledButton.icon(
      onPressed: _connect,
      style: FilledButton.styleFrom(
        backgroundColor: nk.cat,
        foregroundColor: nk.mode == NekoThemeMode.dark
            ? const Color(0xFF1A1206)
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.link_rounded, size: 18),
      label: const Text(
        'Conectar',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _messageRow(IconData icon, String message) {
    final nk = context.nk;
    return Row(
      children: [
        Icon(icon, color: nk.textDim, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: nk.textDim, fontSize: 12),
          ),
        ),
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    final nk = context.nk;
    return BoxDecoration(
      color: nk.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: nk.border),
    );
  }

  String _formatInt(int v) {
    final s = v.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
