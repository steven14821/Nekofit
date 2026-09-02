import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/google_g_icon.dart';
import '../widgets/neko_sheet.dart';
import 'register_screen.dart';

/// Login estilo "cajero de konbini" — el formulario es un ticket térmico.
///
/// Misma identidad que el resto de la app (Noche Ámbar): fondo con kanjis
/// deslizándose, ticket crema con muescas festoneadas, labels en JetBrains
/// Mono y el botón ámbar de la casa. Theme-aware: el ticket conserva su
/// papel crema en ambos modos (igual que el ticket del diario) y el botón
/// primario usa gradiente solo en oscuro.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ── Papel térmico (mismo ticket que el diario) ──
  static const _paper = Color(0xFFF6F1E6);
  static const _paperLight = Color(0xFFF0EADC);
  static const _ink = Color(0xFF1B1A17);
  static const _muted = Color(0xFF6A6255);
  static const _line = Color(0xFFCFCBC1);
  static const _cat = Color(0xFFA9743C);
  static const _danger = Color(0xFFB0453C);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Inyección de dependencias: se lee del contenedor, no del singleton.
  late final _firebaseService = ref.read(firebaseServiceProvider);

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _firebaseService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _firebaseService.signInWithGoogle();
      // Si user == null el usuario canceló el selector de cuentas.
      // Si inició sesión, el StreamBuilder de AuthWrapper en main.dart
      // redirige automáticamente (a la app o al profile setup).
      if (user == null && mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).loginGoogleFailed;
      });
      debugPrint('GoogleSignIn error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final emailForgotController = TextEditingController();
    final forgotKey = GlobalKey<FormState>();

    await NekoSheet.show<void>(
      context: context,
      backgroundColor: nk.surface,
      builder: (sheetContext) {
        return Form(
          key: forgotKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.forgotTitle,
                style: _display(nk, size: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.forgotBody,
                style: _sans(nk, size: 13, color: nk.textDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailForgotController,
                style: _sans(nk, size: 15),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailLabel,
                  labelStyle: _sans(nk, size: 14, color: nk.textDim),
                  prefixIcon: Icon(Icons.email_outlined, color: nk.textDim),
                  filled: true,
                  fillColor: nk.surfaceHigh.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.emailEmpty;
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                    return l10n.emailInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      child: Text(
                        l10n.cancel,
                        style: _sans(nk, size: 14, color: nk.textDim),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nk.amber,
                        foregroundColor: nk.mode == NekoThemeMode.dark
                            ? const Color(0xFF1A1206)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n.send),
                      onPressed: () async {
                        if (forgotKey.currentState!.validate()) {
                          try {
                            await _firebaseService
                                .sendPasswordReset(emailForgotController.text.trim());
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.resetEmailSent),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.errorPrefix(e.toString())),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return Scaffold(
      backgroundColor: nk.bg,
      body: AmberAtmosphere(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBrand(nk),
                    const SizedBox(height: 28),
                    _buildTicket(nk),
                    const SizedBox(height: 24),
                    _buildRegisterPrompt(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Marca: letrero de la tienda ─────────────────────────────────────────
  Widget _buildBrand(NekoColors nk) {
    final isDark = nk.mode == NekoThemeMode.dark;
    return Column(
      children: [
        Text(
          'NEKOFIT',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: nk.amber,
            shadows: isDark
                ? [
                    Shadow(
                      color: nk.amber.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'KONBINI FOOD TRACKER · 24H',
          style: _mono(nk,
              size: 11,
              weight: FontWeight.w700,
              letterSpacing: 0.24,
              color: nk.textDim),
        ),
      ],
    );
  }

  // ── Ticket térmico con el formulario ────────────────────────────────────
  Widget _buildTicket(NekoColors nk) {
    final isDark = nk.mode == NekoThemeMode.dark;
    final paper = isDark ? _paper : _paperLight;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _TicketNotchPainter(paper),
            child: const SizedBox.expand(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: paper,
            // En claro el papel casi se funde con el fondo: borde + sombra
            // suave de elevación (igual que el ticket del diario).
            border: isDark ? null : Border.all(color: _line),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0x14000000),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del ticket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NEKOFIT KONBINI',
                    style: _mono(nk,
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 0.16,
                        color: _muted),
                  ),
                  Text(
                    'N.º 0042',
                    style: _mono(nk,
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 0.16,
                        color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const CustomPaint(
                painter: _DashedLinePainter(Color(0x806A6255)),
                child: SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.loginWelcome,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.loginWelcomeSub,
                style: _mono(nk, size: 11.5, color: _muted),
              ),
              const SizedBox(height: 18),

              // Error (si lo hay)
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _danger.withValues(alpha: 0.08),
                    border: Border.all(color: _danger.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: _mono(nk, size: 11.5, color: _danger, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Correo
              Text(
                l10n.loginEmailLabel,
                style: _mono(nk,
                    size: 10,
                    weight: FontWeight.w700,
                    letterSpacing: 0.16,
                    color: _muted),
              ),
              const SizedBox(height: 6),
              _buildEmailField(),
              const SizedBox(height: 16),

              // Contraseña
              Text(
                l10n.loginPasswordLabel,
                style: _mono(nk,
                    size: 10,
                    weight: FontWeight.w700,
                    letterSpacing: 0.16,
                    color: _muted),
              ),
              const SizedBox(height: 6),
              _buildPasswordField(),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.loginForgotPassword,
                    style: _mono(nk,
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: _cat),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón primario — sello ámbar de la casa
              AnimatedOpacity(
                opacity: _isLoading ? 0.7 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isDark
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF0B429), Color(0xFFFF6B3D)],
                            )
                          : null,
                      color: isDark ? null : const Color(0xFFF0B429),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: _ink,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              l10n.loginSignIn,
                              style: _mono(nk,
                                  size: 14,
                                  weight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                  color: _ink),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Separador "O CONTINÚA CON"
              Row(
                children: [
                  const Expanded(
                    child: CustomPaint(
                      painter: _DashedLinePainter(Color(0x806A6255)),
                      child: SizedBox(height: 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l10n.loginOrContinueWith,
                      style: _mono(nk,
                          size: 9.5,
                          weight: FontWeight.w700,
                          letterSpacing: 0.14,
                          color: _muted),
                    ),
                  ),
                  const Expanded(
                    child: CustomPaint(
                      painter: _DashedLinePainter(Color(0x806A6255)),
                      child: SizedBox(height: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Google
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const GoogleGIcon(size: 22),
                  label: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: _ink,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          l10n.loginContinueGoogle,
                          style: _sans(
                            nk,
                            size: 15,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white,
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pie del ticket
              const CustomPaint(
                painter: _DashedLinePainter(Color(0x806A6255)),
                child: SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MOOD: BIENVENIDO',
                    style: _mono(nk,
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 0.12,
                        color: _muted),
                  ),
                  Text(
                    '24H ABIERTO',
                    style: _mono(nk,
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 0.12,
                        color: _muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _TicketNotchPainter(paper),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    final nk = context.nk;
    return TextFormField(
      controller: _emailController,
      style: _sans(nk, size: 15, color: _ink),
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: 'tú@correo.com',
        hintStyle: _sans(nk, size: 14, color: _muted.withValues(alpha: 0.7)),
        prefixIcon: Icon(Icons.email_outlined, color: _muted, size: 20),
        filled: true,
        fillColor: const Color(0xFFEDE5D2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cat, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return AppLocalizations.of(context).loginEmailErrorEmpty;
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
          return AppLocalizations.of(context).loginEmailErrorInvalid;
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    final nk = context.nk;
    return TextFormField(
      controller: _passwordController,
      style: _sans(nk, size: 15, color: _ink),
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: _sans(nk, size: 14, color: _muted.withValues(alpha: 0.7)),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: _muted, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _muted,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: const Color(0xFFEDE5D2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cat, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).loginPasswordErrorEmpty;
        }
        return null;
      },
    );
  }

  Widget _buildRegisterPrompt() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.loginNoAccount,
          style: _sans(nk, size: 14, color: nk.textDim),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          },
          child: Text(
            l10n.loginRegister,
            style: _sans(nk, size: 14, weight: FontWeight.w700, color: nk.amber),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Painters y helpers tipográficos
// ═════════════════════════════════════════════════════════════════════════════

TextStyle _display(NekoColors nk,
        {double size = 22, FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.text,
      letterSpacing: -0.02 * size,
    );

TextStyle _mono(
  NekoColors nk, {
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double letterSpacing = 0,
  double? height,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.textFaint,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle _sans(
  NekoColors nk, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? nk.text,
    );

/// Línea punteada horizontal (separadores del ticket).
class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

/// Bordes dentados del ticket (alternancia papel/transparente).
class _TicketNotchPainter extends CustomPainter {
  final Color paper;

  const _TicketNotchPainter(this.paper);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = paper;
    const dash = 8.0;
    const gap = 8.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, dash, size.height), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketNotchPainter old) => old.paper != paper;
}
