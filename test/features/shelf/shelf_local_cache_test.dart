import 'package:estante_leituras/features/shelf/data/shelf_local_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test('grava e lê a estante separada por UID', () async {
    final store = InMemoryKeyValueStore();
    final cache = ShelfLocalCache(store);
    final savedAt = DateTime(2026, 11, 20, 9, 15);

    await cache.save('uid-a', [fakeBook('1')], savedAt);

    final lido = await cache.read('uid-a');
    expect(lido!.books.single.title, 'Livro 1');
    expect(lido.savedAt, savedAt);
    expect(await cache.read('uid-b'), isNull);
  });

  test('conteúdo corrompido é descartado', () async {
    final store = InMemoryKeyValueStore();
    store.data[ShelfLocalCache.keyFor('uid-a')] = '{isso não é json';
    final cache = ShelfLocalCache(store);

    expect(await cache.read('uid-a'), isNull);
    expect(store.data, isEmpty);
  });

  test('clear remove os dados da conta (logout)', () async {
    final store = InMemoryKeyValueStore();
    final cache = ShelfLocalCache(store);
    await cache.save('uid-a', [fakeBook('1')], DateTime(2026));

    await cache.clear('uid-a');

    expect(await cache.read('uid-a'), isNull);
  });
}
