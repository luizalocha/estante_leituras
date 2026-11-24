import 'dart:convert';

import '../../../core/key_value_store.dart';
import 'shelf_book.dart';

class CachedShelf {
  const CachedShelf({required this.books, required this.savedAt});

  final List<ShelfBook> books;
  final DateTime savedAt;
}

/// Cache local da estante, separado por UID.
///
/// * Finalidade: mostrar a última estante conhecida quando não há rede.
/// * Atualização: substituído a cada leitura bem-sucedida do Firestore e
///   depois de cada criação, edição ou remoção confirmada.
/// * Invalidação: removido no logout; dados corrompidos são descartados.
class ShelfLocalCache {
  ShelfLocalCache(this._store);

  final KeyValueStore _store;

  static String keyFor(String uid) => 'shelf_cache_v1_$uid';

  Future<void> save(String uid, List<ShelfBook> books, DateTime savedAt) {
    final payload = jsonEncode({
      'savedAt': savedAt.toIso8601String(),
      'books': [for (final b in books) b.toJson()],
    });
    return _store.write(keyFor(uid), payload);
  }

  Future<CachedShelf?> read(String uid) async {
    final raw = await _store.read(keyFor(uid));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(map['savedAt'] as String);
      final books = (map['books'] as List)
          .cast<Map<String, dynamic>>()
          .map(ShelfBook.fromJson)
          .toList();
      return CachedShelf(books: books, savedAt: savedAt);
    } catch (_) {
      // Formato inesperado: descarta para não exibir dado inconsistente.
      await _store.delete(keyFor(uid));
      return null;
    }
  }

  Future<void> clear(String uid) => _store.delete(keyFor(uid));
}
