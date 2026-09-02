import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../core/haptics.dart';
import '../data/outfits.dart';
import '../services/firebase_service.dart';
import '../services/image_service.dart';
import '../services/gemini_vision_service.dart';
import '../services/ai_exceptions.dart';
import '../services/pet_service.dart';
import '../models/pantry_item.dart';
import '../models/recognized_food.dart';
import '../models/meal_entry.dart';
import '../models/saved_recipe.dart';
import '../widgets/celebrations.dart';
import '../widgets/food_balloon.dart';
import '../widgets/neko_cat_mascot.dart';
import '../widgets/neko_sheet.dart';
import '../widgets/recipe_builder_sheet.dart';
import '../widgets/smart_label.dart';
import '../widgets/voice_meal_sheet.dart';

enum NekoFlashMode { off, on, auto }

/// Pantalla de escáner premium — cámara con overlay de escaneo,
/// animación de barrido y resultado con sliders.
class FoodScannerScreen extends ConsumerStatefulWidget {
  final List<PantryItem> pantryItems;
  final MealType initialMealType;
  const FoodScannerScreen({
    super.key,
    this.pantryItems = const [],
    this.initialMealType = MealType.lunch,
  });

  @override
  ConsumerState<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends ConsumerState<FoodScannerScreen>
    with TickerProviderStateMixin {
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);
  late final GeminiVisionService _gemini = ref.read(
    geminiVisionServiceProvider,
  );

  // Cámara
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _isProcessing = false;

  // Estado
  _ScannerTab _tab = _ScannerTab.scan;
  ScannerPhase _phase = ScannerPhase.camera;
  MealType _selectedType = MealType.lunch;
  String? _imagePath;
  Uint8List? _imageBytes;
  List<RecognizedFood> _recognizedFoods = [];
  String? _error;
  bool _saving = false;
  bool _fromCache = false;
  NekoFlashMode _flashMode = NekoFlashMode.auto;

  // ── Estado de celebración de la última guardada ──────────────────────
  // Se rellena en `_saveAllMeals` y la fase `ScannerPhase.success` lo
  // consume para mostrar confeti / brasas / subida de nivel.
  int _celebrationSeq = 0;
  bool _firstMealSaved = false;
  bool _streakMilestone = false;
  int _streakDays = 0;
  int? _levelUpTo;
  int _newXp = 0;
  int _xpGained = 0;
  double _xpMultiplier = 1.0;
  String _catName = 'Mochi';
  List<String> _unlockedNames = const [];

  // Bounding boxes de objetos detectados (ML Kit) para el overlay.
  // Los globos se siembran en `_balloons`; este campo quedó sin uso.
  double _imageWidth = 0;
  double _imageHeight = 0;

  // Globos flotantes premium: combinan bbox de ML Kit con macros de Gemini.
  // Mientras Gemini no responde, cada globo está en estado `pending` (spinner
  // en lugar de kcal). Cuando llega el resultado, se empareja por orden
  // (ML Kit y Gemini devuelven la misma cantidad de items por convención
  // del prompt) y el globo transiciona a `resolved`.
  List<FoodBalloonData> _balloons = [];
  int? _highlightedBalloonIndex;

  // Recetas guardadas
  List<SavedRecipe> _savedRecipes = [];
  bool _loadingRecipes = false;

