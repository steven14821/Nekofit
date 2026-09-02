import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/haptics.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../models/pantry_item.dart';
import '../services/nekochat_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/neko_cat_mascot.dart';

/// Chat con NekoFit — ticket de konbini a las 3 AM, theme-aware (Noche Ámbar).
class NekoChatSheet extends ConsumerStatefulWidget {
  final List<PantryItem> pantryItems;

  const NekoChatSheet({super.key, required this.pantryItems});

  @override
  ConsumerState<NekoChatSheet> createState() => _NekoChatSheetState();

  static Future<void> show(BuildContext context, List<PantryItem> pantryItems) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: NekoChatSheet(pantryItems: pantryItems),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _NekoChatSheetState extends ConsumerState<NekoChatSheet>
    with SingleTickerProviderStateMixin {
  late final NekoChatService _service = ref.read(nekoChatServiceProvider);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _showSuggestions = true;

  // Animación de entrada del header
  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;

  // Sugerencias rápidas — pastel en dark, variante oscura legible en claro.
  final List<_Suggestion> _suggestions = [
    _Suggestion(
      icon: Icons.restaurant_rounded,
      label: '¿Qué cocinar?',
      color: Color(0xFF4CAF50),
      lightColor: Color(0xFF1B5E20),
    ),
    _Suggestion(
      icon: Icons.inventory_2_rounded,
      label: '¿Qué tengo?',
      color: Color(0xFFFFB74D),
      lightColor: Color(0xFF92400E),
    ),
    _Suggestion(
      icon: Icons.local_fire_department_rounded,
      label: 'Tips de proteína',
      color: Color(0xFFE57373),
      lightColor: Color(0xFFC62828),
    ),
    _Suggestion(
      icon: Icons.balance_rounded,
      label: 'Equilibra mi día',
      color: Color(0xFF7E57C2),
      lightColor: Color(0xFF5E35B1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _service.loadCatName();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerAnimController.forward();

    if (_service.history.isEmpty) {
      _sendWelcome();
    }
    // Keep suggestions visible - don't hide them based on history
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _sendWelcome() async {
    setState(() => _loading = true);
    try {
      await _service.sendMessage(
        userMessage: 'Hola',
        pantryItems: widget.pantryItems,
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loading = false;
        // Keep suggestions visible - don't hide them
      });
      _scrollToBottom();
    }
  }

  Future<void> _send([String? text]) async {
    final msg = text ?? _controller.text.trim();
    if (msg.isEmpty || _loading) return;

    _controller.clear();
    Haptics.tap();
    setState(() {
      _loading = true;
      // Keep suggestions visible - don't hide them
    });

    try {
      await _service.sendMessage(
        userMessage: msg,
        pantryItems: widget.pantryItems,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NekoFit se rascó demasiado: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final messages = _service.history;

    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildDivider(),
              Expanded(
                child: messages.isEmpty && _loading
                    ? _buildLoadingState()
                    : _buildMessages(messages),
              ),
              if (_showSuggestions) _buildSuggestions(),
              _buildInput(),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;

    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: nk.textDim),
              onPressed: () {
                _service.clearHistory();
                Navigator.of(context).pop();
              },
            ),
            // Avatar del gato — gradiente gato en dark, neutro lite en claro.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? LinearGradient(
                        colors: [nk.cat, nk.ember],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : nk.cat.withValues(alpha: 0.15),
                border: isDark
                    ? null
                    : Border.all(color: nk.cat.withValues(alpha: 0.40)),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: nk.cat.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: const Center(
                child: NekoCatMascot(
                  mood: CatMood.idle,
                  size: 28,
                  showLabel: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _service.catName,
                    style: _display(
                      size: 18,
                      weight: FontWeight.w800,
                      color: nk.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: nk.ok,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'En línea',
                        style: _mono(
                          size: 10,
                          weight: FontWeight.w600,
                          color: nk.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botón limpiar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: nk.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: isDark ? null : Border.all(color: nk.border),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: isDark ? nk.textFaint : nk.textDim,
                ),
                onPressed: () {
                  _service.clearHistory();
                  setState(() {
                    _showSuggestions = true;
                  });
                  _sendWelcome();
                },
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final nk = context.nk;
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: nk.divider,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Loading state
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    final nk = context.nk;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NekoCatMascot(mood: CatMood.thinking, size: 80),
          const SizedBox(height: 16),
          Text(
            'NekoFit está pensando...',
            style: _body(size: 14, color: nk.textDim),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Mensajes
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildMessages(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessage(messages[index], index);
      },
    );
  }

  Widget _buildMessage(ChatMessage msg, int index) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final isUser = msg.isUser;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                // Avatar del gato
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark
                        ? LinearGradient(
                            colors: [nk.cat, nk.ember],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isDark ? null : nk.cat.withValues(alpha: 0.15),
                    border: isDark
                        ? null
                        : Border.all(color: nk.cat.withValues(alpha: 0.40)),
                  ),
                  child: const Center(
                    child: NekoCatMascot(
                      mood: CatMood.idle,
                      size: 16,
                      showLabel: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser && isDark
                        ? LinearGradient(
                            colors: [
                              nk.amber.withValues(alpha: 0.25),
                              nk.ember.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    color: isUser
                        ? (isDark ? null : nk.amber.withValues(alpha: 0.10))
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : nk.surface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? (isDark
                                ? nk.amber.withValues(alpha: 0.3)
                                : nk.amber.withValues(alpha: 0.35))
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : nk.border),
                    ),
                    boxShadow: [
                      if (isUser && isDark)
                        BoxShadow(
                          color: nk.amber.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: _body(size: 14, color: nk.text, height: 1.5),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: nk.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded, size: 14, color: nk.amber),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? LinearGradient(
                        colors: [nk.cat, nk.ember],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : nk.cat.withValues(alpha: 0.15),
                border: isDark
                    ? null
                    : Border.all(color: nk.cat.withValues(alpha: 0.40)),
              ),
              child: const Center(
                child: NekoCatMascot(
                  mood: CatMood.thinking,
                  size: 16,
                  showLabel: false,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : nk.surface,
                borderRadius: BorderRadius.circular(
                  16,
                ).copyWith(bottomLeft: const Radius.circular(4)),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : nk.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(0),
                  const SizedBox(width: 4),
                  _buildDot(1),
                  const SizedBox(width: 4),
                  _buildDot(2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    // En claro el gato (#A9743C) es más oscuro: subimos las opacidades
    // para que los tres puntos no se fundan con el fondo blanco.
    final alpha = isDark ? 0.4 + (index * 0.2) : 0.7 + (index * 0.15);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: nk.cat.withValues(alpha: alpha),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Sugerencias rápidas
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildSuggestions() {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = _suggestions[index];
          // En claro usamos la variante oscura para que el texto pase AA (≥4.5:1).
          final c = isDark ? s.color : s.lightColor;
          return GestureDetector(
            onTap: () {
              _controller.text = s.label;
              _send(s.label);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: c.withValues(alpha: isDark ? 0.1 : 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: c.withValues(alpha: isDark ? 0.3 : 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 14, color: c),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: _body(size: 12, weight: FontWeight.w500, color: c),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Input
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildInput() {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: nk.surface,
        border: Border(top: BorderSide(color: nk.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : nk.surfaceHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : nk.border,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: _body(size: 14, color: nk.text),
                decoration: InputDecoration(
                  hintText: 'Pregúntale a NekoFit...',
                  hintStyle: _body(
                    size: 14,
                    color: isDark ? nk.textFaint : nk.textDim,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _loading
                    ? null
                    : (isDark
                          ? LinearGradient(
                              colors: [nk.amber, nk.ember],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null),
                color: _loading ? nk.textFaint : (isDark ? null : nk.amber),
                shape: BoxShape.circle,
                boxShadow: _loading
                    ? []
                    : (isDark
                          ? [
                              BoxShadow(
                                color: nk.amber.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : []),
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : nk.text,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF1A1206) : Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tipografía Noche Ámbar (mismas fuentes que Home/Diario/Mascota)
// ═════════════════════════════════════════════════════════════════════════════
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
  double? height,
}) => GoogleFonts.dmSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

// ═════════════════════════════════════════════════════════════════════════════
// Helper classes
// ═════════════════════════════════════════════════════════════════════════════

class _Suggestion {
  final IconData icon;
  final String label;

  /// Color pastel para modo oscuro (brilla sobre carbón).
  final Color color;

  /// Variante oscura legible (≥4.5:1) para modo claro.
  final Color lightColor;

  const _Suggestion({
    required this.icon,
    required this.label,
    required this.color,
    required this.lightColor,
  });
}
