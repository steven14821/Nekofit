// Widget test del AuthWrapper (el auth-gate reactivo).
//
// Al sobrescribir `authRepositoryProvider` y `notificationServiceProvider`
// con fakes, la app arranca sin conectar a Firebase: el gate decide la
// pantalla inicial según el estado de sesión del fake.

import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nekofit/core/providers.dart';
import 'package:nekofit/main.dart';
import 'package:nekofit/screens/login_screen.dart';
import 'package:nekofit/screens/onboarding_screen.dart';

import 'helpers/fakes.dart';

void main() {
  setUp(() {
    // Sin descargas de fuentes por red en tests (evita timers/HTTP falsos).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // Superficie tipo teléfono: en 800x600 las pantallas del auth desbordan
  // (login y onboarding tienen contenido ~844px de alto).
  Future<void> usePhoneSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('sin sesión → muestra LoginScreen', (WidgetTester tester) async {
    await usePhoneSurface(tester);
    final repo = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          notificationServiceProvider.overrideWithValue(FakeNotifications()),
        ],
        child: const MyApp(),
      ),
    );

    // El gate arranca en "checking" (splash) hasta que el stream emite.
    await tester.pump();
    repo.emit(null);
    // Pumps acotados: AmberAtmosphere tiene una animación infinita, así que
    // pumpAndSettle no se puede usar aquí.
    await tester.pump(const Duration(milliseconds: 50));

    // El font de test (Ahem) infla los textos y produce desbordamientos de
    // layout falsos en Rows anchos; lo que validamos es el *routing* del gate.
    tester.takeException();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('sesión con perfil incompleto sin onboarding → Onboarding',
      (WidgetTester tester) async {
    await usePhoneSurface(tester);
    final repo = FakeAuthRepository()..doc = {'uid': 'u1'};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          notificationServiceProvider.overrideWithValue(FakeNotifications()),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    repo.emit('u1');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    tester.takeException();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}