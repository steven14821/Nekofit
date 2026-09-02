import 'package:flutter_test/flutter_test.dart';

import 'package:nekofit/controllers/auth_gate_controller.dart';

import 'helpers/fakes.dart';

/// Pruebas unitarias del auth-gate SIN tocar Firebase: gracias a la
/// Inyección de Dependencias (providers → interfaz [AuthRepository]) el
/// controlador se ejercita con un fake que devuelve los documentos que cada
/// escenario necesita.
void main() {
  group('AuthGateController', () {
    test('sin sesión → unauthenticated', () async {
      final repo = FakeAuthRepository();
      final notif = FakeNotifications();
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: notif,
      );

      repo.emit(null);
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.unauthenticated);
      expect(ctrl.state.uid, isNull);
      ctrl.dispose();
    });

    test('perfil completo → authenticated con UserContext', () async {
      final repo = FakeAuthRepository()..doc = completeProfile();
      final notif = FakeNotifications();
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: notif,
      );

      repo.emit('user-1');
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.authenticated);
      expect(ctrl.state.uid, 'user-1');
      expect(ctrl.state.profile, isNotNull);
      expect(ctrl.state.profile!.username, 'Neko');
      expect(ctrl.state.profile!.macroGoals['calories'], 2200);
      ctrl.dispose();
    });

    test('perfil completo programa notificaciones UNA sola vez', () async {
      final repo = FakeAuthRepository()
        ..doc = completeProfile()
        ..currentUidValue = 'user-1';
      final notif = FakeNotifications();
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: notif,
      );

      repo.emit('user-1');
      await pumpEventQueue();
      expect(notif.mealSchedules, 1);

      // Un refresh en el mismo estado NO debe reprogramar.
      await ctrl.refresh();
      await pumpEventQueue();
      expect(notif.mealSchedules, 1);
      ctrl.dispose();
    });

    test('documento inexistente → needsOnboarding', () async {
      final repo = FakeAuthRepository()..doc = null;
      final notif = FakeNotifications();
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: notif,
      );

      repo.emit('user-1');
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.needsOnboarding);
      ctrl.dispose();
    });

    test('perfil incompleto SIN onboarding visto → needsOnboarding', () async {
      final repo = FakeAuthRepository()
        ..doc = {'uid': 'user-1', 'username': 'Pekes'};
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: FakeNotifications(),
      );

      repo.emit('user-1');
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.needsOnboarding);
      ctrl.dispose();
    });

    test('perfil incompleto CON onboarding visto → needsProfileSetup', () async {
      final repo = FakeAuthRepository()
        ..doc = {'uid': 'user-1', 'seenOnboarding': true};
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: FakeNotifications(),
      );

      repo.emit('user-1');
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.needsProfileSetup);
      ctrl.dispose();
    });

    test('perfil incompleto por edad/weight/height en 0 → needs onboarding', () async {
      final repo = FakeAuthRepository()
        ..doc = {
          'age': 0,
          'weight': 0.0,
          'height': 0.0,
          'fitnessGoal': 'X',
          'macroGoals': {'calories': 2000},
        };
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: FakeNotifications(),
      );

      repo.emit('user-1');
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.needsOnboarding,
          reason: 'todavía no completó el perfil (dato en 0)');
      ctrl.dispose();
    });

    test('error leyendo el perfil → error, y refresh se recupera', () async {
      final repo = FakeAuthRepository()..error = Exception('sin red');
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: FakeNotifications(),
      );

      repo.emit('user-1');
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.error);
      expect(ctrl.state.error, isNotNull);

      // La red vuelve: el refresh re-evalúa y queda autenticado.
      repo
        ..error = null
        ..doc = completeProfile()
        ..currentUidValue = 'user-1';
      await ctrl.refresh();
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.authenticated);
      ctrl.dispose();
    });

    test('el stream se suscribe una vez y el logout resetea el estado',
        () async {
      final repo = FakeAuthRepository()..doc = completeProfile();
      final ctrl = AuthGateController(
        repository: repo,
        notificationService: FakeNotifications(),
      );

      repo.emit('user-1');
      await pumpEventQueue();
      expect(ctrl.state.status, AuthGateStatus.authenticated);

      repo.emit(null);
      await pumpEventQueue();

      expect(ctrl.state.status, AuthGateStatus.unauthenticated);
      expect(ctrl.state.profile, isNull);
      ctrl.dispose();
    });
  });
}