import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Cliente HTTP minimalista pensado para descargar imágenes de Open Food
/// Facts (que en algunos mirrors bloquean el User-Agent por defecto).
class HttpOffImage {
  /// Descarga una imagen desde OFF. Convierte HTTP→HTTPS automáticamente
  /// porque Android 9+ bloquea tráfico cleartext por defecto.
  static Future<Uint8List> download(String url) async {
    // Normalizar a HTTPS
    final safeUrl = url.startsWith('http://')
        ? 'https://${url.substring(7)}'
        : url;

    final response = await http
        .get(Uri.parse(safeUrl),
            headers: const {'User-Agent': 'NekoFit/1.0'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpOffImageException(
        'No pude descargar la imagen (HTTP ${response.statusCode}): $safeUrl',
      );
    }
    return response.bodyBytes;
  }
}

class HttpOffImageException implements Exception {
  final String message;
  HttpOffImageException(this.message);
  @override
  String toString() => message;
}
