import 'package:estante_leituras/core/app_exception.dart';
import 'package:estante_leituras/features/search/data/book_search_result.dart';
import 'package:estante_leituras/features/shelf/data/shelf_repository.dart';
import 'package:estante_leituras/features/shelf/viewmodel/shelf_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeShelfRemoteSource remote;
  late InMemoryKeyValueStore store;
  late FakeCoverPhotoService covers;

  ShelfViewModel buildVm({String uid = 'uid-a'}) => ShelfViewModel(
        repository:
            buildRepository(remote: remote, store: store, covers: covers),
        uid: uid,
      );

  /// Registra o tipo de cada estado publicado pelo ViewModel.
  List<Type> recordStates(ShelfViewModel vm) {
    final types = <Type>[];
    vm.addListener(() => types.add(vm.state.runtimeType));
    return types;
  }

  setUp(() {
    remote = FakeShelfRemoteSource([fakeBook('1'), fakeBook('2')]);
    store = InMemoryKeyValueStore();
    covers = FakeCoverPhotoService();
  });

  group('carregamento', () {
    test('loading → sucesso com dados do servidor', () async {
      final vm = buildVm();
      final states = recordStates(vm);

      await vm.load();

      expect(states, [ShelfLoading, ShelfLoaded]);
      expect(vm.books, hasLength(2));
      expect(vm.origin, DataOrigin.remote);
      expect(vm.canWrite, isTrue);
    });

    test('estante sem livros gera estado vazio', () async {
      remote.books.clear();
      final vm = buildVm();

      await vm.load();

      expect(vm.state, isA<ShelfEmpty>());
    });

    test('só traz os livros do próprio UID', () async {
      remote.books.add(fakeBook('de-b', owner: 'uid-b'));
      final vm = buildVm();

      await vm.load();

      expect(vm.books.map((b) => b.ownerId), everyElement('uid-a'));
    });

    test('erro sem cache → ShelfError; retry → sucesso', () async {
      remote.fetchError = offlineError;
      final vm = buildVm();
      final states = recordStates(vm);

      await vm.load();
      expect(vm.state, isA<ShelfError>());

      remote.fetchError = null;
      await vm.retry();

      expect(states, [ShelfLoading, ShelfError, ShelfLoading, ShelfLoaded]);
      expect(vm.books, hasLength(2));
    });

    test('sem rede usa o cache e sinaliza a origem', () async {
      final vm = buildVm();
      await vm.load(); // online: grava o cache

      remote.fetchError = offlineError;
      await vm.load();

      final state = vm.state as ShelfLoaded;
      expect(state.origin, DataOrigin.cache);
      expect(state.savedAt, DateTime(2026, 11, 20, 14, 32));
      expect(state.books, hasLength(2));
      expect(vm.isOffline, isTrue);
      expect(vm.canWrite, isFalse, reason: 'offline é somente leitura');
    });

    test('acesso negado não cai para o cache', () async {
      final vm = buildVm();
      await vm.load();

      remote.fetchError = const AppException(
        FailureKind.permissionDenied,
        'Acesso negado a este dado.',
      );
      await vm.load();

      expect(vm.state, isA<ShelfError>());
    });

    test('resposta antiga não sobrescreve a mais recente', () async {
      remote.holdFetches = true;
      final vm = buildVm();

      final primeira = vm.load();
      final segunda = vm.load();

      // A segunda termina antes, com 1 livro.
      remote.pendingFetches[1].complete([fakeBook('novo')]);
      await segunda;
      // A primeira chega depois, com dados antigos.
      remote.pendingFetches[0].complete([fakeBook('antigo')]);
      await primeira;

      expect(vm.books.single.id, 'novo');
    });
  });

  group('escrita', () {
    const result = BookSearchResult(
      workKey: '/works/OL1W',
      title: 'Dom Casmurro',
      author: 'Machado de Assis',
      year: 1899,
    );

    test('adicionar grava com o UID do usuário e atualiza a lista', () async {
      final vm = buildVm();
      await vm.load();

      final ok = await vm.addFromSearch(result);

      expect(ok, isTrue);
      expect(vm.books.first.title, 'Dom Casmurro');
      expect(remote.books.last.ownerId, 'uid-a');
      expect(vm.takeMessage(), 'Livro adicionado à estante.');
    });

    test('não adiciona o mesmo livro duas vezes', () async {
      final vm = buildVm();
      await vm.load();
      await vm.addFromSearch(result);
      vm.takeMessage();

      final ok = await vm.addFromSearch(result);

      expect(ok, isFalse);
      expect(vm.takeMessage(), contains('já está'));
    });

    test('escrita bloqueada quando os dados vieram do cache', () async {
      final vm = buildVm();
      await vm.load();
      remote.fetchError = offlineError;
      await vm.load();

      final ok = await vm.addFromSearch(result);

      expect(ok, isFalse);
      expect(vm.takeMessage(), contains('somente leitura'));
    });

    test('remover apaga do servidor e a foto local', () async {
      final vm = buildVm();
      await vm.load();
      final alvo = vm.books.first;

      final ok = await vm.deleteBook(alvo);

      expect(ok, isTrue);
      expect(remote.books.any((b) => b.id == alvo.id), isFalse);
      expect(covers.deleted, ['uid-a_${alvo.id}']);
    });

    test('falha na escrita mantém a lista e informa o erro', () async {
      final vm = buildVm();
      await vm.load();
      remote.writeError = offlineError;

      final ok = await vm.deleteBook(vm.books.first);

      expect(ok, isFalse);
      expect(vm.books, hasLength(2));
      expect(vm.takeMessage(), 'Sem conexão.');
    });
  });
}
