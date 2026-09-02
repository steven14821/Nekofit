import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'l10n/app_localizations.dart';
import 'controllers/auth_gate_controller.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'core/neko_palette.dart';
import 'core/scroll_behavior.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/gemini_vision_service.dart';
import 'services/nekochat_service.dart';
import 'services/notification_service.dart';
import 'widgets/amber_atmosphere.dart';
import 'widgets/neko_cat_mascot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));

  await Firebase.initializeApp();

  // Firestore: activar persistencia offline con 50 MB de caché.
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await initializeDateFormatting('es');
  // Init one-time de servicios con estado (modelos IA + notificaciones).
  // Devuelven las mismas instancias que exponen los providers del contenedor.
  await GeminiVisionService.instance.ensureInitialized();
  await NekoChatService.instance.ensureInitialized();
  await NotificationService.instance.init();

  // La app entera vive bajo el ProviderScope: de aquí salen el contenedor
  // de dependencias (DI) y el estado reactivo.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Cada vez que la app vuelve al primer plano se recalculan las
    // notificaciones inteligentes con el contexto más reciente (comidas de
    // hoy, racha, despensa). Best-effort: nunca bloquea la UI.
    final notifications = ref.read(notificationServiceProvider);
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        notifications.scheduleContextualNotifications();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLocale = ref.watch(localeProvider);
    return ThemeProvider(
      child: MaterialApp(
        title: 'NekoFit',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        scrollBehavior: NekoScrollBehavior(),
        locale: userLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Público objetivo hispano: español por defecto para cualquier locale
        // que no sea inglés explícito; inglés solo cuando el dispositivo lo pide.
        localeResolutionCallback: (locale, supported) {
          if (userLocale != null) return userLocale;
          if (locale != null && locale.languageCode == 'en') {
            return const Locale('en');
          }
          return const Locale('es');
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Puerta de entrada de la app: decide qué pantalla mostrar según el estado
/// reactivo del auth-gate (sesión + perfil completo).
///
/// Ya NO hay StreamBuilder/FutureBuilder aquí: toda la lógica de sesión y
/// de comprobación del perfil vive en [AuthGateController]. Este widget solo
/// mapea el estado a la pantalla correspondiente.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authGateProvider);
    switch (state.status) {
      case AuthGateStatus.checking:
        return _splash(const _CatSplashGreeting());
      case AuthGateStatus.unauthenticated:
        return const LoginScreen();
      case AuthGateStatus.needsOnboarding:
        return const OnboardingScreen();
      case AuthGateStatus.needsProfileSetup:
        return const ProfileSetupScreen();
      case AuthGateStatus.authenticated:
        return const MainNavigation();
      case AuthGateStatus.error:
        return _splash(_AuthGateError(
          message: state.error,
          onRetry: () => ref.read(authGateProvider.notifier).refresh(),
        ));
    }
  }

  Widget _splash(Widget child) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: AmberAtmosphere(
        child: Center(child: child),
      ),
    );
  }
}

/// Pantalla de error del auth-gate: no podemos leer el perfil (p. ej. sin
/// red). En vez de mandar al usuario a un flujo incorrecto (como hacía el
/// FutureBuilder anterior, que caía en onboarding), ofrecemos reintentar.
class _AuthGateError extends StatelessWidget {
  const _AuthGateError({this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NekoCatMascot(
            mood: CatMood.alert,
            size: 96,
            showLabel: false,
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).authGateErrorTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF0B429),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).authGateErrorBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              color: const Color(0xFF6B6459),
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8B8780),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ),
        ],
      ),
    );
  }
}

/// Splash animado con el gato saludando desde el primer frame.
/// Reemplaza el spinner genérico: el gato aparece con scale-in elástico
/// + fade, y debajo el nombre de la app con opacidad pulsante.
class _CatSplashGreeting extends StatefulWidget {
  const _CatSplashGreeting();

  @override
  State<_CatSplashGreeting> createState() => _CatSplashGreetingState();
}

class _CatSplashGreetingState extends State<_CatSplashGreeting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _fadeAnim.value,
                child: const NekoCatMascot(
                  mood: CatMood.idle,
                  size: 120,
                  showLabel: false,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Opacity(
              opacity: _fadeAnim.value.clamp(0.0, 1.0),
              child: Text(
                'NekoFit',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF0B429),
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFF0B429).withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: (_fadeAnim.value * 0.6).clamp(0.0, 1.0),
              child: Text(
                AppLocalizations.of(context).tagline,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B6459),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}