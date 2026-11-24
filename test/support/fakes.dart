import 'dart:async';

import 'package:estante_leituras/core/app_exception.dart';
import 'package:estante_leituras/core/key_value_store.dart';
import 'package:estante_leituras/features/auth/data/auth_service.dart';
import 'package:estante_leituras/features/cover_photo/data/cover_photo_service.dart';
import 'package:estante_leituras/features/search/data/book_search_result.dart';
import 'package:estante_leituras/features/search/data/open_library_service.dart';
import 'package:estante_leituras/features/shelf/data/firestore_shelf_source.dart';
import 'package:estante_leituras/features/shelf/data/shelf_book.dart';
import 'package:estante_leituras/features/shelf/data/shelf_local_cache.dart';
import 'package:estante_leituras/features/shelf/data/shelf_repository.dart';

/// Implementações falsas usadas nos testes de unidade e de widget.
/// Nenhuma delas acessa rede, Firebase ou plugin nativo.

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

const offlineError = AppException(FailureKind.offline, 'Sem conexão.');

ShelfBook fakeBook(String id, {String owner = 'uid-a', String? workKey}) =>
    ShelfBook(
      id: id,
      ownerId: owner,
      title: 'Livro $id',
      author: 'Autora $id',
      workKey: workKey ?? '/works/$id',
      updatedAt: DateTime(2026, 11, 1),
    );

class FakeShelfRemoteSource implements ShelfRemoteSource {
  FakeShelfRemoteSource([List<ShelfBook>? initial]) : books = [...?initial];

  final List<ShelfBook> books;

  /// Se definido, a próxima chamada a fetchAll lança este erro.
  AppException? fetchError;

  /// Se definido, todas as escritas lançam este erro.
  AppException? writeError;

  /// Permite controlar quando fetchAll termina (teste de corrida).
  final List<Completer<List<ShelfBook>>> pendingFetches = [];
  bool holdFetches = false;

  int fetchCount = 0;
  int _nextId = 1;

  @override
  Future<List<ShelfBook>> fetchAll(String uid) async {
    fetchCount++;
    if (holdFetches) {
      final c = Completer<List<ShelfBook>>();
      pendingFetches.add(c);
      return c.future;
    }
    final error = fetchError;
    if (error != null) throw error;
    return books.where((b) => b.ownerId == uid).toList();
  }

  @override
  Future<ShelfBook> create(ShelfBook draft) async {
    if (writeError != null) throw writeError!;
    final created = draft.copyWith(
      id: 'novo-${_nextId++}',
      createdAt: DateTime(2026, 11, 2),
      updatedAt: DateTime(2026, 11, 2),
    );
    books.add(created);
    return created;
  }

  @override
  Future<void> update(ShelfBook book) async {
    if (writeError != null) throw writeError!;
    final i = books.indexWhere((b) => b.id == book.id);
    books[i] = book;
  }

  @override
  Future<void> delete(String bookId) async {
    if (writeError != null) throw writeError!;
    books.removeWhere((b) => b.id == bookId);
  }
}

class FakeCoverPhotoService implements CoverPhotoService {
  PhotoResult nextCameraResult =
      const PhotoResult(PhotoOutcome.saved, path: '/fake/capa.jpg');
  PhotoResult nextGalleryResult =
      const PhotoResult(PhotoOutcome.saved, path: '/fake/galeria.jpg');
  final List<String> deleted = [];
  int settingsOpened = 0;

  @override
  Future<PhotoResult> takePhoto(String uid, String bookId) async =>
      nextCameraResult;

  @override
  Future<PhotoResult> pickFromGallery(String uid, String bookId) async =>
      nextGalleryResult;

  @override
  Future<String?> existingCover(String uid, String bookId) async => null;

  @override
  Future<void> deleteCover(String uid, String bookId) async {
    deleted.add('${uid}_$bookId');
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class FakeBookSearchService implements BookSearchService {
  List<BookSearchResult> results = const [];
  AppException? error;
  final List<String> queries = [];

  @override
  Future<List<BookSearchResult>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }
}

class FakeAuthService implements AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  AuthException? nextError;
  int signOutCount = 0;

  /// Emite o estado atual (simula a restauração de sessão do Firebase).
  void emitCurrent() => _controller.add(_user);

  void setUser(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn(String email, String password) async {
    if (nextError != null) throw nextError!;
    setUser(AppUser(uid: 'uid-${email.hashCode}', email: email));
  }

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);

  @override
  Future<void> signOut() async {
    signOutCount++;
    setUser(null);
  }

  Future<void> close() => _controller.close();
}

/// Monta um ShelfRepository real com dependências falsas.
ShelfRepository buildRepository({
  required FakeShelfRemoteSource remote,
  InMemoryKeyValueStore? store,
  FakeCoverPhotoService? covers,
  DateTime? now,
}) {
  return ShelfRepository(
    remote: remote,
    cache: ShelfLocalCache(store ?? InMemoryKeyValueStore()),
    covers: covers ?? FakeCoverPhotoService(),
    now: () => now ?? DateTime(2026, 11, 20, 14, 32),
  );
}
