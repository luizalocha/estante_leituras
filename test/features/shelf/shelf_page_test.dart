import 'dart:async';

import 'package:estante_leituras/features/shelf/data/shelf_book.dart';
import 'package:estante_leituras/features/shelf/view/shelf_page.dart';
import 'package:estante_leituras/features/shelf/viewmodel/shelf_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fakes.dart';

/// Testes de widget da tela principal: cada estado do ViewModel precisa ter
/// uma representação visual diferente e o erro precisa permitir recuperação.
void main() {
  late FakeShelfRemoteSource remote;
  late InMemoryKeyValueStore store;

  setUp(() {
    remote = FakeShelfRemoteSource([fakeBook('1')]);
    store = InMemoryKeyValueStore();
  });

  Future<ShelfViewModel> pumpShelf(WidgetTester tester) async {
    final vm = ShelfViewModel(
      repository: buildRepository(remote: remote, store: store),
      uid: 'uid-a',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<ShelfViewModel>.value(
        value: vm,
        child: const MaterialApp(home: ShelfPage()),
      ),
    );
    return vm;
  }

  testWidgets('mostra o indicador enquanto carrega e depois a lista',
      (tester) async {
    remote.holdFetches = true;
    final vm = await pumpShelf(tester);
    unawaited(vm.load());
    await tester.pump();

    expect(find.byKey(const Key('shelf_loading')), findsOneWidget);

    remote.pendingFetches.single.complete([fakeBook('1')]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shelf_loading')), findsNothing);
    expect(find.text('Livro 1'), findsOneWidget);
  });

  testWidgets('estante vazia mostra mensagem própria', (tester) async {
    remote.books.clear();
    final vm = await pumpShelf(tester);
    await vm.load();
    await tester.pumpAndSettle();

    expect(find.text('Sua estante está vazia'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem e "Tentar novamente" recupera',
      (tester) async {
    remote.fetchError = offlineError;
    final vm = await pumpShelf(tester);
    await vm.load();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shelf_error')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    remote.fetchError = null;
    await tester.tap(find.byKey(const Key('retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shelf_error')), findsNothing);
    expect(find.text('Livro 1'), findsOneWidget);
  });

  testWidgets('offline exibe aviso com horário e bloqueia a busca',
      (tester) async {
    final vm = await pumpShelf(tester);
    await vm.load(); // grava cache às 14:32 (relógio falso)
    remote.fetchError = offlineError;
    await vm.load();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offline_banner')), findsOneWidget);
    expect(find.textContaining('20/11 às 14:32'), findsOneWidget);
    expect(find.text('Livro 1'), findsOneWidget);

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('open_search')),
    );
    expect(fab.onPressed, isNull);
  });

  testWidgets('mostra status e nota do livro na lista', (tester) async {
    remote.books
      ..clear()
      ..add(fakeBook('9').copyWith(status: ReadingStatus.reading, rating: 5));
    final vm = await pumpShelf(tester);
    await vm.load();
    await tester.pumpAndSettle();

    expect(find.text('Autora 9 · Lendo'), findsOneWidget);
    expect(find.text('★ 5'), findsOneWidget);
  });
}
