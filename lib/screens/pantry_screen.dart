import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import '../core/haptics.dart';
import '../core/providers.dart';
import '../core/neko_palette.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';
import '../services/inventory_estimator_service.dart';
import '../models/pantry_item.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/hanko_button.dart';
import '../widgets/hanko_stamp.dart';
import '../widgets/neko_alert.dart';
import '../widgets/neko_cat_mascot.dart';
import '../widgets/neko_speech_bubble.dart';
import '../widgets/neko_skeleton.dart';
import '../widgets/neko_tour.dart';
import '../widgets/pantry_image_placeholder.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'product_edit_screen.dart';
import 'shopping_plan_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
  late final FirebaseService _firebaseService = ref.read(
    firebaseServiceProvider,
  );
  final InventoryEstimatorService _estimator = InventoryEstimatorService();
  final List<_Category> _categories = const [
    _Category('Proteínas'),
    _Category('Carbohidratos'),
    _Category('Grasas'),
    _Category('Vegetales'),
    _Category('Lácteos/Huevos'),
  ];

  Map<String, InventoryEstimate> _estimates = {};
  String _lastEstimateKey = '';
  Map<String, dynamic>? _profileData;
  bool _profileLoaded = false;
  late TabController _tabController;

  String _categoryLabel(AppLocalizations l10n, _Category cat) {
    return switch (cat.name) {
      'Proteínas' => l10n.categoryProteins,
      'Carbohidratos' => l10n.categoryCarbs,
      'Grasas' => l10n.categoryFats,
      'Vegetales' => l10n.categoryVegetables,
      'Lácteos/Huevos' => l10n.categoryDairyEggs,
      _ => cat.name,
    };
  }

  // ── Tour contextual (primera vez) ──
  final _calendarKey = GlobalKey();
  final _tabsKey = GlobalKey();
  final _agotadosKey = GlobalKey();
  final _scanCtaKey = GlobalKey(); // CTA del estado vacío
  final _searchCtaKey = GlobalKey(); // CTA secundaria del estado vacío
  bool _tourLaunched = false;
  int _tourAttempts = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    // Haptic feedback al cambiar de pestaña (drag o tap)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        Haptics.select();
      }
    });
    _checkForUpdate();
    _loadProfile();
  }

  @override
  void dispose() {
    NekoTour.dismissAll();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(streakServiceProvider).checkStreakOnAppLaunch(uid);
      final snap = await _firebaseService.db.collection('users').doc(uid).get();
      if (!mounted) return;
      final data = snap.data();
      setState(() {
        _profileData = data;
        _profileLoaded = true;
      });

      final catName = data?['catName'] as String?;
      if (catName == null || catName.trim().isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _promptCatNameForLegacyUser(uid);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _profileLoaded = true);
    }
  }

  Future<void> _promptCatNameForLegacyUser(String uid) async {
    final nk = context.nk;
    final nt = context.nt;
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: 'Mochi');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: nk.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const NekoCatMascot(size: 90, showLabel: false),
            const SizedBox(height: 12),
            Text(
              l10n.pantryCatNameTitle,
              style: _display(size: 20, color: nk.text),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.pantryCatNameBody,
              style: _body(size: 13, color: nk.textDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 12,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              style: TextStyle(color: nk.text, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: l10n.pantryCatNameLabel,
                labelStyle: TextStyle(color: nt.onAmber.withValues(alpha: 0.6)),
                hintText: l10n.petNameHint,
                filled: true,
                fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: nk.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: nk.amber, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final chosenName = controller.text.trim().isEmpty
                  ? 'Mochi'
                  : controller.text.trim();
              await _firebaseService.db.collection('users').doc(uid).set({
                'catName': chosenName,
                'catStyle': 'default',
              }, SetOptions(merge: true));

              if (mounted) {
                setState(() {
                  _profileData ??= {};
                  _profileData!['catName'] = chosenName;
                });
              }
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: nk.amber,
              foregroundColor: nt.onAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l10n.pantrySaveName,
              style: TextStyle(color: nt.onAmber, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Flexible update: descarga en background, se aplica al reiniciar
        await InAppUpdate.startFlexibleUpdate();
      }
    } catch (e) {
      // Silenciar errores — solo funciona en Play Store
    }
  }

  Future<void> _computeEstimates(String uid, List<PantryItem> items) async {
    try {
      // Skip if items haven't changed (avoids infinite rebuild loop)
      final key = items.map((i) => '${i.id}:${i.quantity}').join(',');
      if (key == _lastEstimateKey) return;
      _lastEstimateKey = key;

      final itemMaps = items
          .map((i) => {'id': i.id, 'quantity': i.quantity})
          .toList();
      final results = await _estimator.estimateAll(
        uid: uid,
        pantryItems: itemMaps,
      );
      if (!mounted) return;
      setState(() {
        _estimates = {for (final e in results) e.pantryItemId: e};
      });
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Acciones de inventario
  //
  // RF-5 (Reposición Rápida) y RF-4 (Estados). Cada acción es atómica: cambia
  // solo la bandera de disponibilidad y el timestamp. RNF-3 prohíbe duplicar
  // filas o añadir subcolecciones para esto.
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _replenish(PantryItem item) async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid == null || item.isAvailable) return;
    await _firebaseService.db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .doc(item.id)
        .update({
          'isAvailable': true,
          'quantity': item.originalQuantity ?? item.quantity,
          'lastReplenished': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    // Burbuja manga de corazón + sello hanko cayendo con física
    final l10n = AppLocalizations.of(context);
    NekoAlert.heart(context, l10n.pantryItemReplenished(item.name));
    HankoStamp.show(context, kind: HankoStampKind.replenish);
  }

  Future<void> _deplete(PantryItem item) async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid == null || !item.isAvailable) return;
    // Nota: NO se toca `lastReplenished` aquí. Marcar un producto como
    // agotado no es reabastecerlo; reescribir ese timestamp corrompe el
    // predictivo de la notificación inteligente de las 20:00 (RF-9), que
    // cuenta los días desde el último reabastecimiento para avisar.
    await _firebaseService.db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .doc(item.id)
        .update({'isAvailable': false});
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    NekoAlert.jagged(context, l10n.pantryItemDepleted(item.name));
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Logout — limpia la sesión de Firebase y vuelve al login.
  // El authState de Firebase hace que cualquier ruta protegida debería redirigir,
  // pero por seguridad hacemos pushAndRemoveUntil explícito.
  // ────────────────────────────────────────────────────────────────────────────

  // ────────────────────────────────────────────────────────────────────────────
  // Header — emblema con el gato
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic>? profileData) {
    final nk = context.nk;
    final nt = context.nt;
    final l10n = AppLocalizations.of(context);
    final goals = profileData?['macroGoals'] as Map<String, dynamic>?;
    final caloriesGoal = goals?['calories'] as double? ?? 2000.0;
    final proteins = goals?['proteins'] as double?;
    final carbs = goals?['carbs'] as double?;
    final fats = goals?['fats'] as double?;

    return Container(
      decoration: nk.mode == NekoThemeMode.dark
          ? BoxDecoration(gradient: nt.headerGradient)
          : null,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.navPantry.toUpperCase(),
                style: _display(
                  size: 20,
                  weight: FontWeight.w700,
                  color: nk.text,
                  letterSpacing: -0.4,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    key: _calendarKey,
                    icon: Icon(Icons.calendar_month_rounded, color: nk.textDim),
                    tooltip: l10n.pantryCalendarTooltip,
                    onPressed: () {
                      Haptics.tap();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShoppingPlanScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: nk.textDim,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanScreen()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: nk.textDim),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Emblema de meta calórica
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: nk.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: nk.amber.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: nk.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: nk.amber.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.bolt_rounded, color: nk.amber, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pantryDailyGoal,
                        style: _mono(
                          size: 10,
                          weight: FontWeight.w700,
                          color: nk.textFaint,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${caloriesGoal.toStringAsFixed(0)} kcal',
                        style: _display(
                          size: 26,
                          weight: FontWeight.w700,
                          color: nk.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (proteins != null && carbs != null && fats != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _miniMetaLine('P', proteins, nk.protein),
                      _miniMetaLine('C', carbs, nk.carbs),
                      _miniMetaLine('G', fats, nk.fat),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetaLine(String label, double v, Color color) {
    final nk = context.nk;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label  ${v.toStringAsFixed(0)}g',
            style: _mono(size: 11, weight: FontWeight.w700, color: nk.textDim),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tarjeta bento de producto
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildPantryCard(PantryItem item, bool isAvailable) {
    final nk = context.nk;
    final nt = context.nt;
    final catColor = nt.ofCategory(item.category);
    final cardColor = isAvailable
        ? nk.surface
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.35), nk.surface);

    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Haptics.tap();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductEditScreen(item: item)),
          );
        },
        onLongPress: () {
          Haptics.success();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductEditScreen(item: item)),
          );
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: catColor.withValues(alpha: 0.12),
        highlightColor: catColor.withValues(alpha: 0.06),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: catColor.withValues(alpha: isAvailable ? 0.30 : 0.12),
              width: 1,
            ),
            boxShadow: nk.mode == NekoThemeMode.dark
                ? const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(item, catColor),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: _display(
                                size: 15.5,
                                weight: FontWeight.w600,
                                color: nk.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAvailable && _estimates[item.id] != null)
                            _buildEstimateBadge(_estimates[item.id]!),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: nk.surfaceHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.quantity,
                              style: _mono(
                                size: 11,
                                weight: FontWeight.w700,
                                color: nk.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Macros en monoespaciada gigante
                      Row(
                        children: [
                          _macroNumber(
                            'CAL',
                            item.calories.toStringAsFixed(0),
                            catColor,
                          ),
                          const SizedBox(width: 16),
                          _macroNumber(
                            'P',
                            '${item.proteins.toStringAsFixed(0)}g',
                            nk.protein,
                          ),
                          const SizedBox(width: 16),
                          _macroNumber(
                            'C',
                            '${item.carbs.toStringAsFixed(0)}g',
                            nk.carbs,
                          ),
                          const SizedBox(width: 16),
                          _macroNumber(
                            'G',
                            '${item.fats.toStringAsFixed(0)}g',
                            nk.fat,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                // Acción: hanko reabastecer / agotar
                _buildActionButton(item),
              ],
            ),
          ),
        ),
      ),
    );

    // Estado agotado: desaturación + rotación 0.5° (sello viejo)
    if (!isAvailable) {
      card = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          0.55,
          0,
        ]),
        child: Transform.rotate(
          angle: -0.0087, // ~0.5°
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildEstimateBadge(InventoryEstimate estimate) {
    if (estimate.dailyConsumption <= 0) return const SizedBox.shrink();

    Color bgColor;
    Color textColor;
    String text;

    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    if (estimate.isCritical) {
      bgColor = nk.danger.withValues(alpha: 0.15);
      textColor = nk.danger;
      text = l10n.pantryToday;
    } else if (estimate.isWarning) {
      bgColor = nk.warn.withValues(alpha: 0.15);
      textColor = nk.warn;
      text = '${estimate.estimatedDaysLeft}d';
    } else {
      bgColor = nk.ok.withValues(alpha: 0.12);
      textColor = nk.ok;
      text = '${estimate.estimatedDaysLeft}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: _mono(size: 9, weight: FontWeight.w700, color: textColor),
      ),
    );
  }

  /// Miniatura: si el producto tiene foto subida a Storage, la muestra;
  /// si no, el placeholder por categoría (Smart Label) para que todos los
  /// productos sin foto se vean consistentes.
  Widget _buildThumbnail(PantryItem item, Color catColor) {
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final nk = context.nk;
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 56,
          height: 56,
          color: nk.surfaceHigh,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                PantryImagePlaceholder(item: item, size: 56),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return PantryImagePlaceholder(item: item, size: 56);
            },
          ),
        ),
      );
    }
    return PantryImagePlaceholder(item: item, size: 56);
  }

  Widget _macroNumber(String label, String value, Color color) {
    final nk = context.nk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _mono(
            size: 9,
            weight: FontWeight.w700,
            color: nk.textFaint,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: _mono(size: 22, weight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildActionButton(PantryItem item) {
    if (item.isAvailable) {
      return HankoButton.deplete(onPressed: () => _deplete(item));
    }
    return HankoButton.replenish(onPressed: () => _replenish(item));
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Estado vacío (sin datos) — el gato durmiendo en su caja vacía.
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final nk = context.nk;
    final nt = context.nt;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(null),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCatInBox(),
                        const SizedBox(height: 20),
                        Text(
                          l10n.pantryEmptyTitle,
                          style: _display(
                            size: 26,
                            weight: FontWeight.w700,
                            color: nk.text,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.pantryEmptyBody,
                          style: _body(size: 14, color: nk.textDim),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        // CTA principal: escanear
                        GestureDetector(
                          key: _scanCtaKey,
                          onTap: () {
                            Haptics.tap();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ScanScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: nk.mode == NekoThemeMode.dark
                                  ? nt.amberGradient
                                  : null,
                              color: nk.mode == NekoThemeMode.dark
                                  ? null
                                  : nk.amber,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: nk.mode == NekoThemeMode.dark
                                  ? [
                                      BoxShadow(
                                        color: nk.amber.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 20,
                                  color: nt.onAmber,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.pantryEmptyScan,
                                  style: _display(
                                    size: 15,
                                    weight: FontWeight.w700,
                                    color: nt.onAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // CTA secundaria: buscar
                        TextButton(
                          key: _searchCtaKey,
                          onPressed: () {
                            Haptics.tap();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SearchScreen(),
                              ),
                            );
                          },
                          child: Text(
                            l10n.pantryEmptySearch,
                            style: _body(
                              size: 14,
                              weight: FontWeight.w600,
                              color: nk.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ilustración del gato asomándose desde una caja vacía, con un "Z z z"
  /// animado. Hecha con widgets (sin assets nuevos) para mantener el estilo
  /// konbini: caja de cartón + mascota existente.
  ///
  /// Truco de composición: la caja se dibuja primero, el gato encima (su
  /// parte inferior queda "dentro" de la caja) y una tira con el color de la
  /// caja hace de pared frontal, ocultando el excedente del gato y dejando
  /// ver solo la cabeza asomando por el borde.
  Widget _buildCatInBox() {
    final nk = context.nk;
    const boxWidth = 200.0;
    const boxHeight = 130.0;
    const boxTop = 210.0 - boxHeight; // 80 → borde superior de la caja
    const catBottom = 114.0; // el gato sobresale 16px por encima del borde

    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Caja de cartón vacía
          Positioned(
            bottom: 0,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                color: nk.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: nk.amber.withValues(alpha: 0.30),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Línea de "cinta" en la pared frontal
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 3,
                        color: nk.amber.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  // Etiqueta de envío
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 96,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NEKO  //  VACÍO',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: nk.textFaint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gato asomándose por el borde de la caja
          Positioned(
            bottom: catBottom,
            child: NekoCatMascot(
              mood: CatMood.idle,
              size: 96,
              showLabel: false,
            ),
          ),
          // Pared frontal: tapa la parte inferior del gato para que parezca
          // que está DENTRO de la caja, y redibuja el borde superior.
          Positioned(
            top: boxTop,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: boxWidth,
                height: (210 - catBottom) - boxTop, // 16px — solape del gato
                decoration: BoxDecoration(
                  color: nk.surfaceHigh,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: nk.amber.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Zzz flotante
          const Positioned(top: 0, right: 44, child: _SleepingZzz()),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = _firebaseService.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: NekoSkeletonList()));
    }

    if (!_profileLoaded) {
      return Scaffold(
        backgroundColor: context.nk.bg,
        body: const NekoSkeletonList(),
      );
    }

    // Tour contextual — solo la primera vez que el usuario entra a la despensa.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());

    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .snapshots()
          .distinct(),
      builder: (context, pantrySnapshot) {
        if (pantrySnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: context.nk.bg,
            body: const NekoSkeletonList(),
          );
        }
        final docs = pantrySnapshot.data?.docs ?? [];
        final items = docs
            .map(
              (d) => PantryItem.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList();
        if (items.isEmpty) return _buildEmptyState();

        // Compute inventory estimates when items change
        _computeEstimates(uid, items);

        return AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final l10n = AppLocalizations.of(context);
            return Scaffold(
              backgroundColor: context.nk.bg,
              body: AmberAtmosphere(
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(_profileData),
                      _buildCategoryTabs(l10n),
                      const SizedBox(height: AppSpacing.s),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: _categories.map((cat) {
                            final catItems = items
                                .where((i) => i.category == cat.name)
                                .toList();
                            final active = catItems
                                .where((i) => i.isAvailable)
                                .toList();
                            final depleted = catItems
                                .where((i) => !i.isAvailable)
                                .toList();
                            return _buildCategoryBody(l10n, cat, active, depleted);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Lanza el tour contextual la primera vez que el usuario entra a la despensa.
  /// Espera a que el header (botón de calendario) esté renderizado; los targets
  /// de tabs/AGOTADOS solo existen si hay productos, y si faltan el spotlight
  /// cubre toda la pantalla (fallback elegante del tour).
  void _maybeStartTour() {
    if (!mounted || _tourLaunched) return;
    // No lanzar si la pestaña está oculta en el Offstage de la navegación
    // principal (la instancia vive desde el arranque; el tour saldría sobre
    // la pestaña activa). Se abre solo al activar la pestaña.
    final offstage = context.findAncestorWidgetOfExactType<Offstage>();
    if (offstage != null && offstage.offstage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
      return;
    }
    if (_calendarKey.currentContext == null) {
      if (_tourAttempts++ > 300) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
      return;
    }
    _tourLaunched = true;
    final l10n = AppLocalizations.of(context);
    // En el estado vacío no existen las tabs de categoría ni la sección
    // AGOTADOS: el paso 1 ilumina el CTA "Escanear tu primer producto".
    final isEmpty = _tabsKey.currentContext == null;
    NekoTour.show(
      context: context,
      tourId: 'pantry_v1',
      steps: [
        if (isEmpty)
          NekoTourStep(
            title: l10n.tourPantry1Title,
            message: l10n.tourPantry1Empty,
            bubbleVariant: BubbleVariant.cloud,
            // Los botones del estado vacío viven en la mitad baja de la
            // pantalla: burbuja arriba para no tapar el target iluminado.
            bubbleAlignment: NekoTourAlignment.topLeft,
            icon: Icons.qr_code_scanner_rounded,
            targetKey: _scanCtaKey,
            padding: const EdgeInsets.all(8),
          )
        else
          NekoTourStep(
            title: l10n.tourPantry1Title,
            message: l10n.tourPantry1Full,
            bubbleVariant: BubbleVariant.cloud,
            bubbleAlignment: NekoTourAlignment.bottomLeft,
            icon: Icons.inventory_2_outlined,
            targetKey: _tabsKey,
            padding: const EdgeInsets.all(8),
          ),
        if (isEmpty)
          NekoTourStep(
            title: l10n.tourPantry2EmptyTitle,
            message: l10n.tourPantry2Empty,
            bubbleVariant: BubbleVariant.heart,
            bubbleAlignment: NekoTourAlignment.topLeft,
            icon: Icons.search_rounded,
            targetKey: _searchCtaKey,
            padding: const EdgeInsets.all(8),
          )
        else
          NekoTourStep(
            title: l10n.tourPantry2FullTitle,
            message: l10n.tourPantry2Full,
            bubbleVariant: BubbleVariant.heart,
            bubbleAlignment: NekoTourAlignment.bottomLeft,
            icon: Icons.refresh_rounded,
            targetKey: _agotadosKey,
            padding: const EdgeInsets.all(8),
          ),
        NekoTourStep(
          title: l10n.tourPantry3Title,
          message: l10n.tourPantry3,
          bubbleVariant: BubbleVariant.cloud,
          bubbleAlignment: NekoTourAlignment.topLeft,
          icon: Icons.calendar_month_outlined,
          targetKey: _calendarKey,
          padding: const EdgeInsets.all(8),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tabs personalizadas — píldora con color de categoría
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryTabs(AppLocalizations l10n) {
    final nk = context.nk;
    final nt = context.nt;
    final activeCatColor = nt.ofCategory(
      _categories[_tabController.index].name,
    );
    return Container(
      key: _tabsKey,
      margin: const EdgeInsets.only(top: AppSpacing.s),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.stamp),
          color: activeCatColor.withValues(alpha: 0.22),
          border: Border.all(
            color: activeCatColor.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: nk.text,
        unselectedLabelColor: nk.textDim,
        dividerColor: Colors.transparent,
        tabs: _categories.map((cat) {
          final catColor = nt.ofCategory(cat.name);
          return Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _categoryLabel(l10n, cat),
                style: _mono(
                  size: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: catColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryBody(
    AppLocalizations l10n,
    _Category cat,
    List<PantryItem> active,
    List<PantryItem> depleted,
  ) {
    if (active.isEmpty && depleted.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            l10n.pantryEmptyCategory(_categoryLabel(l10n, cat)),
            style: _body(size: 14, color: context.nk.textDim),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active.isNotEmpty) ...[
            _sectionLabel(l10n.pantryInStock, context.nk.ok),
            ...active.map((i) => _buildPantryCard(i, true)),
          ],
          if (depleted.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel(l10n.pantryDepleted, context.nk.danger,
                key: _agotadosKey),
            ...depleted.map((i) => _buildPantryCard(i, false)),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color, {GlobalKey? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l + 4,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: _mono(
              size: 11,
              weight: FontWeight.w700,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String name;
  const _Category(this.name);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tipografía Noche Ámbar (mismas fuentes que Home/Diario)
// ─────────────────────────────────────────────────────────────────────────────
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
}) => GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color);

/// "Z z z" flotante del gato dormido en el empty state — sube y se desvanece
/// en loop para dar vida a la ilustración sin distraer.
class _SleepingZzz extends StatefulWidget {
  const _SleepingZzz();

  @override
  State<_SleepingZzz> createState() => _SleepingZzzState();
}

class _SleepingZzzState extends State<_SleepingZzz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Sube 8px y se desvanece en la segunda mitad del ciclo.
        final opacity = t < 0.6 ? (1.0 - t / 0.6) : 0.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, -8 * t),
            child: Text(
              'Z z z',
              style: _mono(
                size: 15,
                weight: FontWeight.w700,
                color: context.nk.amber.withValues(alpha: 0.9),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Bridge alias — permite que imports viejos a HomeScreen sigan compilando
// mientras se migra al nuevo sistema de navegación.
typedef HomeScreen = PantryScreen;
