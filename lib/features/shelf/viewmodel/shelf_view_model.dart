import 'package:flutter/foundation.dart';

import '../../../core/app_exception.dart';
import '../../search/data/book_search_result.dart';
import '../data/shelf_book.dart';
import '../data/shelf_repository.dart';

sealed class ShelfState {
  const ShelfState();
}

final class ShelfLoading extends ShelfState {
  const ShelfLoading();
}

final class ShelfEmpty extends ShelfState {
  const ShelfEmpty({required this.origin, required this.savedAt});
  final DataOrigin origin;
  final DateTime savedAt;
}

final class ShelfLoaded extends ShelfState {
  const ShelfLoaded({
    required this.books,
    required this.origin,
    required this.savedAt,
  });
  final List<ShelfBook> books;
  final DataOrigin origin;
  final DateTime savedAt;
}

final class ShelfError extends ShelfState {
  const ShelfError(this.message);
  final String message;
}

/// ViewModel da estante (tela principal).
///
/// Transições: loading → (loaded | empty | error); error → retry → loading.
/// Escritas só são liberadas quando os dados vieram do servidor.
class ShelfViewModel extends ChangeNotifier {
  ShelfViewModel({required ShelfRepository repository, required this.uid})
      : _repository = repository;

  final ShelfRepository _repository;
  final String uid;

  ShelfState _state = const ShelfLoading();
  String? _message;
  bool _saving = false;
  int _requestId = 0;
  bool _disposed = false;

  ShelfState get state => _state;
  bool get saving => _saving;

  List<ShelfBook> get books => switch (_state) {
        ShelfLoaded(:final books) => books,
        _ => const [],
      };

  DataOrigin? get origin => switch (_state) {
        ShelfLoaded(:final origin) => origin,
        ShelfEmpty(:final origin) => origin,
        _ => null,
      };

  bool get isOffline => origin == DataOrigin.cache;

  /// Criar, editar e remover exigem dados confirmados pelo servidor.
  bool get canWrite => origin == DataOrigin.remote && !_saving;

  /// Mensagem pontual (snackbar). Lida uma única vez.
  String? takeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  bool containsWork(String? workKey) =>
      workKey != null && books.any((b) => b.workKey == workKey);

  Future<void> load() async {
    final id = ++_requestId;
    _state = const ShelfLoading();
    _notify();
    try {
      final snapshot = await _repository.load(uid);
      if (id != _requestId) return; // resposta antiga: descarta
      _state = _fromBooks(snapshot.books, snapshot.origin, snapshot.savedAt);
    } on AppException catch (e) {
      if (id != _requestId) return;
      _state = ShelfError(e.message);
    }
    _notify();
  }

  Future<void> retry() => load();

  Future<bool> addFromSearch(BookSearchResult result) async {
    if (containsWork(result.workKey)) {
      _message = 'Este livro já está na sua estante.';
      _notify();
      return false;
    }
    return _write(() async {
      final created = await _repository.addFromSearch(uid, result);
      return [created, ...books];
    }, success: 'Livro adicionado à estante.');
  }

  Future<bool> updateBook(ShelfBook book) {
    if (book.notes.length > ShelfBook.maxNotes) {
      _message =
          'A anotação pode ter no máximo ${ShelfBook.maxNotes} caracteres.';
      _notify();
      return Future.value(false);
    }
    return _write(() async {
      final updated = await _repository.update(book);
      return [updated, ...books.where((b) => b.id != book.id)];
    }, success: 'Alterações salvas.');
  }

  Future<bool> deleteBook(ShelfBook book) {
    return _write(() async {
      await _repository.delete(book);
      return books.where((b) => b.id != book.id).toList();
    }, success: 'Livro removido da estante.');
  }

  Future<bool> _write(
    Future<List<ShelfBook>> Function() action, {
    required String success,
  }) async {
    if (!canWrite) {
      _message = isOffline
          ? 'Sem conexão: a estante está em modo somente leitura.'
          : 'Aguarde a estante carregar.';
      _notify();
      return false;
    }
    _saving = true;
    _notify();
    try {
      final newList = await action();
      final now = DateTime.now();
      _state = _fromBooks(newList, DataOrigin.remote, now);
      await _repository.saveCache(uid, newList);
      _message = success;
      return true;
    } on AppException catch (e) {
      _message = e.message;
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  ShelfState _fromBooks(
    List<ShelfBook> books,
    DataOrigin origin,
    DateTime savedAt,
  ) {
    return books.isEmpty
        ? ShelfEmpty(origin: origin, savedAt: savedAt)
        : ShelfLoaded(books: books, origin: origin, savedAt: savedAt);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
