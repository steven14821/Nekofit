import 'dart:io';
import 'dart:ui';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;

/// Objeto detectado por ML Kit con su bounding box en píxeles
/// de la imagen original (no normalizado).
class DetectedFoodObject {
  final Rect boundingBox;
  final String label;
  final double confidence;
  final int index;

  const DetectedFoodObject({
    required this.boundingBox,
    required this.label,
    required this.confidence,
    required this.index,
  });
}

/// Detección de objetos on-device con ML Kit (Google).
///
/// Corre localmente en el dispositivo (sin subir la foto a la nube) y
/// devuelve los bounding boxes de los alimentos/objetos visibles para
/// dibujarlos sobre la imagen capturada en el escáner de comida.
class ObjectDetectionService {
  ObjectDetectionService._();
  static final ObjectDetectionService instance = ObjectDetectionService._();

  /// Detector cached for the app's lifetime. ML Kit loads the TFLite model
  /// on first use (~200ms). Keeping it alive avoids re-loading on every
  /// screen visit. The memory footprint is negligible (~15MB) and the
  /// singleton is GC'd with the app process.
  late final ObjectDetector _detector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  /// Detecta objetos en la imagen [imagePath].
  /// Devuelve lista vacía si no detecta nada o si falla (no lanza).
  Future<List<DetectedFoodObject>> detect(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final objects = await _detector.processImage(input);

      final results = <DetectedFoodObject>[];
      for (var i = 0; i < objects.length; i++) {
        final obj = objects[i];
        final label =
            obj.labels.isNotEmpty ? obj.labels.first.text : 'Alimento';
        final confidence =
            obj.labels.isNotEmpty ? obj.labels.first.confidence : 0.0;
        results.add(DetectedFoodObject(
          boundingBox: obj.boundingBox,
          label: label,
          confidence: confidence,
          index: i,
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Dimensiones (ancho, alto) en píxeles de la imagen [imagePath],
  /// necesarias para mapear los bounding boxes a la pantalla.
  Future<(int, int)?> imageSize(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return (decoded.width, decoded.height);
    } catch (_) {
      return null;
    }
  }
}
