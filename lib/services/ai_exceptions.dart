/// Excepciones tipadas del pipeline de IA.
///
/// Permiten que la UI distinga el origen del fallo y muestre un mensaje
/// específico sin depender de parsear strings:
///   - [ImageProcessingException]: la foto no pudo leerse/comprimirse.
///   - [AIResponseException]: la IA no respondió o su JSON no es válido.
///
/// Uso en pantallas:
/// ```dart
/// } on AIException catch (e) {
///   message = e.userMessage ?? 'Algo falló con la IA';
/// }
/// ```
library;

/// Base de los errores relacionados con el servicio de IA.
sealed class AIException implements Exception {
  const AIException(this.message, {this.userMessage});

  /// Detalle técnico (para logs / diagnóstico).
  final String message;

  /// Mensaje amigable listo para mostrar al usuario. Si es null, la UI
  /// debería usar su propia lógica de mensajes.
  final String? userMessage;

  @override
  String toString() => message;
}

/// La IA devolvió una respuesta vacía, malformada o que no cumple el esquema.
class AIResponseException extends AIException {
  const AIResponseException(super.message, {super.userMessage});

  /// Respuesta vacía de la IA (nulo o sin texto).
  const AIResponseException.empty({super.userMessage})
      : super('La IA no devolvió ninguna respuesta');

  /// El texto devuelto no contenía un objeto JSON válido.
  const AIResponseException.notJson({super.userMessage})
      : super('La respuesta de la IA no contenía un JSON válido');

  /// El JSON no cumplía la estructura esperada (`components`, macros, etc.).
  const AIResponseException.invalidShape({super.userMessage})
      : super('La respuesta de la IA no cumplía la estructura esperada');
}

/// Error antes de llamar a la IA: imagen ausente, ilegible o no soportada.
class ImageProcessingException extends AIException {
  const ImageProcessingException(super.message, {super.userMessage});
}