import '../core/neko_palette.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/category_inference.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';
import '../services/image_service.dart';
import '../services/nutrition_label_parser.dart';
import '../services/open_food_facts_service.dart';

/// Pantalla para cuando el usuario no encontró un producto por nombre y
/// quiere agregarlo fotografiando la tabla nutricional. Toma la foto,
/// corre OCR local con ML Kit, parsea heurísticamente, deja editar al
/// usuario y guarda el documento en la despensa con la foto subida
/// comprimida.
class NutritionLabelScreen extends ConsumerStatefulWidget {
  final String? prefilledName;
  final String? barcode;
  final OpenFoodFactsProduct? fromGuess;

  const NutritionLabelScreen({
    super.key,
    this.prefilledName,
    this.barcode,
    this.fromGuess,
  });

  @override
  ConsumerState<NutritionLabelScreen> createState() =>
      _NutritionLabelScreenState();
}

class _NutritionLabelScreenState extends ConsumerState<NutritionLabelScreen> {
  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _imageService = ImageService();
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);

  File? _photo;
  String? _rawText;
  bool _busy = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _gramsCtrl;
  late TextEditingController _calCtrl;
  late TextEditingController _proCtrl;
  late TextEditingController _carCtrl;
  late TextEditingController _fatCtrl;
  String _baseUnit = 'g';
  double _confidence = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefilledName ?? '');
    _gramsCtrl = TextEditingController(text: '100');
    _calCtrl = TextEditingController();
    _proCtrl = TextEditingController();
    _carCtrl = TextEditingController();
    _fatCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _nameCtrl.dispose();
    _gramsCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final photo = File(file.path);
      final parsed = await _textRecognizer.processImage(
        InputImage.fromFile(photo),
      );
      final raw = parsed.text;
      final result = NutritionLabelParser.parse(raw);
      setState(() {
        _photo = photo;
        _rawText = raw;
        _calCtrl.text = result.calories?.toStringAsFixed(1) ?? '';
        _proCtrl.text = result.proteins?.toStringAsFixed(1) ?? '';
        _carCtrl.text = result.carbs?.toStringAsFixed(1) ?? '';
        _fatCtrl.text = result.fats?.toStringAsFixed(1) ?? '';
        _baseUnit = result.baseUnit;
        _confidence = result.confidence;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).nlToastReadError(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast(AppLocalizations.of(context).nlToastName);
      return;
    }
    final grams = double.tryParse(_gramsCtrl.text.trim());
    if (grams == null || grams <= 0) {
      _toast(AppLocalizations.of(context).nlToastGrams);
      return;
    }
    final cal = double.tryParse(_calCtrl.text.trim());
    final pro = double.tryParse(_proCtrl.text.trim()) ?? 0;
    final car = double.tryParse(_carCtrl.text.trim()) ?? 0;
    final fat = double.tryParse(_fatCtrl.text.trim()) ?? 0;
    if (cal == null && pro == 0 && car == 0 && fat == 0) {
      _toast(AppLocalizations.of(context).nlToastOneMacro);
      return;
    }

    setState(() => _busy = true);
    try {
      final uid = _firebase.currentUser?.uid;
      if (uid == null) return;

      // Creamos el doc primero para tener un ID y poder subir la foto a
      // users/{uid}/pantry/{id}.jpg (regla del proyecto).
      final docRef = _firebase.db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc();

      String? imageUrl;
      if (_photo != null) {
        try {
          imageUrl = await _imageService.uploadProductImage(
            uid: uid,
            productId: docRef.id,
            file: _photo,
          );
        } catch (e) {
          // No bloqueamos el guardado por un fallo en la foto: el
          // usuario puede agregar la foto después desde la edición.
          if (!mounted) return;
          _toast(AppLocalizations.of(context).nlToastUpload);
        }
      }

      // Normalizamos los macros a /100g (o /100ml). Si el OCR los
      // detectó por 100ml, los multiplicamos por la densidad típica
      // 1 g/ml (aproximación segura para etiquetas colombianas) para
      // mantener el formato consistente del documento.
      await docRef.set({
        'name': name,
        'barcode': widget.barcode,
        'quantity': '${grams.round()} g',
        'originalQuantity': '${grams.round()} g',
        'calories': cal ?? 0,
        'proteins': pro,
        'carbs': car,
        'fats': fat,
        'baseUnit': _baseUnit,
        'isAvailable': true,
        'lastReplenished': FieldValue.serverTimestamp(),
        'category': widget.fromGuess != null
            ? inferPantryCategory(widget.fromGuess!)
            : 'Proteínas',
        'imageUrl': imageUrl,
        'source': 'ocr',
        'ocrConfidence': _confidence,
      });

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).nlToastSaved(name),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nlTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _photoPreview(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _takePhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: Text(l10n.nlCamera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _takePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.image_rounded),
                      label: Text(l10n.nlGallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _editableForm(),
              if (_rawText != null && _rawText!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.nlDetectedText,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.nk.textFaint,
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.nk.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Text(
                        _rawText!,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.nk.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(l10n.nlSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPreview() {
    if (_photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.file(_photo!, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: context.nk.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: context.nk.surfaceHigh, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 36,
              color: context.nk.textFaint,
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).nlPhotoHint,
              style: TextStyle(color: context.nk.textFaint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableForm() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: l10n.nlName,
            prefixIcon: const Icon(Icons.label_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _gramsCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.nlQuantity,
                  suffixText: 'g',
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.nk.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.nlTableUnit,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.nk.textFaint,
                      ),
                    ),
                    Text(
                      '/100$_baseUnit',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _macroField(l10n.nlCalories, 'kcal', _calCtrl),
        _macroField(l10n.nlProteins, 'g', _proCtrl),
        _macroField(l10n.nlCarbs, 'g', _carCtrl),
        _macroField(l10n.nlFats, 'g', _fatCtrl),
        if (_confidence > 0 && _confidence < 0.7)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.nlConfidenceDetected((_confidence * 100).round()),
              style: TextStyle(color: context.nk.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _macroField(String label, String suffix, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
  }
}
