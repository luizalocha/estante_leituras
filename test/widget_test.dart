import 'package:estante_leituras/features/auth/view/login_page.dart';
import 'package:estante_leituras/features/auth/viewmodel/session_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

/// Teste de widget da tela de login (contrato visual da autenticação).
void main() {
  late FakeAuthService auth;
  late SessionViewModel vm;

  setUp(() {
    auth = FakeAuthService();
    vm = SessionViewModel(auth);
  });

  tearDown(() async {
    vm.dispose();
    await auth.close();
  });

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
        ChangeNotifierProvider<SessionViewModel>.value(
          value: vm,
          child: const MaterialApp(home: LoginPage()),
        ),
      );

  testWidgets('enviar vazio mostra as validações e não autentica',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('alternar para cadastro muda o texto do botão', (tester) async {
    await pumpLogin(tester);
    expect(find.text('Entrar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login_toggle')));
    await tester.pump();

    expect(find.text('Criar conta'), findsOneWidget);
  });

  testWidgets('credenciais válidas autenticam', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login_email')), 'a@teste.com');
    await tester.enterText(find.byKey(const Key('login_password')), 'segura1');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(auth.currentUser?.email, 'a@teste.com');
    expect(find.byKey(const Key('login_error')), findsNothing);
  });
}
