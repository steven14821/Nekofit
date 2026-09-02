import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/open_food_facts_service.dart';
import '../services/image_service.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../core/category_inference.dart';
import '../widgets/amber_atmosphere.dart';
import '../l10n/app_localizations.dart';
import 'nutrition_label_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _service = OpenFoodFactsService();
  final _imageService = ImageService();
  List<OpenFoodFactsProduct> _results = [];
  List<FreshFoodPreset> _localResults = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);

    // Buscar en Open Food Facts (externo)
    final results = await _service.searchProducts(query);

    // Buscar en frescos locales
    final queryLower = query.trim().toLowerCase();
    final local = _freshFoodPresets
        .where((p) => p.name.toLowerCase().contains(queryLower))
        .toList();

    if (!mounted) return;
    setState(() {
      _results = results;
      _localResults = local;
      _loading = false;
    });
  }

  void _showProductSheet(OpenFoodFactsProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nk.surface,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _SearchProductSheet(product: product, imageService: _imageService),
    );
  }

  void _offerLabelPhoto(String prefilledName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NutritionLabelScreen(prefilledName: prefilledName),
      ),
    );
  }

  void _openManualFreshFoodSheet(
    String prefilledName, {
    FreshFoodPreset? preset,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nk.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ManualFreshFoodSheet(
        prefilledName: prefilledName,
        imageService: _imageService,
        preset: preset,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nk = context.nk;
    return Scaffold(
      backgroundColor: nk.bg,
      appBar: AppBar(
        title: Text(
          l10n.pantryEmptySearch,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: nk.text,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: nk.text),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_camera_rounded, color: nk.text),
            tooltip: l10n.scanLabelPhoto,
            onPressed: () => _offerLabelPhoto(_controller.text),
          ),
        ],
      ),
      body: AmberAtmosphere(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                              _localResults = [];
                            });
                          },
                        )
                      : null,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _search(v);
                },
                onChanged: (v) => setState(() {}),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_results.isEmpty && _localResults.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.searchEmptyNoProducts,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: nk.textDim, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        if (_controller.text.trim().isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(l10n.searchAddManually),
                              onPressed: () => _openManualFreshFoodSheet(
                                _controller.text.trim(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: Text(l10n.searchOrTakeLabelPhoto),
                          onPressed: () => _offerLabelPhoto(_controller.text),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (_localResults.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          l10n.searchFreshSuggestions,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: nk.textFaint,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ..._localResults.map(
                        (preset) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: nk.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            side: BorderSide(color: nk.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _categoryColor(
                                preset.category,
                                nk,
                              ).withValues(alpha: 0.12),
                              child: Icon(
                                Icons.eco_rounded,
                                color: _categoryColor(preset.category, nk),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              preset.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: nk.text,
                              ),
                            ),
                            subtitle: Text(
                              l10n.searchFreshMacros(
                                preset.calories.round(),
                                preset.proteins.toStringAsFixed(1),
                                preset.carbs.toStringAsFixed(1),
                                preset.fats.toStringAsFixed(1),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: nk.textDim,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () => _openManualFreshFoodSheet(
                                preset.name,
                                preset: preset,
                              ),
                              child: Text(l10n.diaryAdd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_results.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          l10n.searchSupermarketProducts,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: nk.textFaint,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ..._results.map(
                        (product) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: nk.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            side: BorderSide(color: nk.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadii.chip,
                              ),
                              child: Container(
                                width: 40,
                                height: 40,
                                color: nk.surfaceHigh,
                                child: product.imageFrontUrl != null
                                    ? Image.network(
                                        product.imageFrontUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _productInitialIcon(
                                              product.name ?? 'P',
                                            ),
                                      )
                                    : _productInitialIcon(product.name ?? 'P'),
                              ),
                            ),
                            title: Text(
                              product.name ?? l10n.searchProduct,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: nk.text,
                              ),
                            ),
                            subtitle: Text(
                              '${product.brand != null ? '${product.brand} · ' : ''}${_macrosString(product, l10n)}',
                              style: TextStyle(fontSize: 11, color: nk.textDim),
                            ),
                            trailing: TextButton(
                              onPressed: () => _showProductSheet(product),
                              child: Text(l10n.diaryAdd),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _macrosString(OpenFoodFactsProduct p, AppLocalizations l10n) {
    final unit = p.baseUnit;
    final parts = <String>[];
    if (p.calories != null) {
      parts.add(l10n.searchMacroKcal(p.calories!.round(), unit));
    }
    if (p.proteins != null) {
      parts.add(l10n.searchMacroProtein(p.proteins!.toStringAsFixed(1), unit));
    }
    if (p.carbs != null) {
      parts.add(l10n.searchMacroCarbs(p.carbs!.toStringAsFixed(1), unit));
    }
    if (p.fats != null) {
      parts.add(l10n.searchMacroFats(p.fats!.toStringAsFixed(1), unit));
    }
    return parts.join(' · ');
  }

  Widget _productInitialIcon(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: context.nk.textFaint,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _SearchProductSheet extends ConsumerStatefulWidget {
  final OpenFoodFactsProduct product;
  final ImageService imageService;

  const _SearchProductSheet({
    required this.product,
    required this.imageService,
  });

  @override
  ConsumerState<_SearchProductSheet> createState() =>
      _SearchProductSheetState();
}

class _SearchProductSheetState extends ConsumerState<_SearchProductSheet> {
  late final TextEditingController _gramsCtrl;
  bool _saving = false;
  String? _imageUrl;
  String? _originalOffUrl;
  File? _userPhoto;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _gramsCtrl = TextEditingController();
    _imageUrl = widget.product.imageFrontUrl;
    _originalOffUrl = widget.product.imageFrontUrl;
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      _userPhoto = File(file.path);
      _imageUrl = file.path;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final product = widget.product;
    final grams = double.tryParse(_gramsCtrl.text.trim());
    if (grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.scanGramsSnack),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = ref.read(firebaseServiceProvider).currentUser?.uid;
      if (uid == null) return;
      final docRef = ref
          .read(firebaseServiceProvider)
          .db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc();

      String? storedImageUrl;
      if (_userPhoto != null) {
        try {
          storedImageUrl = await widget.imageService.uploadProductImage(
            uid: uid,
            productId: docRef.id,
            file: _userPhoto,
          );
        } catch (_) {
          storedImageUrl = null;
        }
      } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        try {
          storedImageUrl = await widget.imageService.uploadProductImage(
            uid: uid,
            productId: docRef.id,
            sourceUrl: _imageUrl,
          );
        } catch (_) {
          storedImageUrl = null;
        }
      }

      await docRef.set({
        'name': product.name ?? 'Producto',
        'barcode': product.barcode,
        'quantity': '${grams.round()} ${product.baseUnit}',
        'originalQuantity': '${grams.round()} ${product.baseUnit}',
        'calories': product.calories ?? 0,
        'proteins': product.proteins ?? 0,
        'carbs': product.carbs ?? 0,
        'fats': product.fats ?? 0,
        'baseUnit': product.baseUnit,
        'isAvailable': true,
        'lastReplenished': FieldValue.serverTimestamp(),
        'category': inferPantryCategory(product),
        'imageUrl': storedImageUrl,
        'source': 'search',
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scanProductAdded)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nk = context.nk;
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.name ?? l10n.searchProduct,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: nk.text,
            ),
          ),
          if (p.brand != null)
            Text(p.brand!, style: TextStyle(color: nk.textDim)),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (_userPhoto != null || _imageUrl != null) return;
                  await _pickPhoto(ImageSource.camera);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: nk.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    image: _userPhoto != null
                        ? DecorationImage(
                            image: FileImage(_userPhoto!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _userPhoto == null
                      ? (_imageUrl != null
                            ? Icon(
                                Icons.image_rounded,
                                color: nk.textFaint,
                                size: 20,
                              )
                            : Icon(
                                Icons.image_not_supported_outlined,
                                color: nk.textFaint,
                                size: 20,
                              ))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _userPhoto != null
                      ? l10n.searchPhotoReady
                      : (p.imageFrontUrl != null
                            ? l10n.searchPhotoFetchOnSave
                            : l10n.searchPhotoNoneAdd),
                  style: TextStyle(fontSize: 12, color: nk.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded, size: 16),
                    label: Text(
                      l10n.nlCamera,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.image_rounded, size: 16),
                    label: Text(
                      l10n.nlGallery,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              if (_userPhoto != null || _imageUrl != _originalOffUrl) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _userPhoto = null;
                      _imageUrl = _originalOffUrl;
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (p.calories != null)
            Text(
              '${l10n.nlCalories}: ${p.calories!.toStringAsFixed(0)} kcal/100${p.baseUnit}',
              style: TextStyle(color: nk.text, fontSize: 13),
            ),
          if (p.proteins != null)
            Text(
              '${l10n.nlProteins}: ${p.proteins!.toStringAsFixed(1)}g/100${p.baseUnit}',
              style: TextStyle(color: nk.text, fontSize: 13),
            ),
          if (p.carbs != null)
            Text(
              '${l10n.nlCarbs}: ${p.carbs!.toStringAsFixed(1)}g/100${p.baseUnit}',
              style: TextStyle(color: nk.text, fontSize: 13),
            ),
          if (p.fats != null)
            Text(
              '${l10n.nlFats}: ${p.fats!.toStringAsFixed(1)}g/100${p.baseUnit}',
              style: TextStyle(color: nk.text, fontSize: 13),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _gramsCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.nlQuantity,
              hintText: l10n.scanGramsHint,
              suffixText: p.baseUnit,
              prefixIcon: const Icon(Icons.scale_rounded),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(l10n.scanAddToPantry),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Color de una categoría de alimento por nombre, resuelto para el modo activo
// (espejo de AppColors.ofCategory, pero theme-aware).
// ═════════════════════════════════════════════════════════════════════════════
Color _categoryColor(String name, NekoColors nk) {
  switch (name) {
    case 'Proteínas':
      return nk.protein;
    case 'Carbohidratos':
      return nk.carbs;
    case 'Grasas':
      return nk.fat;
    case 'Vegetales':
      return nk.ok;
    case 'Lácteos/Huevos':
      return nk.warn;
    default:
      return nk.amber;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sheet para agregar alimentos frescos manualmente
// ═════════════════════════════════════════════════════════════════════════════

class _ManualFreshFoodSheet extends ConsumerStatefulWidget {
  final String prefilledName;
  final ImageService imageService;
  final FreshFoodPreset? preset;

  const _ManualFreshFoodSheet({
    required this.prefilledName,
    required this.imageService,
    this.preset,
  });

  @override
  ConsumerState<_ManualFreshFoodSheet> createState() =>
      _ManualFreshFoodSheetState();
}

class _ManualFreshFoodSheetState extends ConsumerState<_ManualFreshFoodSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _qtyCtrl;
  String _category = 'Proteínas';
  bool _saving = false;

  File? _userPhoto;
  final _picker = ImagePicker();
  final _offService = OpenFoodFactsService();
  Timer? _debounce;
  String? _suggestedImageUrl;
  bool _searchingImage = false;

  static const _categories = [
    'Proteínas',
    'Carbohidratos',
    'Grasas',
    'Vegetales',
    'Lácteos/Huevos',
  ];

  String _categoryLabel(String cat, AppLocalizations l10n) {
    switch (cat) {
      case 'Proteínas':
        return l10n.categoryProteins;
      case 'Carbohidratos':
        return l10n.categoryCarbs;
      case 'Grasas':
        return l10n.categoryFats;
      case 'Vegetales':
        return l10n.categoryVegetables;
      case 'Lácteos/Huevos':
        return l10n.categoryDairyEggs;
      default:
        return cat;
    }
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefilledName);

    // Si viene de un preset, autocompletamos los valores nutritivos
    if (widget.preset != null) {
      final p = widget.preset!;
      _calCtrl = TextEditingController(text: p.calories.toStringAsFixed(0));
      _proCtrl = TextEditingController(text: p.proteins.toStringAsFixed(1));
      _carbCtrl = TextEditingController(text: p.carbs.toStringAsFixed(1));
      _fatCtrl = TextEditingController(text: p.fats.toStringAsFixed(1));
      _category = p.category;
    } else {
      _calCtrl = TextEditingController();
      _proCtrl = TextEditingController();
      _carbCtrl = TextEditingController();
      _fatCtrl = TextEditingController();
    }
    _qtyCtrl = TextEditingController(text: '100');

    // Auto-buscar imagen si ya hay nombre prefilled
    if (widget.prefilledName.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchImageForName(widget.prefilledName.trim());
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().length >= 3) {
        _searchImageForName(value.trim());
      } else {
        setState(() => _suggestedImageUrl = null);
      }
    });
  }

  Future<void> _searchImageForName(String query) async {
    if (_userPhoto != null) return;
    setState(() => _searchingImage = true);
    try {
      final result = await _offService.firstMatchByName(query);
      if (!mounted) return;
      setState(() {
        _suggestedImageUrl = result.found ? result.imageFrontUrl : null;
        _searchingImage = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchingImage = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      _userPhoto = File(file.path);
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchAskName)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(firebaseServiceProvider).currentUser?.uid;
      if (uid == null) return;

      final docRef = ref
          .read(firebaseServiceProvider)
          .db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc();

      String? storedImageUrl;
      if (_userPhoto != null) {
        try {
          storedImageUrl = await widget.imageService.uploadProductImage(
            uid: uid,
            productId: docRef.id,
            file: _userPhoto,
          );
        } catch (_) {
          storedImageUrl = null;
        }
      } else if (_suggestedImageUrl != null && _suggestedImageUrl!.isNotEmpty) {
        try {
          storedImageUrl = await widget.imageService.uploadProductImage(
            uid: uid,
            productId: docRef.id,
            sourceUrl: _suggestedImageUrl,
          );
        } catch (_) {
          storedImageUrl = null;
        }
      }

      final grams = double.tryParse(_qtyCtrl.text.trim()) ?? 100;
      final calories = double.tryParse(_calCtrl.text.trim()) ?? 0;
      final proteins = double.tryParse(_proCtrl.text.trim()) ?? 0;
      final carbs = double.tryParse(_carbCtrl.text.trim()) ?? 0;
      final fats = double.tryParse(_fatCtrl.text.trim()) ?? 0;

      await docRef.set({
        'name': name,
        'category': _category,
        'quantity': '${grams.round()} g',
        'originalQuantity': '${grams.round()} g',
        'calories': calories,
        'proteins': proteins,
        'carbs': carbs,
        'fats': fats,
        'baseUnit': 'g',
        'isAvailable': true,
        'lastReplenished': FieldValue.serverTimestamp(),
        'source': 'manual',
        'imageUrl': storedImageUrl,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.searchManualAdded(name))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nk = context.nk;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: nk.ok.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Icon(Icons.eco_rounded, size: 16, color: nk.ok),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.searchAddFreshFood,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: nk.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nombre
            TextField(
              controller: _nameCtrl,
              onChanged: _onNameChanged,
              decoration: InputDecoration(
                labelText: l10n.searchFoodName,
                hintText: l10n.searchFoodNameHint,
                prefixIcon: const Icon(Icons.restaurant_rounded),
              ),
            ),
            const SizedBox(height: 8),

            // Imagen sugerida por nombre (auto-búsqueda)
            if (_searchingImage)
              Container(
                height: 48,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: nk.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: nk.cat,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.searchSearchingImage,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        color: nk.textFaint,
                      ),
                    ),
                  ],
                ),
              )
            else if (_suggestedImageUrl != null && _userPhoto == null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: nk.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: nk.cat.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _suggestedImageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 40,
                          height: 40,
                          color: nk.surfaceHigh,
                          child: Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: nk.textFaint,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.searchImageFoundOff,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 12,
                          color: nk.textDim,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _suggestedImageUrl = null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: nk.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Foto de Alimento Fresco
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    if (_userPhoto != null) return;
                    await _pickPhoto(ImageSource.camera);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: nk.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      image: _userPhoto != null
                          ? DecorationImage(
                              image: FileImage(_userPhoto!),
                              fit: BoxFit.cover,
                            )
                          : _suggestedImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_suggestedImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_userPhoto == null && _suggestedImageUrl == null)
                        ? Icon(
                            Icons.image_not_supported_outlined,
                            color: nk.textFaint,
                            size: 20,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _userPhoto != null
                        ? l10n.searchPhotoReady
                        : (_suggestedImageUrl != null
                              ? l10n.searchUsingImageOff
                              : l10n.searchPhotoNoneAdd),
                    style: TextStyle(fontSize: 12, color: nk.textDim),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: Text(
                        l10n.nlCamera,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.image_rounded, size: 16),
                      label: Text(
                        l10n.nlGallery,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                if (_userPhoto != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _userPhoto = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Categoría
            Text(
              l10n.searchCategory,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: nk.textFaint,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((cat) {
                final isSelected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? nk.ok.withValues(alpha: 0.15)
                          : nk.surfaceHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: isSelected
                          ? Border.all(
                              color: nk.ok.withValues(alpha: 0.5),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Text(
                      _categoryLabel(cat, l10n),
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? nk.ok : nk.textFaint,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Macros por 100g
            Text(
              l10n.searchValuesPer100g,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: nk.textFaint,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _calCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.nlCalories,
                      hintText: '0',
                      suffixText: 'kcal',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _proCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.nlProteins,
                      hintText: '0',
                      suffixText: 'g',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _carbCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.nlCarbs,
                      hintText: '0',
                      suffixText: 'g',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.nlFats,
                      hintText: '0',
                      suffixText: 'g',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cantidad a agregar
            TextField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.searchQuantityAdd,
                hintText: l10n.scanGramsHint,
                suffixText: 'g',
                prefixIcon: const Icon(Icons.scale_rounded),
              ),
            ),
            const SizedBox(height: 20),

            // Guardar
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(l10n.scanAddToPantry),
            ),
          ],
        ),
      ),
    );
  }
}

class FreshFoodPreset {
  final String name;
  final String category;
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;

  const FreshFoodPreset({
    required this.name,
    required this.category,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
  });
}

const List<FreshFoodPreset> _freshFoodPresets = [
  // Proteínas
  FreshFoodPreset(
    name: 'Pechuga de Pollo Fresca',
    category: 'Proteínas',
    calories: 165,
    proteins: 31,
    carbs: 0,
    fats: 3.6,
  ),
  FreshFoodPreset(
    name: 'Filete de Salmón Fresco',
    category: 'Proteínas',
    calories: 208,
    proteins: 20,
    carbs: 0,
    fats: 13,
  ),
  FreshFoodPreset(
    name: 'Huevo Entero',
    category: 'Lácteos/Huevos',
    calories: 143,
    proteins: 13,
    carbs: 1.1,
    fats: 9.5,
  ),
  FreshFoodPreset(
    name: 'Carne de Res Molida (Magra)',
    category: 'Proteínas',
    calories: 176,
    proteins: 20,
    carbs: 0,
    fats: 10,
  ),
  FreshFoodPreset(
    name: 'Pescado Blanco (Merluza/Tilapia)',
    category: 'Proteínas',
    calories: 90,
    proteins: 18,
    carbs: 0,
    fats: 2,
  ),

  // Carbohidratos
  FreshFoodPreset(
    name: 'Plátano / Banano',
    category: 'Carbohidratos',
    calories: 89,
    proteins: 1.1,
    carbs: 22.8,
    fats: 0.3,
  ),
  FreshFoodPreset(
    name: 'Manzana Roja/Verde',
    category: 'Carbohidratos',
    calories: 52,
    proteins: 0.3,
    carbs: 13.8,
    fats: 0.2,
  ),
  FreshFoodPreset(
    name: 'Papa Blanca Cocida',
    category: 'Carbohidratos',
    calories: 87,
    proteins: 1.9,
    carbs: 20.1,
    fats: 0.1,
  ),
  FreshFoodPreset(
    name: 'Batata / Camote',
    category: 'Carbohidratos',
    calories: 86,
    proteins: 1.6,
    carbs: 20.1,
    fats: 0.1,
  ),
  FreshFoodPreset(
    name: 'Arroz Blanco Cocido',
    category: 'Carbohidratos',
    calories: 130,
    proteins: 2.7,
    carbs: 28,
    fats: 0.3,
  ),

  // Grasas
  FreshFoodPreset(
    name: 'Aguacate Hass',
    category: 'Grasas',
    calories: 160,
    proteins: 2,
    carbs: 9,
    fats: 15,
  ),
  FreshFoodPreset(
    name: 'Aceite de Oliva Extra Virgen',
    category: 'Grasas',
    calories: 884,
    proteins: 0,
    carbs: 0,
    fats: 100,
  ),
  FreshFoodPreset(
    name: 'Nueces',
    category: 'Grasas',
    calories: 654,
    proteins: 15.2,
    carbs: 13.7,
    fats: 65.2,
  ),
  FreshFoodPreset(
    name: 'Almendras',
    category: 'Grasas',
    calories: 579,
    proteins: 21,
    carbs: 22,
    fats: 49,
  ),

  // Vegetales
  FreshFoodPreset(
    name: 'Brócoli Fresco',
    category: 'Vegetales',
    calories: 34,
    proteins: 2.8,
    carbs: 7,
    fats: 0.4,
  ),
  FreshFoodPreset(
    name: 'Espinaca Fresca',
    category: 'Vegetales',
    calories: 23,
    proteins: 2.9,
    carbs: 3.6,
    fats: 0.4,
  ),
  FreshFoodPreset(
    name: 'Tomate Rojo',
    category: 'Vegetales',
    calories: 18,
    proteins: 0.9,
    carbs: 3.9,
    fats: 0.2,
  ),
  FreshFoodPreset(
    name: 'Zanahoria Cruda',
    category: 'Vegetales',
    calories: 41,
    proteins: 0.9,
    carbs: 9.6,
    fats: 0.2,
  ),
  FreshFoodPreset(
    name: 'Lechuga Romana',
    category: 'Vegetales',
    calories: 15,
    proteins: 1.4,
    carbs: 2.9,
    fats: 0.3,
  ),
];
