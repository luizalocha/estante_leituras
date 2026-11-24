import 'package:estante_leituras/features/auth/data/auth_service.dart';
import 'package:estante_leituras/features/auth/viewmodel/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeAuthService auth;

  setUp(() => auth = FakeAuthService());
  tearDown(() => auth.close());

  test('começa desconhecido e restaura a sessão existente', () async {
    final vm = SessionViewModel(auth);
    expect(vm.status, SessionStatus.unknown);

    auth.setUser(const AppUser(uid: 'uid-a', email: 'a@teste.com'));
    await Future<void>.delayed(Duration.zero);

    expect(vm.status, SessionStatus.signedIn);
    expect(vm.user!.uid, 'uid-a');
    vm.dispose();
  });

  test('validação recusa e-mail e senha inválidos sem chamar o serviço',
      () async {
    final vm = SessionViewModel(auth);

    await vm.signIn('sem-arroba', '123456');
    expect(vm.errorMessage, 'E-mail inválido.');

    await vm.signIn('a@teste.com', '123');
    expect(vm.errorMessage, contains('6 caracteres'));
    expect(auth.currentUser, isNull);
    vm.dispose();
  });

  test('erro do serviço aparece como mensagem e libera o botão', () async {
    auth.nextError = const AuthException('E-mail ou senha incorretos.');
    final vm = SessionViewModel(auth);

    await vm.signIn('a@teste.com', 'errada1');

    expect(vm.errorMessage, 'E-mail ou senha incorretos.');
    expect(vm.busy, isFalse);
    expect(vm.status, isNot(SessionStatus.signedIn));
    vm.dispose();
  });

  test('login → signedIn; logout limpa dados locais e volta a signedOut',
      () async {
    final limpos = <String>[];
    final vm =
        SessionViewModel(auth, onSignOut: (uid) async => limpos.add(uid));

    await vm.signIn('a@teste.com', 'segura1');
    await Future<void>.delayed(Duration.zero);
    expect(vm.status, SessionStatus.signedIn);
    final uid = vm.user!.uid;

    await vm.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(limpos, [uid]);
    expect(auth.signOutCount, 1);
    expect(vm.status, SessionStatus.signedOut);
    vm.dispose();
  });
}
