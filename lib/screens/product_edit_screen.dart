import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/neko_palette.dart';
import '../core/theme.dart';
import '../core/category_inference.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/pantry_item.dart';
import '../services/image_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/pantry_image_placeholder.dart';
import '../widgets/product_comparator_sheet.dart';

/// Pantalla de edición de un producto de la despensa. Permite:
///   * Cambiar el nombre
///   * Cambiar la cantidad (en g o ml según la unidad base)
///   * Cambiar los macros por 100g/100ml
///   * Establecer el precio (opcional, para el comparador de productos)
///   * Tomar o subir una nueva foto (comprimida <100KB y subida a
///     `users/{uid}/pantry/{id}.jpg`)
///   * Eliminar el producto
///   * Comparar con productos similares de la misma categoría
class ProductEditScreen extends ConsumerStatefulWidget {
  final PantryItem item;
  const ProductEditScreen({super.key, required this.item});

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proCtrl;
  late final TextEditingController _carCtrl;
  late final TextEditingController _fatCtrl;

  /// Campo de precio, opcional. Si está vacío se guarda como null.
  late final TextEditingController _priceCtrl;
  late String _category;
  late String _baseUnit;
  String? _imageUrl;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _loadingPeers = false;
  final _picker = ImagePicker();
  final _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.replaceAll(RegExp(r'[^0-9.,]'), ''),
    );
    _calCtrl = TextEditingController(text: widget.item.calories.toString());
    _proCtrl = TextEditingController(text: widget.item.proteins.toString());
    _carCtrl = TextEditingController(text: widget.item.carbs.toString());
    _fatCtrl = TextEditingController(text: widget.item.fats.toString());
    _priceCtrl = TextEditingController(
      text: widget.item.price != null ? widget.item.price.toString() : '',
    );
    _category = widget.item.category;
    _baseUnit = widget.item.baseUnit ?? 'g';
    _imageUrl = widget.item.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carCtrl.dispose();
    _fatCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'Proteínas' => l10n.categoryProteins,
      'Carbohidratos' => l10n.categoryCarbs,
      'Grasas' => l10n.categoryFats,
      'Vegetales' => l10n.categoryVegetables,
      'Lácteos/Huevos' => l10n.categoryDairyEggs,
      _ => key,
    };
  }

  /// Carga los productos de la misma categoría y abre el comparador.
  Future<void> _openComparator() async {
    final uid = ref.read(firebaseServiceProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingPeers = true);
    try {
      final snap = await ref
          .read(firebaseServiceProvider)
          .db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .where('category', isEqualTo: _category)
          .get();
      final peers = snap.docs
          .map((d) => PantryItem.fromMap(d.data(), d.id))
          .where((p) => p.isAvailable)
          .toList();
      if (!mounted) return;
      // Incluir el producto actual con su precio actualizado si el user lo editó
      final updatedCurrent = PantryItem(
        id: widget.item.id,
        name: _nameCtrl.text.trim().isEmpty
            ? widget.item.name
            : _nameCtrl.text.trim(),
        category: _category,
        isAvailable: widget.item.isAvailable,
        quantity: widget.item.quantity,
        calories: double.tryParse(_calCtrl.text.trim()) ?? widget.item.calories,
        proteins: double.tryParse(_proCtrl.text.trim()) ?? widget.item.proteins,
        carbs: double.tryParse(_carCtrl.text.trim()) ?? widget.item.carbs,
        fats: double.tryParse(_fatCtrl.text.trim()) ?? widget.item.fats,
        lastReplenished: widget.item.lastReplenished,
        price: double.tryParse(_priceCtrl.text.trim()),
      );
      // Reemplazar el ítem actual en la lista con los valores recién editados
      final peersUpdated = peers.map((p) {
        return p.id == updatedCurrent.id ? updatedCurrent : p;
      }).toList();
      if (!peersUpdated.any((p) => p.id == updatedCurrent.id)) {
        peersUpdated.add(updatedCurrent);
      }
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ProductComparatorSheet(
          current: updatedCurrent,
          peers: peersUpdated,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPeers = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await _imageService.uploadProductImage(
        uid: ImageService.currentUid(),
        productId: widget.item.id,
        file: File(file.path),
      );
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.prodPhotoUploadError(e.toString()))));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    final uid = ref.read(firebaseServiceProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final quantity = double.tryParse(_qtyCtrl.text.trim());
      await ref
          .read(firebaseServiceProvider)
          .db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc(widget.item.id)
          .update({
            'name': _nameCtrl.text.trim(),
            'quantity': quantity != null
                ? '${quantity.round()} $_baseUnit'
                : widget.item.quantity,
            'originalQuantity': quantity != null
                ? '${quantity.round()} $_baseUnit'
                : widget.item.originalQuantity ?? widget.item.quantity,
            'calories': double.tryParse(_calCtrl.text.trim()) ?? 0,
            'proteins': double.tryParse(_proCtrl.text.trim()) ?? 0,
            'carbs': double.tryParse(_carCtrl.text.trim()) ?? 0,
            'fats': double.tryParse(_fatCtrl.text.trim()) ?? 0,
            'baseUnit': _baseUnit,
            'category': _category,
            'imageUrl': _imageUrl,
            'price': double.tryParse(_priceCtrl.text.trim()),
          });
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.prodUpdated)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nk.surface,
        title: Text(l10n.prodDeleteTitle, style: TextStyle(color: nk.text)),
        content: Text(
          l10n.prodDeleteConfirm(widget.item.name),
          style: TextStyle(color: nk.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel, style: TextStyle(color: nk.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.diaryDeleteConfirm,
              style: TextStyle(color: nk.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final uid = ref.read(firebaseServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await ref
        .read(firebaseServiceProvider)
        .db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .doc(widget.item.id)
        .delete();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Decoración de input theme-aware (Noche Ámbar).
  InputDecoration _input(String label, {String? suffix, IconData? prefixIcon}) {
    final nk = context.nk;
    return InputDecoration(
      labelText: label,
      labelStyle: _body(size: 14, color: nk.textDim),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: nk.textDim)
          : null,
      suffixText: suffix,
      suffixStyle: _mono(size: 12, color: nk.textFaint),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: nk.bg,
      appBar: AppBar(
        title: Text(
          l10n.prodEditTitle,
          style: _display(
            size: 19,
            weight: FontWeight.w700,
            color: nk.text,
            letterSpacing: -0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: nk.text),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: nk.danger),
            onPressed: _saving ? null : _delete,
          ),
        ],
      ),
      body: AmberAtmosphere(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _imageArea(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingImage
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nk.text,
                          side: const BorderSide(color: Color(0xFFCFCBC1)),
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.photo_camera_rounded, size: 20),
                        label: Text(l10n.nlCamera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingImage
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nk.text,
                          side: const BorderSide(color: Color(0xFFCFCBC1)),
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.image_rounded, size: 20),
                        label: Text(l10n.nlGallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  style: _body(size: 15, color: nk.text),
                  decoration: _input(
                    l10n.nlName,
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: _body(size: 15, color: nk.text),
                        decoration: _input(
                          l10n.nlQuantity,
                          suffix: _baseUnit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _baseUnit,
                        style: _body(size: 15, color: nk.text),
                        dropdownColor: nk.surface,
                        decoration: _input(l10n.prodUnit),
                        items: const [
                          DropdownMenuItem(value: 'g', child: Text('g')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                        ],
                        onChanged: (v) => setState(() => _baseUnit = v ?? 'g'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  style: _body(size: 15, color: nk.text),
                  dropdownColor: nk.surface,
                  decoration: _input(
                    l10n.prodCategory,
                    prefixIcon: Icons.category_outlined,
                  ),
                  items: pantryCategories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          _categoryLabel(l10n, c),
                          style: _body(size: 14, color: nk.text),
                        ),
                      ),
                    )
                    .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 16),
                _macroField(l10n.nlCalories, 'kcal', _calCtrl),
                _macroField(l10n.nlProteins, 'g', _proCtrl),
                _macroField(l10n.nlCarbs, 'g', _carCtrl),
                _macroField(l10n.nlFats, 'g', _fatCtrl),
                const SizedBox(height: 4),
                // ── Precio (opcional) ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: _body(size: 15, color: nk.text),
                    decoration: _input(
                      l10n.prodPrice,
                      suffix: '\$',
                      prefixIcon: Icons.attach_money_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ── Guardar ───────────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nk.amber,
                    foregroundColor: nk.mode == NekoThemeMode.dark
                        ? const Color(0xFF1A1206)
                        : Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                  icon: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: nk.mode == NekoThemeMode.dark
                                ? const Color(0xFF1A1206)
                                : Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(l10n.prodSave),
                ),
                const SizedBox(height: 12),
                // ── Comparar con similares ─────────────────────────────────
                OutlinedButton.icon(
                  onPressed: _loadingPeers ? null : _openComparator,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: nk.text,
                    side: BorderSide(color: nk.amber.withValues(alpha: 0.5)),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _loadingPeers
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: nk.amber,
                          ),
                        )
                      : Icon(Icons.balance_rounded, size: 20, color: nk.amber),
                  label: Text(l10n.prodCompareSimilar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageArea() {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => PantryImagePlaceholder(
                  item: widget.item,
                  size: null,
                  borderRadius: 0,
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return PantryImagePlaceholder(
                    item: widget.item,
                    size: null,
                    borderRadius: 0,
                  );
                },
              ),
              if (_uploadingImage)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: nk.border),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: nk.textDim,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.prodPhotoHint,
              style: _body(size: 12, color: nk.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroField(String label, String suffix, TextEditingController c) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: _body(size: 15, color: nk.text),
        decoration: _input(l10n.prodMacroField(label, _baseUnit), suffix: suffix),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tipografía Noche Ámbar
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
}) => GoogleFonts.dmSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);