  // Animaciones
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialMealType;
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    // Defer repeat animations to first frame so context.shouldAnimate is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.shouldAnimate) {
        _scanLineController.repeat();
        _pulseController.repeat(reverse: true);
      } else {
        // Reduced motion: park controllers at a static frame.
        _scanLineController.value = 0.5;
        _pulseController.value = 0.5;
      }
    });
    _initCamera();
    _loadSavedRecipes();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setError('No se encontró cámara');
        return;
      }
      // Cámara trasera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setError('Error cámara: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScanPressed() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }
    Haptics.tap();
    _captureAndAnalyze();
  }

  Future<void> _toggleFlash() async {
    setState(() {
      _flashMode = _flashMode == NekoFlashMode.auto
          ? NekoFlashMode.on
          : _flashMode == NekoFlashMode.on
              ? NekoFlashMode.off
              : NekoFlashMode.auto;
    });
    await _cameraController?.setFlashMode(_mapFlashMode(_flashMode));
    Haptics.select();
  }

  FlashMode _mapFlashMode(NekoFlashMode mode) {
    switch (mode) {
      case NekoFlashMode.off:
        return FlashMode.off;
      case NekoFlashMode.on:
        return FlashMode.always;
      case NekoFlashMode.auto:
        return FlashMode.auto;
    }
  }

  Future<void> _captureAndAnalyze() async {
    try {
      setState(() => _isProcessing = true);
      final xFile = await _cameraController!.takePicture();

      // Comprimir
      final bytes = await File(xFile.path).readAsBytes();
      final compressed = await ImageService.compressToTarget(bytes);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(compressed, flush: true);

      setState(() {
        _imagePath = tempFile.path;
        _imageBytes = Uint8List.fromList(compressed);
        _phase = ScannerPhase.scanning;
        _error = null;
        _isProcessing = false;
      });

      _analyzeImage();
      unawaited(_runObjectDetection());
    } catch (e) {
      setState(() {
        setError('Error al capturar: $e');
        _isProcessing = false;
      });
    }
  }

  void _onGalleryPressed() async {
    if (_isProcessing) return;
    Haptics.tap();

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;

    try {
      setState(() => _isProcessing = true);

      final bytes = await File(xFile.path).readAsBytes();
      final compressed = await ImageService.compressToTarget(bytes);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/gallery_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(compressed, flush: true);

      setState(() {
        _imagePath = tempFile.path;
        _imageBytes = Uint8List.fromList(compressed);
        _phase = ScannerPhase.scanning;
        _error = null;
        _isProcessing = false;
      });

      _analyzeImage();
      unawaited(_runObjectDetection());
    } catch (e) {
      setError('Error al cargar imagen: $e');
      setState(() => _isProcessing = false);
    }
  }

  /// Detección local de objetos (ML Kit) para dibujar los bounding boxes
  /// sobre la foto mientras Gemini analiza los macros.
  Future<void> _runObjectDetection() async {
    final path = _imagePath;
    if (path == null) return;

    final size = await ref.read(objectDetectionServiceProvider).imageSize(path);
    if (size != null && mounted) {
      setState(() {
        _imageWidth = size.$1.toDouble();
        _imageHeight = size.$2.toDouble();
      });
    }

    final objects = await ref.read(objectDetectionServiceProvider).detect(path);
    if (!mounted) return;

    // Sembrar globos en estado pending. Cuando Gemini responda, los
    // emparejamos por orden y los pasamos a resolved.
    final pending = objects
        .map(
          (o) => FoodBalloonData(
            detected: o,
            food: null,
            state: FoodBalloonState.pending,
          ),
        )
        .toList();

    setState(() {
      _balloons = pending;
    });
  }

  Future<void> _analyzeImage() async {
    if (_imagePath == null || _imageBytes == null) return;

    // 1) Intentamos reutilizar un resultado previo para esta misma imagen.
    final cached = await ref
        .read(foodScanCacheServiceProvider)
        .lookup(imageBytes: _imageBytes!, pantryItems: widget.pantryItems);
    if (cached != null && cached.isNotEmpty) {
      // Mantenemos la animación de "analizando" un instante para que el
      // usuario perciba que la app reaccionó y no salte directo al resultado.
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _fadeToZero();
      setState(() {
        _recognizedFoods = cached;
        _fromCache = true;
        _phase = ScannerPhase.result;
        _balloons = _pairBalloonsWithFoods(_balloons, cached);
      });
      _fadeToOne();
      return;
    }

    try {
      final results = await _gemini.identifyFood(
        imagePath: _imagePath!,
        pantryItems: widget.pantryItems,
      );

      if (results.isEmpty) {
        setState(() {
        setError('No se identificaron alimentos');
          _phase = ScannerPhase.camera;
        });
        return;
      }

      // 2) Sin cache hit: persistimos para el próximo escaneo similar.
      unawaited(
        ref
            .read(foodScanCacheServiceProvider)
            .store(
              imageBytes: _imageBytes!,
              pantryItems: widget.pantryItems,
              foods: results,
            ),
      );

      // Transición suave a resultados
      await _fadeToZero();
      setState(() {
        _recognizedFoods = results;
        _fromCache = false;
        _phase = ScannerPhase.result;
        _balloons = _pairBalloonsWithFoods(_balloons, results);
      });
      _fadeToOne();
    } catch (e) {
      setError(_friendlyGeminiError(e));
      setState(() {
        _phase = ScannerPhase.camera;
      });
    }
  }

  /// Clasifica errores de Gemini y devuelve un mensaje amigable.
  static String _friendlyGeminiError(Object e) {
    if (e is AIException && e.userMessage != null) return e.userMessage!;
    final msg = e.toString().toLowerCase();
    if (msg.contains('429') || msg.contains('quota') || msg.contains('rate')) {
      return 'Gemini está ocupado. Espera un momento y vuelve a intentar.';
    }
    if (msg.contains('timeout') || msg.contains('deadline')) {
      return 'La IA tardó demasiado. Revisa tu conexión e intenta de nuevo.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return 'Sin conexión a internet. Verifica tu red y vuelve a intentar.';
    }
    if (msg.contains('no devolió respuesta') || msg.contains('empty')) {
      return 'No pude identificar el plato. Intenta con otra foto.';
    }
    return 'Algo falló con la IA. Toca retry o registra manualmente.';
  }

  /// Obtiene todos los documentos de comidas registradas HOY por el usuario.
  /// Se usa para verificar si el día tiene las 4 comidas completas antes de
  /// avanzar la racha.
  Future<List<Map<String, dynamic>>> _fetchTodayMeals(String uid) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final snap = await _firebase.db
          .collection('users')
          .doc(uid)
          .collection('meals')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'createdAt',
            isLessThan: Timestamp.fromDate(endOfDay),
          )
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Empareja los globos pendientes con los alimentos identificados por
  /// Gemini. La estrategia es 1:1 por orden: si el detector de ML Kit
  /// encontró N objetos y Gemini devolvió M componentes, los primeros
  /// `min(N, M)` globos se marcan como resolved. Los que sobren se
  /// quedan como pending (mostrando solo la clase de ML Kit).
  ///
  /// Si Gemini devolvió más componentes que detecciones de ML Kit, los
  /// excedentes se agregan como globos nuevos sin bbox (no se muestran
  /// sobre la imagen, pero el recibo debajo sigue completo).
  List<FoodBalloonData> _pairBalloonsWithFoods(
    List<FoodBalloonData> existing,
    List<RecognizedFood> foods,
  ) {
    final paired = <FoodBalloonData>[];
    final n = existing.length < foods.length ? existing.length : foods.length;
    for (var i = 0; i < n; i++) {
      paired.add(
        existing[i].copyWith(food: foods[i], state: FoodBalloonState.resolved),
      );
    }
    // Globos sin match de Gemini: quedan pending.
    for (var i = n; i < existing.length; i++) {
      paired.add(existing[i]);
    }
    return paired;
  }

  Future<void> _saveAllMeals() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final mealsRef = _firebase.db
          .collection('users')
          .doc(uid)
          .collection('meals');

      // ¿Es la primera comida guardada jamás? → confeti al final.
      int existingCount = 0;
      try {
        existingCount = (await mealsRef.count().get()).count ?? 0;
      } catch (_) {}
      final isFirstMeal = existingCount == 0;

      for (final food in _recognizedFoods) {
        // 1. Crear el documento para obtener su id y usarlo en Storage.
        final mealRef = mealsRef.doc();

        // 2. Subir la foto a Storage (si hay una capturada) y obtener la URL.
        String? imageUrl;
        if (_imagePath != null) {
          try {
            final ref = FirebaseStorage.instance.ref().child(
              'users/$uid/meals/${mealRef.id}.jpg',
            );
            final task = await ref.putFile(
              File(_imagePath!),
              SettableMetadata(
                contentType: 'image/jpeg',
                cacheControl: 'public, max-age=31536000',
              ),
            );
            imageUrl = await task.ref.getDownloadURL();
          } catch (e) {
            // Si falla la subida seguimos guardando la comida sin foto,
            // para no bloquear al usuario; el campo imageUrl quedará null.
            debugPrint('FoodScanner: no se pudo subir la foto: $e');
          }
        }

        // 3. Persistir la comida con la URL de la foto.
        await mealRef.set({
          'mealType': _selectedType.name,
          'foodName': food.name,
          'grams': food.estimatedGrams,
          'calories': food.calories,
          'proteins': food.proteins,
          'carbs': food.carbs,
          'fats': food.fats,
          'createdAt': FieldValue.serverTimestamp(),
          'pantryItemId': food.pantryItemId,
          'imageUrl': imageUrl,
        });

        if (food.pantryItemId != null && food.pantryItemId!.isNotEmpty) {
          final ok = await _deductFromPantry(
            uid,
            food.pantryItemId!,
            food.estimatedGrams,
          );
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se pudo descontar "${food.name}" de la despensa. Revisala.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      // Feedback táctil: comida guardada.
      Haptics.success();

      final todayMeals = await _fetchTodayMeals(uid);
      final streakResult = await ref
          .read(streakServiceProvider)
          .updateStreakOnMealLogged(uid, todayMeals: todayMeals);

      // El consumo cambió: recalcular notificaciones inteligentes (18:00,
      // 19:00, 20:00, 21:00) con los datos frescos. Best-effort.
      await ref
          .read(notificationServiceProvider)
          .scheduleContextualNotifications();

      // ── Celebrar: alimentar mascota, racha, outfits ──────────────────
      final currentStreak = streakResult['currentStreak'] ?? 0;
      final longestStreak = streakResult['longestStreak'] ?? 0;

      // Nuevo récord de racha → feedback de logro + alerta del gato
      // (el dot rojo de la pestaña Mascota se enciende).
      if (currentStreak > 1 && currentStreak == longestStreak) {
        Haptics.success();
        ref.read(catAlertServiceProvider).bump();
      }
      final totalKcal = _recognizedFoods.fold<double>(
        0,
        (acc, f) => acc + f.calories,
      );
      final totalProtein = _recognizedFoods.fold<double>(
        0,
        (acc, f) => acc + f.proteins,
      );

      FeedResult feed = FeedResult.none;
      try {
        feed = await ref
            .read(petServiceProvider)
            .feedPet(
              uid,
              kcal: totalKcal,
              proteinGrams: totalProtein,
              streak: currentStreak,
            );
      } catch (e) {
        debugPrint('FoodScanner: error alimentando mascota: $e');
      }

      bool streakMilestone = false;
      List<String> unlockedIds = [...feed.newlyUnlockedOutfits];
      String catName = 'Mochi';
      final userRef = _firebase.db.collection('users').doc(uid);
      try {
        if (currentStreak > 0 && currentStreak % 7 == 0) {
          final userSnap = await userRef.get();
          final lastCelebrated =
              (userSnap.data()?['lastStreakMilestone'] as num?)?.toInt() ?? 0;
          // Solo se celebra la primera vez que se alcanza cada hito.
          if (currentStreak > lastCelebrated) {
            streakMilestone = true;
            await userRef.set({
              'lastStreakMilestone': currentStreak,
            }, SetOptions(merge: true));
          }
        }
        // Outfits por racha (p. ej. Gafas de Sol a 7 días, Corona a 14).
        final streakUnlocks = await ref
            .read(petServiceProvider)
            .unlockEligibleOutfits(uid, streak: currentStreak);
        unlockedIds = [...unlockedIds, ...streakUnlocks];

        final userSnap = await userRef.get();
        final rawCat = userSnap.data()?['catName'] as String?;
        if (rawCat != null && rawCat.trim().isNotEmpty) catName = rawCat.trim();
      } catch (e) {
        debugPrint('FoodScanner: error celebrando: $e');
      }

      // Subida de nivel → feedback de logro (además de la celebración visual).
      if (feed.levelsGained > 0) Haptics.success();

      if (!mounted) return;
      setState(() {
        _celebrationSeq++;
        _firstMealSaved = isFirstMeal;
        _streakMilestone = streakMilestone;
        _streakDays = currentStreak;
        _levelUpTo = feed.levelsGained > 0 ? feed.state.level : null;
        _newXp = feed.state.xp;
        _xpGained = feed.xpGain;
        _xpMultiplier = feed.multiplier;
        _catName = catName;
        _unlockedNames = unlockedIds
            .map((id) => Outfits.byId(id)?.nombre ?? id)
            .toList();
        _phase = ScannerPhase.success;
      });
      await Future.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _deductFromPantry(
    String uid,
    String pantryItemId,
    double consumedGrams,
  ) async {
    try {
      final doc = await _firebase.db
          .collection('users')
          .doc(uid)
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

      await _firebase.db
          .collection('users')
          .doc(uid)
          .collection('pantry')
          .doc(pantryItemId)
          .update({
            'quantity': remaining <= 0
                ? '0 $baseUnit'
                : '${remaining.round()} $baseUnit',
            if (remaining <= 0) 'isAvailable': false,
          });
      return true;
    } catch (e) {
      debugPrint('FoodScanner: error descontando despensa: $e');
      return false;
    }
  }

  void setError(String msg) {
    setState(() => _error = msg);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _error == msg) {
        setState(() => _error = null);
      }
    });
  }

  /// Fade transition that respects reduced motion.
  Future<void> _fadeToZero() {
    if (!context.shouldAnimate) {
      _fadeController.value = 0.0;
      return Future.value();
    }
    return _fadeController.reverse();
  }

  Future<void> _fadeToOne() {
    if (!context.shouldAnimate) {
      _fadeController.value = 1.0;
      return Future.value();
    }
    return _fadeToOne();
  }

  void _reset() {
    setState(() {
      _phase = ScannerPhase.camera;
      _imagePath = null;
      _imageBytes = null;
      _recognizedFoods = [];
      _balloons = [];
      _highlightedBalloonIndex = null;
      _imageWidth = 0;
      _imageHeight = 0;
      _error = null;
      _fromCache = false;
    });
    if (_cameraController != null && !_cameraController!.value.isInitialized) {
      _initCamera();
    }
  }

  Future<List<PantryItem>> _loadPantry(String uid) async {
    final snap = await _firebase.db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .get();
    return snap.docs
        .where((d) => (d.data()['isAvailable'] as bool?) ?? true)
        .map((d) => PantryItem.fromMap(d.data(), d.id))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // RECETAS GUARDADAS
  // ═════════════════════════════════════════════════════════════════════════════

  Future<void> _loadSavedRecipes() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingRecipes = true);
    try {
      final snap = await _firebase.db
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .orderBy('createdAt', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _savedRecipes = snap.docs.map(SavedRecipe.fromDoc).toList();
        _loadingRecipes = false;
      });
    } catch (e) {
      debugPrint('FoodScanner: error cargando recetas: $e');
      if (mounted) setState(() => _loadingRecipes = false);
    }
  }

  Future<void> _useSavedRecipe(SavedRecipe recipe) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nk.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          recipe.name,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.nk.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${recipe.ingredients.length} ingredientes  ·  ${recipe.totalCalories.toStringAsFixed(0)} kcal',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 12,
                color: context.nk.textDim,
              ),
            ),
            const SizedBox(height: 10),
            ...recipe.ingredients.map(
              (ing) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ing.name,
                        style: TextStyle(
                          color: context.nk.text,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${ing.grams.toStringAsFixed(0)}g',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11,
                        color: context.nk.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Se descontarán los ingredientes de tu despensa.',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11,
                color: context.nk.textFaint.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: context.nk.textDim),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nk.cat,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      for (final ing in recipe.ingredients) {
        await _firebase.db
            .collection('users')
            .doc(uid)
            .collection('meals')
            .doc()
            .set({
              'mealType': recipe.mealType,
              'foodName': ing.name,
              'grams': ing.grams,
              'calories': ing.calories,
              'proteins': ing.proteins,
              'carbs': ing.carbs,
              'fats': ing.fats,
              'createdAt': FieldValue.serverTimestamp(),
              'pantryItemId': ing.pantryItemId,
              'imageUrl': null,
            });
        if (ing.pantryItemId.isNotEmpty) {
          await _deductFromPantry(uid, ing.pantryItemId, ing.grams);
        }
      }

      final todayMeals2 = await _fetchTodayMeals(uid);
      final streakResult = await ref
          .read(streakServiceProvider)
          .updateStreakOnMealLogged(uid, todayMeals: todayMeals2);
      await ref
          .read(notificationServiceProvider)
          .scheduleContextualNotifications();

      try {
        final feed = await ref
            .read(petServiceProvider)
            .feedPet(
              uid,
              kcal: recipe.totalCalories,
              proteinGrams: recipe.totalProteins,
            );
        final currentStreak = streakResult['currentStreak'] ?? 0;
        final unlocks = await ref
            .read(petServiceProvider)
            .unlockEligibleOutfits(uid, streak: currentStreak);
        final newNames = [
          ...feed.newlyUnlockedOutfits,
          ...unlocks,
        ].map((id) => Outfits.byId(id)?.nombre ?? id).join(', ');
        if ((feed.levelsGained > 0 || newNames.isNotEmpty) && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                feed.levelsGained > 0
                    ? '¡Nivel ${feed.state.level}! ${newNames.isNotEmpty ? 'Desbloqueaste: $newNames' : 'La mascota creció.'}'
                    : 'Outfit desbloqueado: $newNames',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('FoodScanner: error celebrando receta guardada: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${recipe.name} registrada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('FoodScanner: error usando receta guardada: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar la receta.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Modo Receta: abre el builder de recetas y persiste cada ingrediente
  /// como comida (mismo patrón que el escáner) descontando de la despensa.
  Future<void> _openRecipeMode() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final pantry = await _loadPantry(uid);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.nk.surface,
      builder: (ctx) => RecipeBuilderSheet(
        pantryItems: pantry,
        mealType: _selectedType,
        onSave: (ingredients, {required name}) async {
          try {
            // 1. Guardar la receta para uso futuro
            await _firebase.db
                .collection('users')
                .doc(uid)
                .collection('recipes')
                .doc()
                .set(
                  SavedRecipe(
                    id: '',
                    name: name,
                    mealType: _selectedType.name,
                    ingredients: ingredients
                        .map(
                          (i) => SavedIngredient(
                            name: i.source.name,
                            grams: i.grams,
                            caloriesPer100: i.source.calories,
                            proteinsPer100: i.source.proteins,
                            carbsPer100: i.source.carbs,
                            fatsPer100: i.source.fats,
                            pantryItemId: i.source.id,
                          ),
                        )
                        .toList(),
                    totalCalories: ingredients.fold<double>(
                      0,
                      (a, b) => a + b.calories,
                    ),
                    totalProteins: ingredients.fold<double>(
                      0,
                      (a, b) => a + b.proteins,
                    ),
                    totalCarbs: ingredients.fold<double>(
                      0,
                      (a, b) => a + b.carbs,
                    ),
                    totalFats: ingredients.fold<double>(
                      0,
                      (a, b) => a + b.fats,
                    ),
                    createdAt: DateTime.now(),
                  ).toMap(),
                );

            // 2. Registrar cada ingrediente como comida individual
            for (final ing in ingredients) {
              await _firebase.db
                  .collection('users')
                  .doc(uid)
                  .collection('meals')
                  .doc()
                  .set({
                    'mealType': _selectedType.name,
                    'foodName': ing.source.name,
                    'grams': ing.grams,
                    'calories': ing.calories,
                    'proteins': ing.proteins,
                    'carbs': ing.carbs,
                    'fats': ing.fats,
                    'createdAt': FieldValue.serverTimestamp(),
                    'pantryItemId': ing.source.id,
                    'imageUrl': null,
                  });
              await _deductFromPantry(uid, ing.source.id, ing.grams);
            }
            final todayMeals3 = await _fetchTodayMeals(uid);
            final streakResult = await ref
                .read(streakServiceProvider)
                .updateStreakOnMealLogged(uid, todayMeals: todayMeals3);
            await ref
                .read(notificationServiceProvider)
                .scheduleContextualNotifications();

            // Celebrar (no hay pantalla de éxito aquí: snackbar best-effort).
            try {
              final totalKcal = ingredients.fold<double>(
                0,
                (acc, ing) => acc + ing.calories,
              );
              final totalProtein = ingredients.fold<double>(
                0,
                (acc, ing) => acc + ing.proteins,
              );
              final feed = await ref
                  .read(petServiceProvider)
                  .feedPet(uid, kcal: totalKcal, proteinGrams: totalProtein);
              final currentStreak = streakResult['currentStreak'] ?? 0;
              final unlocks = await ref
                  .read(petServiceProvider)
                  .unlockEligibleOutfits(uid, streak: currentStreak);
              final newNames = [
                ...feed.newlyUnlockedOutfits,
                ...unlocks,
              ].map((id) => Outfits.byId(id)?.nombre ?? id).join(', ');
              if ((feed.levelsGained > 0 || newNames.isNotEmpty) && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      feed.levelsGained > 0
                          ? '¡Nivel ${feed.state.level}! ${newNames.isNotEmpty ? 'Desbloqueaste: $newNames' : 'La mascota creció.'}'
                          : 'Outfit desbloqueado: $newNames',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              debugPrint('FoodScanner: error celebrando receta: $e');
            }
            _loadSavedRecipes();
            return true;
          } catch (e) {
            debugPrint('FoodScanner: error guardando receta: $e');
            return false;
          }
        },
      ),
    );
  }

  /// Modo Voz: dicta qué comiste, Gemini lo interpreta y se muestra el
  /// mismo flujo de resultado/guardado del escáner.
  Future<void> _openVoiceMode() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final pantry = await _loadPantry(uid);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.nk.surface,
      builder: (ctx) => VoiceMealSheet(
        mealType: _selectedType,
        onSubmit: (transcript) async {
          try {
            final foods = await _gemini.identifyFromText(
              transcript: transcript,
              pantryItems: pantry,
            );
            if (!mounted) return;
            setState(() {
              _tab = _ScannerTab.scan;
              _phase = ScannerPhase.result;
              _recognizedFoods = foods;
              _fromCache = false;
              _error = null;
            });
            _fadeToOne();
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_FoodScannerScreenState._friendlyGeminiError(e)),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Opacity(opacity: _fadeController.value, child: child);
        },
        child: _buildCurrentPhase(),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    switch (_tab) {
      case _ScannerTab.recipe:
        return _buildRecipeTab();
      case _ScannerTab.voice:
        return _buildModePlaceholder(isRecipe: false, onTap: _openVoiceMode);
      case _ScannerTab.scan:
        break;
    }
    switch (_phase) {
      case ScannerPhase.camera:
        return _buildCameraPhase();
      case ScannerPhase.scanning:
        return _buildScanningPhase();
      case ScannerPhase.result:
        return _buildResultPhase();
      case ScannerPhase.success:
        return _buildSuccessPhase();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // FASE 1: Cámara con overlay premium
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildCameraPhase() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview de cámara en vivo
        if (_cameraReady && _cameraController != null)
          Center(child: CameraPreview(_cameraController!))
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0A0F), Color(0xFF12121A)],
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(color: context.nk.cat),
            ),
          ),

        // Overlay de esquinas con exterior oscurecido
        _buildScanOverlay(),

        // Header
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

        // Pestañas de modo: Escáner / Receta / Voz
        Positioned(top: 86, left: 0, right: 0, child: _buildModeTabs()),

        // Hint flotante — centra la atención en el plato
        Positioned(
          top: 150,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final glow = 0.5 + (_pulseController.value * 0.5);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.nk.cat.withValues(alpha: 0.3 * glow),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.center_focus_strong_rounded,
                        size: 14,
                        color: context.nk.cat.withValues(alpha: glow),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CENTRA TU PLATO EN EL RECUADRO',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Footer con botón de escanear + tip inferior
        Positioned(bottom: 0, left: 0, right: 0, child: _buildCameraFooter()),

        // Error
        if (_error != null) _buildErrorBanner(),
      ],
    );
  }

  Widget _buildCameraFooter() {
    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tip contextual — cambia según haya despensa o no
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.pantryItems.isEmpty
                  ? 'Sin despensa aún — registra todo lo que veas'
                  : '${widget.pantryItems.length} productos en tu despensa listos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildScanButton(),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final opacity = 0.6 + (_pulseController.value * 0.3);
        return CustomPaint(
          painter: _ScanOverlayPainter(opacity: opacity, catColor: context.nk.cat),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Back con halo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESCANEAR COMIDA',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.nk.cat,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Pill selector del tipo de comida
                  GestureDetector(
                    onTap: _showMealTypePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _mealTypeIcon(_selectedType),
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedType.displayName,
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.55),
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
  }

  IconData _mealTypeIcon(MealType t) {
    switch (t) {
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

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case NekoFlashMode.off:
        return Icons.flash_off_rounded;
      case NekoFlashMode.on:
        return Icons.flash_on_rounded;
      case NekoFlashMode.auto:
        return Icons.flash_auto_rounded;
    }
  }

  Future<void> _showMealTypePicker() async {
    Haptics.select();
    final picked = await NekoSheet.show<MealType>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TIPO DE COMIDA',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.nk.textDim,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          for (final t in MealType.values)
            ListTile(
              leading: Icon(
                _mealTypeIcon(t),
                size: 20,
                color: context.nk.text,
              ),
              title: Text(
                t.displayName,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.nk.text,
                ),
              ),
              trailing: _selectedType == t
                  ? Icon(
                      Icons.check_rounded,
                      color: context.nk.cat,
                      size: 18,
                    )
                  : null,
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    );
    if (picked != null && picked != _selectedType && mounted) {
      setState(() => _selectedType = picked);
    }
  }

  Widget _buildScanButton() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Slot izquierdo — galería: elegir foto del dispositivo
          GestureDetector(
            onTap: _onGalleryPressed,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 28),
          GestureDetector(
            onTap: _onScanPressed,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 1.0 + (_pulseController.value * 0.04);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.nk.cat.withValues(alpha: 0.45),
                          blurRadius: 24 + (_pulseController.value * 8),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [context.nk.cat, context.nk.catShadow],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_rounded,
                          size: 28,
                          color: Color(0xFF1A0F00),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 28),
          // Slot derecho — control de flash
          GestureDetector(
            onTap: _toggleFlash,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(
                _getFlashIcon(),
                size: 20,
                color: _flashMode == NekoFlashMode.off
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Pestañas de modo: Escáner / Crear receta / Describir por voz
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildModeTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            children: [
              _modeTab(_ScannerTab.scan, Icons.camera_alt_rounded, 'Escáner'),
              _modeTab(_ScannerTab.recipe, Icons.menu_book_rounded, 'Receta'),
              _modeTab(_ScannerTab.voice, Icons.mic_rounded, 'Voz'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(_ScannerTab tab, IconData icon, String label) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptics.select();
          setState(() => _tab = tab);
        },
        child: AnimatedContainer(
          duration: context.shouldAnimate ? const Duration(milliseconds: 200) : Duration.zero,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? context.nk.cat.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? context.nk.cat
                    : Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? context.nk.cat
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // FASE RECETA: Lista de recetas guardadas + crear nueva
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildRecipeTab() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0C20), Color(0xFF0A0818)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'RECETAS',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.nk.cat,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildModeTabs(),
              const SizedBox(height: 8),

              // "Crear receta" CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _openRecipeMode,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.nk.cat, context.nk.catShadow],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: context.nk.cat.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Crear receta',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // "Mis recetas" label
              if (_savedRecipes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'MIS RECETAS',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.nk.textDim,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${_savedRecipes.length}',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.nk.cat,
                        ),
                      ),
                    ],
                  ),
                ),

              // Recipe list
              Expanded(
                child: _loadingRecipes
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.nk.cat,
                          strokeWidth: 2,
                        ),
                      )
                    : _savedRecipes.isEmpty
                    ? _buildEmptyRecipes()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        itemCount: _savedRecipes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildRecipeCard(_savedRecipes[index]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRecipes() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NekoCatMascot(mood: CatMood.idle, size: 80),
          const SizedBox(height: 16),
          Text(
            'Sin recetas guardadas',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Crea tu primera receta arriba',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(SavedRecipe recipe) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _useSavedRecipe(recipe),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.nk.cat.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 14,
                      color: context.nk.cat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.nk.cat.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      recipe.mealType.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: context.nk.cat,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _recipeMacro(
                    '${recipe.totalCalories.toStringAsFixed(0)} kcal',
                    context.nk.cat,
                  ),
                  SizedBox(width: 10),
                  _recipeMacro(
                    'P ${recipe.totalProteins.toStringAsFixed(0)}g',
                    context.nk.protein,
                  ),
                  SizedBox(width: 10),
                  _recipeMacro(
                    'C ${recipe.totalCarbs.toStringAsFixed(0)}g',
                    context.nk.carbs,
                  ),
                  SizedBox(width: 10),
                  _recipeMacro(
                    'G ${recipe.totalFats.toStringAsFixed(0)}g',
                    context.nk.fat,
                  ),
                  Spacer(),
                  Text(
                    '${recipe.ingredients.length} ing.',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      color: context.nk.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recipeMacro(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildModePlaceholder({
    required bool isRecipe,
    required VoidCallback onTap,
  }) {
    final IconData heroIcon = isRecipe
        ? Icons.menu_book_rounded
        : Icons.mic_rounded;
    final String heroTitle = isRecipe
        ? 'Recetas personalizadas'
        : 'Comida por voz';
    final String heroSubtitle = isRecipe
        ? 'Arma una receta eligiendo ingredientes de tu despensa y las cantidades que usaste.'
        : 'Dicta o escribe qué comiste. NekoFit identificará los alimentos por ti.';
    final String ctaLabel = isRecipe ? 'Crear receta' : 'Empezar a dictar';

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0C20), Color(0xFF0A0818)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRecipe ? 'CREAR RECETA' : 'DESCRIBIR POR VOZ',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.nk.cat,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildModeTabs(),
              Spacer(),
              NekoCatMascot(mood: CatMood.idle, size: 100),
              SizedBox(height: 24),
              Icon(heroIcon, size: 44, color: context.nk.cat),
              const SizedBox(height: 12),
              Text(
                heroTitle,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  heroSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.nk.cat, context.nk.catShadow],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: context.nk.cat.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(heroIcon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          ctaLabel,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // FASE 2: Escaneando — animación de barrido
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildScanningPhase() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Foto capturada como fondo
        if (_imagePath != null)
          Image.file(
            File(_imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFF0A0A0F)),
          )
        else
          Container(color: const Color(0xFF0A0A0F)),

        // Overlay oscuro semi-transparente
        Container(color: Colors.black.withValues(alpha: 0.3)),

        // Globos flotantes premium (ML Kit bbox + Gemini macros)
        if (_balloons.isNotEmpty && _imageWidth > 0 && _imageHeight > 0)
          Positioned.fill(
            child: FloatingFoodBalloons(
              balloons: _balloons,
              imageNaturalWidth: _imageWidth,
              imageNaturalHeight: _imageHeight,
              highlightedIndex: _highlightedBalloonIndex,
              onBalloonTap: (i, _) {
                Haptics.select();
                setState(() {
                  _highlightedBalloonIndex = _highlightedBalloonIndex == i
                      ? null
                      : i;
                });
              },
            ),
          ),

        // Overlay de esquinas
        _buildScanOverlay(),

        // Línea de escaneo animada
        AnimatedBuilder(
          animation: _scanLineController,
          builder: (context, _) {
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              left: 24,
              right: 24,
              child: ClipRect(
                child: Align(
                  alignment: Alignment(0, -1 + (_scanLineController.value * 2)),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          context.nk.cat.withValues(alpha: 0.8),
                          context.nk.cat,
                          context.nk.cat.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.nk.cat.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Header
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

        // Indicador de escaneo
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.nk.cat.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.nk.cat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Analizando tu comida...',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // NekoFit mascot thinking
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Center(child: NekoCatMascot(mood: CatMood.thinking, size: 80)),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // FASE 3: Resultados — recibo de konbini
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildResultPhase() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0C20), Color(0xFF0A0818)],
            ),
          ),
        ),

        // Header — RECIBO DE COMIDA + sello con la foto capturada
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(child: _buildReceiptHeader()),
        ),

        // Ticket del recibo — un renglón por alimento
        Positioned(
          top: 116,
          left: 16,
          right: 16,
          bottom: 162,
          child: _buildReceiptTicket(),
        ),

        // Pie del recibo — total + registrar
        Positioned(bottom: 0, left: 0, right: 0, child: _buildSaveBar()),
      ],
    );
  }

  // ── Cabecera del recibo ──
  Widget _buildReceiptHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: _reset,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'RECIBO DE COMIDA',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.nk.cat,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (_fromCache) ...[
                      const SizedBox(width: 8),
                      _cacheBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_recognizedFoods.length} alimento${_recognizedFoods.length > 1 ? 's' : ''} identificado${_recognizedFoods.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildPhotoThumbnail(),
        ],
      ),
    );
  }

  Widget _cacheBadge() {
    return Tooltip(
      message: 'Resultado recuperado instantáneamente del caché local',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.nk.amber.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 10, color: context.nk.amberSoft),
            SizedBox(width: 3),
            Text(
              'CACHÉ',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: context.nk.amberSoft,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sello con la foto capturada ──
  Widget _buildPhotoThumbnail() {
    final path = _imagePath;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: context.nk.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(
          color: context.nk.cat.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.chip - 1),
        child: path != null
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _PhotoStampPlaceholder(),
              )
            : _PhotoStampPlaceholder(),
      ),
    );
  }

  // ── Ticket del recibo ──
  Widget _buildReceiptTicket() {
    final decoration = BoxDecoration(
      color: context.nk.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: context.nk.cat.withValues(alpha: 0.2), width: 1),
    );

    if (_recognizedFoods.isEmpty) {
      // Recibo vacío — sigue leyéndose como un ticket.
      return Container(
        decoration: decoration,
        child: Center(          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 26,
                color: context.nk.textFaint,
              ),
              SizedBox(height: 8),
              Text(
                'Sin alimentos en el recibo',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.nk.textFaint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card - 1),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _recognizedFoods.length,
          separatorBuilder: (context, index) => _dottedDivider(),
          itemBuilder: (context, index) {
            return _buildReceiptLineItem(_recognizedFoods[index], index);
          },
        ),
      ),
    );
  }

  Widget _dottedDivider() {
    return CustomPaint(
      painter: _DottedLinePainter(lineColor: context.nk.textFaint),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }

  /// Renglón del recibo: número de línea, nombre editable, etiquetas
  /// inteligentes, slider de porción y macros (tap para editar).
  Widget _buildReceiptLineItem(RecognizedFood food, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea: número de renglón + nombre editable + eliminar
          Row(
            children: [
              Text(
                (index + 1).toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.nk.textFaint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _editFoodName(index),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          food.name,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.nk.text,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: context.nk.textDim,
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _recognizedFoods.removeAt(index));
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.nk.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: context.nk.danger.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Etiquetas inteligentes — identifican de un vistazo la comida
          SmartLabelStrip(food: food),

          const SizedBox(height: 14),

          // Slider de porción
          Row(
            children: [
              Text(
                'PORCIÓN',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: context.nk.textDim,
                  letterSpacing: 1,
                ),
              ),
              Spacer(),
              Text(
                '${food.estimatedGrams.toStringAsFixed(0)} g',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.nk.cat,
                ),
              ),
            ],
          ),
          Semantics(
            label: 'Ajustar porción de ${food.name}',
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: context.nk.cat,
                inactiveTrackColor: context.nk.surfaceHigh,
                thumbColor: context.nk.cat,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 4,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: food.estimatedGrams,
                min: 10,
                max: 500,
                divisions: 49,
                onChanged: (v) {
                  setState(() {
                    _recognizedFoods[index] = food.withGrams(v);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Macros — tap para editar
          GestureDetector(
            onTap: () => _editFoodMacros(index),
            child: Row(
              children: [
                _macroColumn(
                  'KCAL',
                  food.calories.toStringAsFixed(0),
                  context.nk.cat,
                ),
                _macroColumn(
                  'PROT',
                  '${food.proteins.toStringAsFixed(0)}g',
                  context.nk.protein,
                ),
                _macroColumn(
                  'CARB',
                  '${food.carbs.toStringAsFixed(0)}g',
                  context.nk.carbs,
                ),
                _macroColumn(
                  'GRASA',
                  '${food.fats.toStringAsFixed(0)}g',
                  context.nk.fat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: context.nk.textDim,
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
      ),
    );
  }

  void _editFoodName(int index) {
    final food = _recognizedFoods[index];
    final controller = TextEditingController(text: food.name);

    NekoSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EDITAR NOMBRE',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.nk.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Nombre del alimento',
              hintStyle: TextStyle(
                fontFamily: AppFonts.sans,
                color: context.nk.textDim,
              ),
              filled: true,
              fillColor: context.nk.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.nk.cat),
              ),
            ),
            onSubmitted: (_) {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _recognizedFoods[index] = food.copyWith(name: newName);
                });
              }
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _recognizedFoods[index] = food.copyWith(name: newName);
                  });
                }
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.nk.cat, context.nk.catShadow],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Guardar',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editFoodMacros(int index) {
    final food = _recognizedFoods[index];
    final calCtrl = TextEditingController(
      text: food.caloriesPer100.toStringAsFixed(0),
    );
    final protCtrl = TextEditingController(
      text: food.proteinsPer100.toStringAsFixed(0),
    );
    final carbCtrl = TextEditingController(
      text: food.carbsPer100.toStringAsFixed(0),
    );
    final fatCtrl = TextEditingController(
      text: food.fatsPer100.toStringAsFixed(0),
    );

    NekoSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EDITAR MACROS (por 100g)',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.nk.textDim,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _macroInput('KCAL', calCtrl, context.nk.cat)),
              SizedBox(width: 12),
              Expanded(
                child: _macroInput(
                  'PROT (g)',
                  protCtrl,
                  context.nk.protein,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _macroInput('CARB (g)', carbCtrl, context.nk.carbs),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _macroInput('GRASA (g)', fatCtrl, context.nk.fat),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                final cal =
                    double.tryParse(calCtrl.text) ?? food.caloriesPer100;
                final prot =
                    double.tryParse(protCtrl.text) ?? food.proteinsPer100;
                final carb =
                    double.tryParse(carbCtrl.text) ?? food.carbsPer100;
                final fat = double.tryParse(fatCtrl.text) ?? food.fatsPer100;
                setState(() {
                  _recognizedFoods[index] = food.copyWith(
                    caloriesPer100: cal,
                    proteinsPer100: prot,
                    carbsPer100: carb,
                    fatsPer100: fat,
                  );
                });
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.nk.cat, context.nk.catShadow],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Guardar',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroInput(
    String label,
    TextEditingController controller,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.nk.text,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.nk.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  /// Pie del recibo: línea de corte punteada, TOTAL, macros agregadas
  /// y el botón que persiste todo en Firestore.
  Widget _buildSaveBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: context.nk.surface,
          border: Border(
            top: BorderSide(color: context.nk.cat.withValues(alpha: 0.15)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Línea de corte del recibo
            _dottedDivider(),
            const SizedBox(height: 10),
            // Total
            Row(
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.nk.textDim,
                    letterSpacing: 1.5,
                  ),
                ),
                Spacer(),
                Text(
                  '${_totalCalories().toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.nk.cat,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Macros totales + botón registrar
            Row(
              children: [
                _totalMacroPill('P', _totalProteins(), context.nk.protein),
                SizedBox(width: 8),
                _totalMacroPill('C', _totalCarbs(), context.nk.carbs),
                SizedBox(width: 8),
                _totalMacroPill('G', _totalFats(), context.nk.fat),
                const Spacer(),
                _buildRegisterButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalMacroPill(String label, double grams, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${grams.toStringAsFixed(0)}g',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _saving ? null : _saveAllMeals,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _saving
                ? [Colors.grey, Colors.grey]
                : [context.nk.cat, context.nk.catShadow],
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: [
            BoxShadow(
              color: context.nk.cat.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Registrar',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  double _totalCalories() {
    return _recognizedFoods.fold<double>(0.0, (acc, f) => acc + f.calories);
  }

  double _totalProteins() {
    return _recognizedFoods.fold<double>(0.0, (acc, f) => acc + f.proteins);
  }

  double _totalCarbs() {
    return _recognizedFoods.fold<double>(0.0, (acc, f) => acc + f.carbs);
  }

  double _totalFats() {
    return _recognizedFoods.fold<double>(0.0, (acc, f) => acc + f.fats);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // FASE 4: Éxito
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildSuccessPhase() {
    final celebratesLevel = _levelUpTo != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0C20), Color(0xFF0A0818)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NekoCatMascot(mood: CatMood.success, size: 120),
                SizedBox(height: 24),
                Text(
                  '¡Registrado!',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.nk.cat,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_recognizedFoods.length} alimento${_recognizedFoods.length > 1 ? 's' : ''} guardado${_recognizedFoods.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (_xpGained > 0) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.nk.cat.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.nk.cat.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: context.nk.cat,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '+$_xpGained XP',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.nk.cat,
                          ),
                        ),
                        if (_xpMultiplier > 1.0) ...[
                          SizedBox(width: 6),
                          Text(
                            '(${_xpMultiplier}x Racha 🔥)',
                            style: TextStyle(
                              fontFamily: AppFonts.mono,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.nk.amberSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Confeti: solo en la primera comida registrada.
        if (_firstMealSaved)
          ParticleBurst(
            trigger: _celebrationSeq,
            mode: BurstMode.confetti,
            origin: const Alignment(0, 0.78),
          ),

        // Brasas: cada hito de racha (múltiplos de 7 días).
        if (_streakMilestone)
          ParticleBurst(
            trigger: _celebrationSeq,
            mode: BurstMode.embers,
            origin: const Alignment(0, 1.1),
          ),

        if (_streakMilestone)
          Positioned(
            bottom: 120,
            left: 24,
            right: 24,
            child: _milestoneBanner(
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF9800),
              text: '¡Racha de $_streakDays días! Que no se rompa.',
            ),
          ),

        if (_unlockedNames.isNotEmpty)
          Positioned(
            bottom: 68,
            left: 24,
            right: 24,
            child: _milestoneBanner(
              icon: Icons.checkroom_rounded,
              color: context.nk.amber,
              text: 'Outfit desbloqueado: ${_unlockedNames.join(' · ')}',
            ),
          ),

        // Subida de nivel: celebración encima de todo.
        if (celebratesLevel)
          LevelUpCelebration(
            key: ValueKey('levelup-$_celebrationSeq'),
            level: _levelUpTo!,
            xp: _newXp,
            catName: _catName,
          ),
      ],
    );
  }

  Widget _milestoneBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.nk.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildErrorBanner() {
    final isGeminiError =
        _error!.contains('IA') ||
        _error!.contains('Gemini') ||
        _error!.contains('conexión');
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.nk.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.nk.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: context.nk.danger,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12,
                  color: context.nk.danger,
                ),
              ),
            ),
            if (isGeminiError)
              GestureDetector(
                onTap: _analyzeImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.nk.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(                    'RETRY',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: context.nk.danger,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: _reset,
              child: Icon(                Icons.close_rounded,
                size: 14,
                color: context.nk.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modos del escáner — pestañas superiores
enum _ScannerTab { scan, recipe, voice }

/// Fases del escáner
enum ScannerPhase { camera, scanning, result, success }

/// Painter del overlay de escaneo — esquinas + exterior oscurecido + marco
/// con degradado. Estilo premium "viewfinder" inspirado en scanners de IA.
class _ScanOverlayPainter extends CustomPainter {
  final double opacity;
  final Color catColor;
  _ScanOverlayPainter({required this.opacity, required this.catColor});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.45;
    final frameWidth = size.width * 0.72;
    final frameHeight = size.width * 0.72;

    // Rectángulo de la zona de escaneo (ligeramente redondeado).
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: frameWidth,
        height: frameHeight,
      ),
      const Radius.circular(20),
    );

    // 1) Oscurecer exterior del recuadro con un degradado vertical sutil
    //    (más oscuro arriba/abajo, menos en el centro donde está el plato).
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addRRect(scanRect),
    );
    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.72),
          Colors.black.withValues(alpha: 0.45),
          Colors.black.withValues(alpha: 0.72),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // 2) Marco del recuadro (sutil, para dar profundidad).
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(scanRect, framePaint);

    // 3) Esquinas con brackets — más largas y mejor espaciadas, con glow.
    final cornerLength = 28.0;
    final margin =
        size.width * 0.14 - cornerLength; // las esquinas abrazan el recuadro
    final frameLeft = scanRect.left;
    final frameTop = scanRect.top;
    final frameRight = scanRect.right;
    final frameBottom = scanRect.bottom;

    // Glow detrás de las esquinas
    final glowPaint = Paint()
      ..color = catColor.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final cornerPaint = Paint()
      ..color = catColor.withValues(alpha: opacity)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawCorner(
      Offset start,
      Offset corner,
      Offset end, {
      bool glow = true,
    }) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(end.dx, end.dy);
      if (glow) canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, cornerPaint);
    }

    // Superior izquierda
    drawCorner(
      Offset(frameLeft, frameTop + cornerLength),
      Offset(frameLeft, frameTop),
      Offset(frameLeft + cornerLength, frameTop),
    );
    // Superior derecha
    drawCorner(
      Offset(frameRight - cornerLength, frameTop),
      Offset(frameRight, frameTop),
      Offset(frameRight, frameTop + cornerLength),
    );
    // Inferior izquierda
    drawCorner(
      Offset(frameLeft, frameBottom - cornerLength),
      Offset(frameLeft, frameBottom),
      Offset(frameLeft + cornerLength, frameBottom),
    );
    // Inferior derecha
    drawCorner(
      Offset(frameRight - cornerLength, frameBottom),
      Offset(frameRight, frameBottom),
      Offset(frameRight, frameBottom - cornerLength),
    );

    // 4) Ticks pequeños sobre los bordes (medidores, dan sensación técnica).
    final tickPaint = Paint()
      ..color = catColor.withValues(alpha: opacity * 0.65)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const tickCount = 8;
    final tickLen = 4.0;
    // top + bottom
    for (int i = 1; i < tickCount; i++) {
      final t = i / tickCount;
      if (t == 0.5) continue; // skip center (already corners area)
      final x = frameLeft + frameWidth * t;
      canvas.drawLine(
        Offset(x, frameTop - 2),
        Offset(x, frameTop - 2 - tickLen),
        tickPaint,
      );
      canvas.drawLine(
        Offset(x, frameBottom + 2),
        Offset(x, frameBottom + 2 + tickLen),
        tickPaint,
      );
    }
    for (int i = 1; i < tickCount; i++) {
      final t = i / tickCount;
      if (t == 0.5) continue;
      final y = frameTop + frameHeight * t;
      canvas.drawLine(
        Offset(frameLeft - 2, y),
        Offset(frameLeft - 2 - tickLen, y),
        tickPaint,
      );
      canvas.drawLine(
        Offset(frameRight + 2, y),
        Offset(frameRight + 2 + tickLen, y),
        tickPaint,
      );
    }
    // Silence unused warning
    // ignore: unused_local_variable
    final _ = margin;
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.catColor != catColor;
}

class BlurFilter extends StatelessWidget {
  final double sigmaX;
  final double sigmaY;
  final Widget child;

  const BlurFilter({
    super.key,
    required this.sigmaX,
    required this.sigmaY,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: child,
    );
  }
}

/// Línea punteada estilo recibo de konbini (mismo patrón que el drawer
/// y el diario alimentario).
class _DottedLinePainter extends CustomPainter {
  final Color lineColor;
  _DottedLinePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const double dashWidth = 4;
    const double dashGap = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Placeholder del sello cuando no hay foto capturada (modo voz / receta).
class _PhotoStampPlaceholder extends StatelessWidget {
  const _PhotoStampPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.nk.surfaceHigh,
      child: Icon(
        Icons.restaurant_rounded,
        size: 20,
        color: context.nk.textFaint,
      ),
    );
  }
}
