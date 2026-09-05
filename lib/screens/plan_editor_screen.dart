import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/nutrition_plan.dart';
import '../services/firebase_service.dart';
import '../services/nutrition_plan_service.dart';
import '../widgets/amber_atmosphere.dart';

/// Editor del plan nutricional (personalización extrema).
///
/// Disponible para usuarios NUEVOS y ANTIGUOS: crea un plan si no existe y
/// actualiza el activo en caso contrario. El plan es OPCIONAL y solo estructura
/// las comidas (tomas, ayuno, contexto) para el plan semanal con IA; NUNCA
/// reescribe las calorías ni el objetivo, que salen del cálculo clásico.
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);
  late final NutritionPlanService _service = NutritionPlanService.instance;

  bool _loading = true;
  bool _saving = false;

  // Campos del plan.
  String _phase = 'cut';
  int _durationWeeks = 8;
  int _mealsPerDay = 4;
  bool _intermittentFasting = false;
  int _fastingHours = 16;
  String? _planId;

  final _medicalController = TextEditingController();
  final _dietController = TextEditingController();
  final _mustHaveController = TextEditingController();
  final _aversionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _medicalController.dispose();
    _dietController.dispose();
    _mustHaveController.dispose();
    _aversionsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    try {
      final plan = await _service.activePlan(uid);
      if (plan != null) {
        _planId = plan.id;
        _phase = plan.phase.storageName;
        _durationWeeks = plan.durationWeeks;
        _mealsPerDay = plan.schedule.mealsPerDay;
        _intermittentFasting = plan.schedule.intermittentFasting;
        _fastingHours = plan.schedule.fastingHours > 0
            ? plan.schedule.fastingHours
            : 16;
        _medicalController.text = plan.context.medicalConditions.join(', ');
        _dietController.text = plan.context.dietaryPreferences.join(', ');
        _mustHaveController.text = plan.context.mustHaveFoods.join(', ');
        _aversionsController.text = plan.context.aversions.join(', ');
      } else {
        // Primer plan: que la fase nazca alineada con el objetivo del perfil
        // para que el plan semanal y la meta no se contradigan.
        final doc =
            await _firebase.db.collection('users').doc(uid).get();
        final goal = doc.data()?['fitnessGoal'] as String?;
        if (goal != null) {
          _phase = switch (goal) {
            'Perder peso' => 'cut',
            'Ganar músculo' => 'lean_gain',
            _ => 'maintenance',
          };
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<String> _split(TextEditingController c) => c.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await _service.saveOrUpdatePlan(
        uid: uid,
        phase: PlanPhase.fromString(_phase),
        durationWeeks: _durationWeeks,
        schedule: MealSchedule(
          mealsPerDay: _mealsPerDay,
          intermittentFasting: _intermittentFasting,
          fastingHours: _intermittentFasting ? _fastingHours : 0,
        ),
        context: NutritionContext(
          medicalConditions: _split(_medicalController),
          dietaryPreferences: _split(_dietController),
          mustHaveFoods: _split(_mustHaveController),
          aversions: _split(_aversionsController),
        ),
        planId: _planId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveProfileError('$e'))),
      );
    }
  }

  Future<void> _deletePlan() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await _service.clearPlan(uid: uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveProfileError('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: nk.amber))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTitle(l10n.extremePhaseLabel),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip('cut', l10n.extremePhaseCut),
                                _chip('maintenance', l10n.extremePhaseMaintain),
                                _chip('lean_gain', l10n.extremePhaseGain),
                                _chip('recomposition', l10n.extremePhaseRecomp),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _sectionTitle(l10n.extremeDurationLabel),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                _durationChip(4),
                                _durationChip(8),
                                _durationChip(12),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _sectionTitle(l10n.extremeMealsLabel),
                            const SizedBox(height: 4),
                            Text(
                              l10n.extremeMealsHint,
                              style: _body(nk, 12, nk.textDim),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                _mealsChip(3),
                                _mealsChip(4),
                                _mealsChip(5),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _ifSection(l10n),
                            const SizedBox(height: 28),
                            _sectionTitle(l10n.extremeContextLabel),
                            const SizedBox(height: 4),
                            Text(
                              l10n.extremeContextHint,
                              style: _body(nk, 12, nk.textDim),
                            ),
                            const SizedBox(height: 12),
                            _field(_medicalController, l10n.extremeMedicalLabel,
                                Icons.medical_information_outlined),
                            Text(l10n.extremeMedicalHint,
                                style: _hint(nk)),
                            const SizedBox(height: 16),
                            _field(_dietController, l10n.extremeDietLabel,
                                Icons.eco_outlined),
                            Text(l10n.extremeDietHint, style: _hint(nk)),
                            const SizedBox(height: 16),
                            _field(_mustHaveController, l10n.extremeMustHaveLabel,
                                Icons.favorite_border),
                            Text(l10n.extremeMustHaveHint, style: _hint(nk)),
                            const SizedBox(height: 16),
                            _field(_aversionsController, l10n.extremeAversionsLabel,
                                Icons.block),
                            Text(l10n.extremeAversionsHint, style: _hint(nk)),
                            const SizedBox(height: 28),
                            _noticeCard(l10n),
                            const SizedBox(height: 28),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: nk.mode == NekoThemeMode.dark
                                              ? const Color(0xFF1A1206)
                                              : Colors.white),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(l10n.savePlanButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: nk.amber,
                                foregroundColor: nk.mode == NekoThemeMode.dark
                                    ? const Color(0xFF1A1206)
                                    : Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            if (_planId != null) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _deletePlan,
                                icon: const Icon(Icons.delete_outline),
                                label: Text(l10n.deletePlanButton),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: nk.danger,
                                  side: BorderSide(color: nk.danger),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final nk = context.nk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: nk.text),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              l10n.extremeTitle,
              style: _display(nk, 20, nk.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    final nk = context.nk;
    return Text(text, style: _display(nk, 15, nk.text));
  }

  Widget _chip(String value, String label) {
    final nk = context.nk;
    final selected = _phase == value;
    return GestureDetector(
      onTap: () => setState(() => _phase = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(
          label,
          style: _chipText(nk, selected),
        ),
      ),
    );
  }

  Widget _durationChip(int weeks) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final selected = _durationWeeks == weeks;
    final label = switch (weeks) {
      4 => l10n.extremeW4,
      12 => l10n.extremeW12,
      _ => l10n.extremeW8,
    };
    return GestureDetector(
      onTap: () => setState(() => _durationWeeks = weeks),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(label, style: _chipText(nk, selected)),
      ),
    );
  }

  Widget _mealsChip(int meals) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final selected = _mealsPerDay == meals;
    final label = switch (meals) {
      3 => l10n.extremeMeals3,
      5 => l10n.extremeMeals5,
      _ => l10n.extremeMeals4,
    };
    return GestureDetector(
      onTap: () => setState(() => _mealsPerDay = meals),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(label, style: _chipText(nk, selected)),
      ),
    );
  }

  Widget _ifSection(AppLocalizations l10n) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.extremeIfLabel,
                        style: _display(nk, 14, nk.text)),
                    const SizedBox(height: 4),
                    Text(l10n.extremeIfDesc,
                        style: _body(nk, 12, nk.textDim)),
                  ],
                ),
              ),
              Switch(
                value: _intermittentFasting,
                activeThumbColor: nk.amber,
                onChanged: (v) => setState(() => _intermittentFasting = v),
              ),
            ],
          ),
          if (_intermittentFasting) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _fastChip(16, l10n.extremeIf16),
                _fastChip(18, l10n.extremeIf18),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fastChip(int hours, String label) {
    final nk = context.nk;
    final selected = _fastingHours == hours;
    return GestureDetector(
      onTap: () => setState(() => _fastingHours = hours),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? nk.amber : nk.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? nk.amber : nk.border),
        ),
        child: Text(label, style: _chipText(nk, selected)),
      ),
    );
  }

  Widget _field(
      TextEditingController c, String label, IconData icon) {
    final nk = context.nk;
    return TextField(
      controller: c,
      keyboardType: TextInputType.text,
      style: _body(nk, 15, nk.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _body(nk, 14, nk.textDim),
        prefixIcon: Icon(icon, color: nk.textDim),
        filled: true,
        fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _noticeCard(AppLocalizations l10n) {
    final nk = context.nk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: nk.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: nk.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.extremeNotice,
                style: _body(nk, 12, nk.textDim)),
          ),
        ],
      ),
    );
  }

  // ── Tipografía ──────────────────────────────────────────────────────────
  TextStyle _display(NekoColors nk, double size, Color color) =>
      GoogleFonts.spaceGrotesk(
          fontSize: size, fontWeight: FontWeight.w700, color: color);

  TextStyle _body(NekoColors nk, double size, Color color) =>
      GoogleFonts.dmSans(fontSize: size, color: color);

  TextStyle _hint(NekoColors nk) =>
      GoogleFonts.dmSans(fontSize: 11, color: nk.textDim);

  TextStyle _chipText(NekoColors nk, bool selected) {
    final on = nk.mode == NekoThemeMode.dark
        ? const Color(0xFF1A1206)
        : Colors.white;
    return GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: selected ? on : nk.textDim,
    );
  }
}