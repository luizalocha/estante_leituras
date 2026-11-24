import 'package:estante_leituras/app.dart';
import 'package:estante_leituras/bootstrap.dart';
import 'package:estante_leituras/features/search/data/book_search_result.dart';
import 'package:estante_leituras/features/search/data/open_library_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Jornada crítica, ponta a ponta, no Android com Firebase real
/// (ou no Emulator Suite com --dart-define=USE_EMULATOR=true):
///
/// cadastro → estante vazia → busca → adicionar (create) → recarregar do
/// servidor (read) → editar nota (update) → remover (delete) → logout.
///
/// A busca usa um serviço determinístico para não depender da Open Library.
/// Dados de teste: conta descartável `e2e_<timestamp>@teste.example.com`,
/// apagada no final junto com o livro criado.
class _E2ESearchService implements BookSearchService {
  @override
  Future<List<BookSearchResult>> search(String query) async => const [
        BookSearchResult(
          workKey: '/works/E2E1W',
          title: 'E2E - Livro de teste',
          author: 'Autora de Teste',
          year: 2026,
        ),
      ];
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Não apareceu a tempo: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jornada completa da estante', (tester) async {
    final deps = await bootstrap(searchService: _E2ESearchService());
    await deps.auth.signOut(); // começa sem sessão

    final email =
        'e2e_${DateTime.now().millisecondsSinceEpoch}@teste.example.com';
    const password = 'Teste#2026';

    await tester.pumpWidget(EstanteApp(deps: deps));
    await pumpUntilFound(tester, find.byKey(const Key('login_submit')));

    // 1. Cadastro
    await tester.tap(find.byKey(const Key('login_toggle')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login_email')), email);
    await tester.enterText(find.byKey(const Key('login_password')), password);
    await tester.tap(find.byKey(const Key('login_submit')));

    // 2. Rota protegida: estante vazia
    await pumpUntilFound(tester, find.text('Sua estante está vazia'));

    // 3. Busca e criação (create)
    await tester.tap(find.byKey(const Key('open_search')));
    await pumpUntilFound(tester, find.byKey(const Key('search_field')));
    await tester.enterText(find.byKey(const Key('search_field')), 'E2E');
    await tester.tap(find.byKey(const Key('search_submit')));
    await pumpUntilFound(tester, find.byKey(const Key('add_/works/E2E1W')));
    await tester.tap(find.byKey(const Key('add_/works/E2E1W')));
    await pumpUntilFound(tester, find.byIcon(Icons.check_circle));
    await tester.pageBack();

    // 4. Consulta (read): recarrega do servidor
    await pumpUntilFound(tester, find.text('E2E - Livro de teste'));
    await tester.tap(find.byKey(const Key('refresh_button')));
    await pumpUntilFound(tester, find.text('E2E - Livro de teste'));
    expect(find.byKey(const Key('offline_banner')), findsNothing);

    // 5. Atualização (update): nota 4
    await tester.tap(find.text('E2E - Livro de teste'));
    await pumpUntilFound(tester, find.byKey(const Key('rating_4')));
    await tester.tap(find.byKey(const Key('rating_4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_book')));
    await pumpUntilFound(tester, find.text('★ 4'));

    // 6. Remoção (delete)
    await tester.tap(find.text('E2E - Livro de teste'));
    await pumpUntilFound(tester, find.byKey(const Key('delete_book')));
    await tester.tap(find.byKey(const Key('delete_book')));
    await pumpUntilFound(tester, find.byKey(const Key('confirm_delete')));
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await pumpUntilFound(tester, find.text('Sua estante está vazia'));

    // 7. Logout: volta para o login
    await tester.tap(find.byKey(const Key('logout_button')));
    await pumpUntilFound(tester, find.byKey(const Key('login_submit')));
    expect(find.text('Minha estante'), findsNothing);

    // Limpeza: apaga a conta descartável.
    final cred = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    await cred.user!.delete();
    await tester.pump(const Duration(seconds: 1));
  });
}
