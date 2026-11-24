import 'package:flutter/foundation.dart';

import '../../../core/app_exception.dart';
import '../data/book_search_repository.dart';
import '../data/book_search_result.dart';

sealed class SearchState {
  const SearchState();
}

final class SearchIdle extends SearchState {
  const SearchIdle();
}

final class SearchLoading extends SearchState {
  const SearchLoading(this.query);
  final String query;
}

final class SearchSuccess extends SearchState {
  const SearchSuccess(this.query, this.results);
  final String query;
  final List<BookSearchResult> results;
}

final class SearchEmpty extends SearchState {
  const SearchEmpty(this.query);
  final String query;
}

final class SearchError extends SearchState {
  const SearchError(this.query, this.message);
  final String query;
  final String message;
}

/// Estados da busca: ocioso → carregando → sucesso | vazio | erro.
///
/// Cada busca recebe um identificador; uma resposta antiga que chegue
/// depois de uma busca mais nova é descartada.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._repository);

  final BookSearchRepository _repository;

  SearchState _state = const SearchIdle();
  String? _validationMessage;
  String _lastQuery = '';
  int _requestId = 0;
  bool _disposed = false;

  SearchState get state => _state;
  String? get validationMessage => _validationMessage;

  Future<void> search(String raw) async {
    final query = raw.trim();
    if (query.length < 2) {
      _validationMessage = 'Digite pelo menos 2 caracteres.';
      _notify();
      return;
    }
    _validationMessage = null;
    _lastQuery = query;
    final id = ++_requestId;
    _state = SearchLoading(query);
    _notify();

    try {
      final results = await _repository.search(query);
      if (id != _requestId) return;
      _state =
          results.isEmpty ? SearchEmpty(query) : SearchSuccess(query, results);
    } on AppException catch (e) {
      if (id != _requestId) return;
      _state = SearchError(query, e.message);
    }
    _notify();
  }

  Future<void> retry() => search(_lastQuery);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
