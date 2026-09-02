import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../models/meal_entry.dart';

/// Sheet para describir una comida por voz (o por texto si el usuario
/// prefiere tipear). Cuando termina, devuelve la transcripción que el
/// caller (scanner) envía a Gemini para que extraiga los alimentos.
class VoiceMealSheet extends StatefulWidget {
  final MealType mealType;
  final Future<void> Function(String transcript) onSubmit;

  const VoiceMealSheet({
    super.key,
    required this.mealType,
    required this.onSubmit,
  });

  @override
  State<VoiceMealSheet> createState() => _VoiceMealSheetState();
}

class _VoiceMealSheetState extends State<VoiceMealSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textCtrl = TextEditingController();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _submitting = false;
  String _partialText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de voz: ${e.errorMsg}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
  }

  Future<void> _toggleListen() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Reconocimiento de voz no disponible. Escribe tu comida abajo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _partialText = result.recognizedWords;
          if (result.finalResult) {
            _textCtrl.text = _partialText;
            _isListening = false;
          }
        });
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe qué comiste para continuar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.nk.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.nk.textDim.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(),
                Divider(color: context.nk.textFaint, height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l, AppSpacing.m, AppSpacing.l, 100),
                    children: [
                      _buildBigMicButton(),
                      const SizedBox(height: AppSpacing.l),
                      _buildTranscriptPreview(),
                      const SizedBox(height: AppSpacing.l),
                      _buildTextInput(),
                      const SizedBox(height: AppSpacing.l),
                      _buildQuickPrompts(),
                    ],
                  ),
                ),
                _buildSubmitBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, 8, AppSpacing.l, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.nk.cat.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 18,
              color: context.nk.cat,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Describe por voz',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.nk.text,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.nk.cat.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(
              widget.mealType.displayName.toUpperCase(),
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: context.nk.cat,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigMicButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleListen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isListening
                ? LinearGradient(
                    colors: [context.nk.danger, Color(0xFFD32F2F)],
                  )
                : LinearGradient(
                    colors: [context.nk.cat, context.nk.catShadow],
                  ),
            boxShadow: [
              BoxShadow(
                color: (_isListening
                        ? context.nk.danger
                        : context.nk.cat)
                    .withValues(alpha: 0.4),
                blurRadius: _isListening ? 28 : 16,
                spreadRadius: _isListening ? 4 : 0,
              ),
            ],
          ),
          child: Icon(
            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
            size: 56,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptPreview() {
    final shown = _isListening && _partialText.isNotEmpty
        ? _partialText
        : _textCtrl.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.nk.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: context.nk.cat.withValues(alpha: _isListening ? 0.4 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isListening ? Icons.graphic_eq_rounded : Icons.format_quote_rounded,
                size: 14,
                color: _isListening ? context.nk.danger : context.nk.cat,
              ),
              const SizedBox(width: 6),
              Text(
                _isListening ? 'ESCUCHANDO…' : 'TRANSCRIPCIÓN',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: _isListening ? context.nk.danger : context.nk.cat,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            shown.isEmpty
                ? (_speechAvailable
                    ? 'Toca el micrófono y empieza a hablar…'
                    : 'Escribe abajo qué comiste.')
                : shown,
            style: TextStyle(
              color: shown.isEmpty
                  ? context.nk.textDim
                  : context.nk.text,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'O ESCRÍBELO',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.nk.textDim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: context.nk.text,
            fontSize: 14,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: 'Ej. "Comí 200g de arroz con 150g de pechuga de pollo y ensalada"',
            hintStyle: TextStyle(color: context.nk.textFaint),
            filled: true,
            fillColor: context.nk.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPrompts() {
    final examples = <(String, String)>[
      ('', 'Arroz blanco 200g con pollo 150g'),
      ('', 'Ensalada verde con atún y aguacate'),
      ('', 'Avena con banana y mantequilla de maní'),
      ('', 'Manzana con mantequilla de almendras'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATAJOS',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.nk.textDim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: examples
              .map((e) => ActionChip(
                    avatar: e.$1.isNotEmpty
                        ? Text(e.$1, style: const TextStyle(fontSize: 14))
                        : null,
                    label: Text(
                      e.$2,
                      style: TextStyle(
                        color: context.nk.text,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: context.nk.surface,
                    side: BorderSide(
                      color: context.nk.cat.withValues(alpha: 0.25),
                    ),
                    onPressed: () {
                      setState(() {
                        _textCtrl.text = e.$2;
                      });
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.l, 12, AppSpacing.l, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.nk.surface,
        border: Border(
          top: BorderSide(color: context.nk.cat.withValues(alpha: 0.15)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: _submitting ? null : _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _submitting
                    ? [Colors.grey, Colors.grey]
                    : [context.nk.cat, context.nk.catShadow],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: context.nk.cat.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _submitting
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Analizar con NekoFit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
