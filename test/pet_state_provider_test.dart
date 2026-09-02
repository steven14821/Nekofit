// Tests del `petStateProvider`: el estado del gato es reactivo a la sesión
// (auth-gate) y se re-suscribe automáticamente al cambiar de usuario, sin
// tocar Firebase.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nekofit/core/providers.dart';
import 'package:nekofit/models/pet_state.dart';

import 'helpers/fakes.dart';

/// Drena el event loop real lo suficiente para que el gate (awaits en
/// cascada) y los streams del fake terminen sus microtareas.
Future<void> flushAsync() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakePetRepository pet;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<PetState>> hold;

  setUp(() {
    auth = FakeAuthRepository()..doc = completeProfile();
    pet = FakePetRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        notificationServiceProvider.overrideWithValue(FakeNotifications()),
        petServiceProvider.overrideWithValue(pet),
      ],
    );
    // Mantiene vivo el provider autoDispose durante el test.
    hold = container.listen<AsyncValue<PetState>>(petStateProvider, (_, _) {});
  });

  tearDown(() {
    hold.close();
    container.dispose();
  });

  test('sin sesión el provider no emite nada', () async {
    expect(container.read(petStateProvider).hasValue, isFalse);
    await flushAsync();
    expect(container.read(petStateProvider).hasValue, isFalse);
    expect(pet.lastSubscribedUid, isNull);
  });

  test('con sesión entrega el estado y se apaga al cerrar la sesión', () async {
    final seen = <String>[];
    container.listen<AsyncValue<PetState>>(petStateProvider, (prev, next) {
      seen.add('$next');
    });
    auth.emit('user-1');
    await flushAsync();

    expect(pet.lastSubscribedUid, 'user-1');
    expect(container.read(petStateProvider).hasValue, isTrue);
    expect(
      container.read(petStateProvider).value?.currentHunger,
      closeTo(pet.petState.currentHunger, 1),
    );
    expect(container.read(petStateProvider).value?.currentHunger, greaterThanOrEqualTo(75));
    expect(pet.activeSubscriptions, 1); // listener de datos del provider
    expect(seen, anyElement(startsWith('AsyncData')));

    // Logout → el provider deja de suscribirse al stream del pet y lo cierra.
    auth.emit(null);
    await flushAsync();
    expect(pet.activeSubscriptions, 0); // sin suscripción viva
    expect(pet.cancelledUids, contains('user-1')); // stream del pet cerrado
    expect(container.read(petStateProvider).hasError, isFalse);
    // Nota: Riverpod conserva el último valor como "isLoading" mientras
    // reconstruye (seamless); al ser autoDispose, el provider se descarta
    // cuando la UI se desmonta, así el dato no sobrevive a otro login.
  });

  test('se re-suscribe automáticamente al cambiar de usuario', () async {
    auth.emit('user-1');
    await flushAsync();
    expect(pet.lastSubscribedUid, 'user-1');

    auth.emit('user-2');
    await flushAsync();
    expect(pet.lastSubscribedUid, 'user-2');
    // La suscripción anterior se cerró al reconstruirse el provider.
    expect(pet.activeSubscriptions, 1);
    expect(pet.cancelledUids, contains('user-1'));
    expect(
      container.read(petStateProvider).value?.currentHunger,
      closeTo(pet.petState.currentHunger, 1),
    );
  });

  test('un cambio de hambre en el stream se refleja en el provider', () async {
    auth.emit('user-1');
    await flushAsync();
    final before = container.read(petStateProvider).value!;

    pet.emit(before.copyWith(hunger: 5, lastFedAt: DateTime.now()));
    await flushAsync();

    expect(
      container.read(petStateProvider).value?.currentHunger,
      closeTo(pet.petState.currentHunger, 1),
    );
    expect(container.read(petStateProvider).value?.currentHunger, lessThan(10));
  });
}