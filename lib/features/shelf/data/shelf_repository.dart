import '../../../core/app_exception.dart';
import '../../cover_photo/data/cover_photo_service.dart';
import '../../search/data/book_search_result.dart';
import 'firestore_shelf_source.dart';
import 'shelf_book.dart';
import 'shelf_local_cache.dart';

/// De onde vieram os dados exibidos.
enum DataOrigin { remote, cache }

class ShelfSnapshot {
  const ShelfSnapshot({
    required this.books,
    required this.origin,
    required this.savedAt,
  });

  final List<ShelfBook> books;
  final DataOrigin origin;
  final DateTime savedAt;
}

/// Coordena Firestore (fonte da verdade), cache local e fotos.
///
/// Estratégia offline: leitura com fallback para o cache; escrita somente
/// online (o ViewModel bloqueia criação, edição e remoção sem rede).
class ShelfRepository {
  ShelfRepository({
    required ShelfRemoteSource remote,
    required ShelfLocalCache cache,
    required CoverPhotoService covers,
    DateTime Function()? now,
  })  : _remote = remote,
        _cache = cache,
        _covers = covers,
        _now = now ?? DateTime.now;

  final ShelfRemoteSource _remote;
  final ShelfLocalCache _cache;
  final CoverPhotoService _covers;
  final DateTime Function() _now;

  Future<ShelfSnapshot> load(String uid) async {
    try {
      final books = _sorted(await _remote.fetchAll(uid));
      final now = _now();
      await _cache.save(uid, books, now);
      return ShelfSnapshot(
          books: books, origin: DataOrigin.remote, savedAt: now);
    } on AppException catch (e) {
      if (!e.isConnectivity) rethrow;
      final cached = await _cache.read(uid);
      if (cached == null) {
        throw const AppException(
          FailureKind.offline,
          'Sem conexão e ainda não há dados salvos neste aparelho.',
        );
      }
      return ShelfSnapshot(
        books: _sorted(cached.books),
        origin: DataOrigin.cache,
        savedAt: cached.savedAt,
      );
    }
  }

  Future<ShelfBook> addFromSearch(String uid, BookSearchResult result) {
    final title = result.title.length > ShelfBook.maxTitle
        ? result.title.substring(0, ShelfBook.maxTitle)
        : result.title;
    final draft = ShelfBook(
      id: '',
      ownerId: uid,
      title: title,
      author: result.author,
      year: result.year,
      coverUrl: result.coverUrl,
      workKey: result.workKey,
    );
    return _remote.create(draft);
  }

  Future<ShelfBook> update(ShelfBook book) async {
    await _remote.update(book);
    return book.copyWith(updatedAt: _now());
  }

  Future<void> delete(ShelfBook book) async {
    await _remote.delete(book.id);
    await _covers.deleteCover(book.ownerId, book.id);
  }

  /// Atualiza o cache depois de uma escrita confirmada pelo servidor.
  Future<void> saveCache(String uid, List<ShelfBook> books) =>
      _cache.save(uid, books, _now());

  /// Chamado no logout.
  Future<void> clearLocal(String uid) => _cache.clear(uid);

  static List<ShelfBook> _sorted(List<ShelfBook> books) {
    final copy = [...books];
    copy.sort((a, b) {
      final da = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return copy;
  }
}
