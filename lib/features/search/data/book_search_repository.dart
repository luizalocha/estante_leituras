import 'book_search_result.dart';
import 'open_library_service.dart';

/// Repositório da busca: normaliza a consulta e remove duplicados.
///
/// A View e o ViewModel não sabem que os dados vêm da Open Library;
/// trocar de API exige mudar só o Service.
class BookSearchRepository {
  BookSearchRepository(this._service);

  final BookSearchService _service;

  Future<List<BookSearchResult>> search(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    final results = await _service.search(normalized);
    final seen = <String>{};
    return [
      for (final r in results)
        if (seen.add(r.workKey)) r,
    ];
  }
}
