import '../core/neko_palette.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/open_food_facts_service.dart';
import '../services/image_service.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../core/haptics.dart';
import '../core/category_inference.dart';
import '../l10n/app_localizations.dart';
import 'nutrition_label_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _scannerController = MobileScannerController();
  final _openFoodFacts = OpenFoodFactsService();
  final _imageService = ImageService();
  bool _scanning = true;
  bool _looking = false;
  String? _lastBarcode;

  // Animación de pulse
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    _scanning = false;
    _lastBarcode = barcode;
    Haptics.success();
    _lookupProduct(barcode);
  }

  Future<void> _lookupProduct(String barcode) async {
    setState(() => _looking = true);
    final product = await _openFoodFacts.resolveBarcode(barcode);
    if (!mounted) return;
    setState(() => _looking = false);

    if (product.hasUsableData) {
      _showProductSheet(product);
    } else {
      _showNotFoundFallback(barcode);
    }
  }

  Future<void> _searchByName(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _looking = true);
    final result = await _openFoodFacts.firstMatchByName(query);
    if (!mounted) return;
    setState(() => _looking = false);
    if (result.hasUsableData) {
      _showProductSheet(result);
    } else {
      if (!mounted) return;
      _offerLabelPhoto(prefilledName: query);
    }
  }

  void _offerLabelPhoto({String? prefilledName, String? barcode}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NutritionLabelScreen(
          prefilledName: prefilledName,
          barcode: barcode,
        ),
      ),
    );
  }

  void _showProductSheet(OpenFoodFactsProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nk.surface,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _ProductSheet(product: product, imageService: _imageService),
    ).then((_) {
      if (mounted) {
        setState(() {
          _scanning = true;
          _lastBarcode = null;
        });
      }
    });
  }

  void _showNotFoundFallback(String barcode) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nk.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.scanNoMacrosData),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.scanNoMacrosBody(barcode),
              style: TextStyle(
                fontSize: 13,
                color: context.nk.textDim,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.scanSearchHint,
              ),
              onSubmitted: (v) {
                Navigator.of(ctx).pop();
                _searchByName(v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              _offerLabelPhoto(barcode: barcode);
            },
            child: Text(l10n.scanLabelPhoto),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _scanning = true;
            },
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final q = controller.text;
              Navigator.of(ctx).pop();
              _searchByName(q);
            },
            child: Text(l10n.scanSearchButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cámara
          MobileScanner(controller: _scannerController, onDetect: _onDetect),

          // Overlay oscuro
          Container(color: Colors.black.withValues(alpha: 0.15)),

          // Overlay de esquinas premium
          _buildScanOverlay(),

          // Header
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

          // Indicador de escaneo
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _buildScanIndicator(),
          ),

          // Botón de buscar por nombre
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: _buildSearchButton(),
          ),

          // Loading overlay
          if (_looking)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.nk.cat.withValues(alpha: 0.15),
                        border: Border.all(
                          color: context.nk.cat.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 28,
                        color: context.nk.cat,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.scanSearching,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: context.nk.cat,
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

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.scanTitle,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.nk.cat,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.scanPrompt,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    final catColor = context.nk.cat;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final opacity = 0.2 + (_pulseController.value * 0.15);
        return CustomPaint(
          painter: _BarcodeOverlayPainter(color: catColor, opacity: opacity),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildScanIndicator() {
    final l10n = AppLocalizations.of(context);
    if (_lastBarcode == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.nk.cat.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.nk.cat.withValues(
                        alpha: 0.5 + _pulseController.value * 0.5,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                l10n.scanWaiting,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: context.nk.ok.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.nk.ok.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: context.nk.ok,
            ),
            SizedBox(width: 8),
            Text(
              l10n.scanCodeDetected(_lastBarcode!),
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.nk.ok,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: GestureDetector(
        onTap: () => _showSearchDialog(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.scanSearchByName,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nk.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.scanSearchProduct),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.scanSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onSubmitted: (v) {
            Navigator.of(ctx).pop();
            _searchByName(v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final q = controller.text;
              Navigator.of(ctx).pop();
              _searchByName(q);
            },
            child: Text(l10n.scanSearchButton),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Overlay de esquinas premium para barcode scanner
// ═════════════════════════════════════════════════════════════════════════════

class _BarcodeOverlayPainter extends CustomPainter {
  final double opacity;
  final Color color;
  _BarcodeOverlayPainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = size.width * 0.07;
    final margin = size.width * 0.08;

    // Esquina superior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(margin, margin + cornerLength)
        ..lineTo(margin, margin)
        ..lineTo(margin + cornerLength, margin),
      paint,
    );

    // Esquina superior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - margin - cornerLength, margin)
        ..lineTo(size.width - margin, margin)
        ..lineTo(size.width - margin, margin + cornerLength),
      paint,
    );

    // Esquina inferior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(margin, size.height - margin - cornerLength)
        ..lineTo(margin, size.height - margin)
        ..lineTo(margin + cornerLength, size.height - margin),
      paint,
    );

    // Esquina inferior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - margin - cornerLength, size.height - margin)
        ..lineTo(size.width - margin, size.height - margin)
        ..lineTo(size.width - margin, size.height - margin - cornerLength),
      paint,
    );

    // Marco central para barcode (más ancho que alto)
    final centerX = size.width / 2;
    final centerY = size.height * 0.42;
    final frameWidth = size.width * 0.65;
    final frameHeight = size.height * 0.18;

    final framePaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: frameWidth,
        height: frameHeight,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(frameRect, framePaint);

    // Línea de escaneo central
    final linePaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(centerX - frameWidth / 2 + 12, centerY),
      Offset(centerX + frameWidth / 2 - 12, centerY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarcodeOverlayPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
// Bottom sheet del producto encontrado
// ═════════════════════════════════════════════════════════════════════════════

class _ProductSheet extends ConsumerStatefulWidget {
  final OpenFoodFactsProduct product;
  final ImageService imageService;

  const _ProductSheet({required this.product, required this.imageService});

  @override
  ConsumerState<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<_ProductSheet> {
  late TextEditingController _gramsCtrl;
  bool _saving = false;
  String? _imageUrl;
  File? _userPhoto;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _gramsCtrl = TextEditingController(text: '100');
    _imageUrl = widget.product.imageFrontUrl;
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
        SnackBar(content: Text(l10n.scanGramsSnack)),
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
        } catch (e) {
          debugPrint('Error subiendo foto: $e');
          storedImageUrl = null;
        }
      } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        try {
          storedImageUrl = await widget.imageService.uploadProductImage(
            uid: uid,
            productId: docRef.id,
            sourceUrl: _imageUrl,
          );
        } catch (e) {
          debugPrint('Error con imagen OFF: $e');
          storedImageUrl = _imageUrl;
        }
      }

      await docRef.set({
        'name': product.name ?? 'Producto',
        'barcode': product.barcode,
        'quantity': '${grams.round()} g',
        'originalQuantity': '${grams.round()} g',
        'calories': product.calories ?? 0,
        'proteins': product.proteins ?? 0,
        'carbs': product.carbs ?? 0,
        'fats': product.fats ?? 0,
        'baseUnit': product.baseUnit,
        'isAvailable': true,
        'lastReplenished': FieldValue.serverTimestamp(),
        'category': inferPantryCategory(product),
        'imageUrl': storedImageUrl,
        'source': 'barcode',
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
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.nk.cat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: context.nk.cat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name ?? 'Producto',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.nk.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.brand != null)
                      Text(
                        p.brand!,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 12,
                          color: context.nk.textDim,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Foto del producto
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (_userPhoto != null || _imageUrl != null) return;
                  await _pickPhoto(ImageSource.camera);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.nk.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
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
                                color: context.nk.textFaint,
                                size: 22,
                              )
                            : Icon(
                                Icons.add_a_photo_rounded,
                                color: context.nk.textFaint,
                                size: 22,
                              ))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _userPhoto != null
                      ? l10n.scanPhotoCustom
                      : (p.imageFrontUrl != null
                            ? l10n.scanPhotoOff
                            : l10n.scanPhotoNone),
                  style: TextStyle(fontSize: 11, color: context.nk.textFaint),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Macros preview
          if (p.calories != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.nk.cat.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroPreview(
                    'KCAL',
                    p.calories!.toStringAsFixed(0),
                    context.nk.cat,
                  ),
                  _macroPreview(
                    'PROT',
                    '${p.proteins?.toStringAsFixed(0) ?? "0"}g',
                    context.nk.protein,
                  ),
                  _macroPreview(
                    'CARB',
                    '${p.carbs?.toStringAsFixed(0) ?? "0"}g',
                    context.nk.carbs,
                  ),
                  _macroPreview(
                    'GRASA',
                    '${p.fats?.toStringAsFixed(0) ?? "0"}g',
                    context.nk.fat,
                  ),
                ],
              ),
            ),
          if (p.baseUnit == 'ml')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.scanMacrosPer100ml,
                style: TextStyle(color: context.nk.danger, fontSize: 11),
              ),
            ),
          const SizedBox(height: 16),

          // Input de gramos
          TextField(
            controller: _gramsCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.nlQuantity,
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: l10n.scanGramsHint,
              prefixIcon: const Icon(
                Icons.scale_rounded,
                color: Colors.white60,
              ),
              suffixText: 'g',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Botón guardar
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
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
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.scanAddToPantry),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.nk.cat,
                foregroundColor: const Color(0xFF1A0F00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: context.nk.textFaint,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
