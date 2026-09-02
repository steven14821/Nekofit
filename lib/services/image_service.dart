import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'http_off_image.dart';
import 'firebase_service.dart';

/// Servicio de imágenes: comprime cualquier foto a <100KB JPEG y la sube
/// a Firebase Storage siguiendo la convención `users/{uid}/pantry/{id}.jpg`.
///
/// RNF-2 del README exige imágenes <100KB. Esta clase se asegura de eso
/// con un bucle: baja calidad, baja resolución, hasta que el JPEG quepa.
/// Si tras todos los intentos sigue por encima del umbral, devuelve el
/// último resultado igualmente para no bloquear al usuario.
class ImageService {
  static const int _targetKb = 95;
  static const int _maxWidth = 900;
  static const int _minWidth = 320;

  /// Punto único de entrada: desde un archivo (cámara/galería) o desde
  /// una URL (descarga de OFF). Devuelve la URL pública en Storage.
  Future<String> uploadProductImage({
    required String uid,
    required String productId,
    File? file,
    String? sourceUrl,
  }) async {
    if (file == null && (sourceUrl == null || sourceUrl.isEmpty)) {
      throw ArgumentError('uploadProductImage: file o sourceUrl requerido');
    }

    final Uint8List input = file != null
        ? await file.readAsBytes()
        : await HttpOffImage.download(sourceUrl!);

    final compressed = await compressToTarget(input);
    final tempDir = await getTemporaryDirectory();
    final tmpFile = File(p.join(
      tempDir.path,
      'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ));
    await tmpFile.writeAsBytes(compressed, flush: true);

    final ref = FirebaseStorage.instance
        .ref()
        .child('users/$uid/pantry/$productId.jpg');
    final task = await ref.putFile(
      tmpFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    final url = await task.ref.getDownloadURL();

    try {
      await tmpFile.delete();
    } catch (_) {}

    return url;
  }

  /// Comprime agresivamente hasta entrar en `_targetKb`. Si la imagen
  /// original ya entra, se respeta y se devuelve tal cual.
  static Future<Uint8List> compressToTarget(Uint8List input) async {
    if (input.lengthInBytes <= _targetKb * 1024) {
      return input;
    }

    Uint8List best = input;
    int width = _maxWidth;
    int quality = 85;

    for (int attempt = 0; attempt < 6; attempt++) {
      final encoded = await FlutterImageCompress.compressWithList(
        input,
        quality: quality,
        minWidth: width,
        minHeight: width,
        format: CompressFormat.jpeg,
      );
      if (encoded.isEmpty) break; // plataforma no inicializada
      if (encoded.lengthInBytes <= _targetKb * 1024) {
        return encoded;
      }
      best = encoded;

      if (quality > 50) {
        quality -= 10;
      } else {
        width = (width * 0.8).toInt().clamp(_minWidth, _maxWidth);
        quality = 75;
      }
    }
    return best;
  }

  /// Decodifica un JPEG y devuelve sus dimensiones. Útil para placeholders
  /// con aspect ratio antes de que termine la subida.
  static Future<({int width, int height})> probeJpeg(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (width: 0, height: 0);
    return (width: decoded.width, height: decoded.height);
  }

  /// Helper para mantener consistencia entre las pantallas que suben
  /// imágenes. Lanza si no hay sesión.
  static String currentUid() {
    final user = FirebaseService.instance.currentUser;
    if (user == null) {
      throw StateError('No hay sesión activa');
    }
    return user.uid;
  }
}
