import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pantry_item.dart';

/// Servicio de chat con NekoFit.
///
/// El historial se guarda en `users/{uid}/chat_history` para que sobreviva
/// al cierre de la app. El servicio funciona aunque no haya sesión
/// (mantiene la lista en memoria) pero solo persiste si hay `uid`.
///
/// Initialization is race-safe: concurrent calls to [ensureInitialized] all
/// await the same [Completer], so the model and auth listener are created
/// exactly once even if multiple widgets call it simultaneously.
class NekoChatService {
  NekoChatService._();
  static final NekoChatService instance = NekoChatService._();

  Completer<void>? _initCompleter;
  GenerativeModel? _model;
  final List<ChatMessage> _history = [];
  final Map<String, _CacheEntry> _cache = {};

  /// UID del usuario activo, si lo hay. Determina dónde persistir.
  String? _uid;
  bool _historyLoaded = false;

  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Ensures the model and auth listener are set up. Safe to call multiple
  /// times; concurrent callers share the same pending future.
  Future<void> ensureInitialized() async {
    if (_model != null) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.5-flash',
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 1024,
        ),
      );
      // Vinculamos al usuario actual (si hay) y a cambios de sesión.
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          attach(user.uid);
        } else {
          detach();
        }
      });
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  GenerativeModel get _safeModel {
    final model = _model;
    if (model == null) {
      throw StateError(
        'NekoChatService not initialized. Call ensureInitialized() first.',
      );
    }
    return model;
  }

  /// Asocia el servicio al UID de un usuario autenticado y carga
  /// el historial persistente. Llamar tras login.
  Future<void> attach(String uid) async {
    _uid = uid;
    _historyLoaded = false;
    await _loadHistory();
  }

  /// Limpia la asociación. Llamar al cerrar sesión para no persistir
  /// en el documento anterior y para liberar memoria.
  Future<void> detach() async {
    _uid = null;
    _history.clear();
    _historyLoaded = false;
  }

  String _catName = 'Mochi';

  String get catName => _catName;

  Future<void> loadCatName() async {
    if (_uid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final rawName = userDoc.data()?['catName'] as String?;
      if (rawName != null && rawName.trim().isNotEmpty) {
        _catName = rawName.trim();
      }
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    if (_uid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final rawName = userDoc.data()?['catName'] as String?;
      if (rawName != null && rawName.trim().isNotEmpty) {
        _catName = rawName.trim();
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('chat_history')
          .orderBy('createdAt', descending: false)
          .get();
      _history
        ..clear()
        ..addAll(snap.docs.map(ChatMessage.fromDoc));
      _historyLoaded = true;
    } catch (e) {
      // Si falla (permisos/offline) seguimos con la lista vacía en memoria.
      _historyLoaded = true;
    }
  }

  Future<void> _persistMessage(ChatMessage msg) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_history')
          .add(msg.toMap());
    } catch (_) {
      // La persistencia es best-effort: el mensaje ya está en memoria.
    }
  }

  Future<void> _clearPersisted() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final docs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_history')
          .get();
      for (final d in docs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {
      // best-effort
    }
  }

  Future<String> sendMessage({
    required String userMessage,
    required List<PantryItem> pantryItems,
  }) async {
    await ensureInitialized();
    if (!_historyLoaded) await _loadHistory();
    _history.add(ChatMessage(text: userMessage, isUser: true));
    await _persistMessage(_history.last);

    // Buscar en caché (TTL 5 minutos)
    final cacheKey = userMessage.toLowerCase().trim();
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      _history.add(ChatMessage(text: cached.reply, isUser: false));
      await _persistMessage(_history.last);
      return cached.reply;
    }

    final pantryContext = _buildPantryContext(pantryItems);
    final systemPrompt = _buildSystemPrompt(pantryContext);

    final content = [
      Content.system(systemPrompt),
      Content.text(userMessage),
    ];

    try {
      final response = await _safeModel.generateContent(content);
      final reply = response.text ?? 'No se me ocurrió nada ahora...';

      // Guardar en caché con TTL
      _cache[cacheKey] = _CacheEntry(reply);

      _history.add(ChatMessage(text: reply, isUser: false));
      await _persistMessage(_history.last);
      return reply;
    } catch (e) {
      // Si es rate limit, dar respuesta local
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        final fallback = _localResponse(userMessage, pantryItems);
        _history.add(ChatMessage(text: fallback, isUser: false));
        await _persistMessage(_history.last);
        return fallback;
      }
      _history.removeLast();
      rethrow;
    }
  }

  String _localResponse(String userMessage, List<PantryItem> pantryItems) {
    final msg = userMessage.toLowerCase();
    final available = pantryItems.where((i) => i.isAvailable).toList();
    final names = available.map((i) => i.name).join(', ');

    if (msg.contains('qué cocinar') || msg.contains('qué hacer') || msg.contains('receta')) {
      if (available.isEmpty) return 'Tu despensa está vacía. ¡Ve a comprar algo!';
      return 'Con $names, intenta algo sencillo. ¡Sé creativo!';
    }

    if (msg.contains('hola') || msg.contains('hey')) {
      return '¡Hola! Soy $_catName. Estoy en modo sin conexión por ahora.';
    }

    return 'Disculpa, estoy sin conexión ahora. Intenta de nuevo en unos minutos.';
  }

  String _buildPantryContext(List<PantryItem> pantryItems) {
    if (pantryItems.isEmpty) return 'El usuario no tiene nada en la despensa todavía.';

    final available = pantryItems.where((i) => i.isAvailable).toList();
    if (available.isEmpty) return 'Todo está agotado en la despensa.';

    final byCategory = <String, List<String>>{};
    for (final item in available) {
      byCategory.putIfAbsent(item.category, () => []).add(item.name);
    }

    final lines = byCategory.entries.map((e) {
      return '- ${e.key}: ${e.value.join(", ")}';
    }).join('\n');

    return 'Despensa actual del usuario:\n$lines';
  }

  String _buildSystemPrompt(String pantryContext) {
    return '''Eres $_catName, la mascota virtual de nutrición y cocina del usuario.

PERSONALIDAD:
- Eres una mascota virtual atenta, amigable y perspicaz llamada $_catName
- Hablas con estilo limpio y profesional pero cercano
- Si el usuario no tiene algo en la despensa, se lo dices de forma amable
- Si tiene todo, le recomiendas algo rico y rápido
- NO utilices emojis en tus respuestas
- Sé directo, no des vueltas
- Responder en español informal pero normal (tú)

REGLAS:
- NUNCA uses emojis en tus respuestas
- NUNCA des recetas largas, máximo 5 pasos
- SIEMPRE usa lo que el usuario tiene en la despensa
- Si no tiene nada, recomienda algo simple con ingredientes básicos
- Si pregunta por algo que no tiene, dile con amabilidad que no lo tiene
- Máximo 3 líneas por respuesta, sé conciso
- Si te preguntan algo que no es de comida, redirige al tema con amabilidad

$pantryContext''';
  }

  /// Limpia el historial en memoria y en Firestore.
  Future<void> clearHistory() async {
    _history.clear();
    await _clearPersisted();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt;

  ChatMessage({required this.text, required this.isUser, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final ts = data['createdAt'];
    DateTime when = DateTime.now();
    if (ts is Timestamp) {
      when = ts.toDate();
    }
    return ChatMessage(
      text: data['text']?.toString() ?? '',
      isUser: data['isUser'] == true,
      createdAt: when,
    );
  }
}

class _CacheEntry {
  final String reply;
  final DateTime createdAt;
  static const _ttl = Duration(minutes: 5);

  _CacheEntry(this.reply) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt) > _ttl;
}
