import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/app_exception.dart';
import 'book_search_result.dart';

/// Contrato do serviço de busca de livros.
abstract interface class BookSearchService {
  Future<List<BookSearchResult>> search(String query);
}

/// Serviço Web: Open Library Search API (https://openlibrary.org/dev/docs/api/search).
///
/// Responsabilidades:
/// * montar a requisição e aplicar timeout;
/// * tratar status HTTP diferente de 200;
/// * converter o JSON em [BookSearchResult], ignorando itens inválidos;
/// * transformar qualquer falha em [AppException].
class OpenLibraryService implements BookSearchService {
  OpenLibraryService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _host = 'openlibrary.org';
  static const _fields = 'key,title,author_name,first_publish_year,cover_i';

  @override
  Future<List<BookSearchResult>> search(String query) async {
    final uri = Uri.https(_host, '/search.json', {
      'q': query,
      'fields': _fields,
      'limit': '20',
    });

    final http.Response response;
    try {
      response = await _client.get(uri, headers: const {
        // A Open Library pede um User-Agent identificando o app.
        'User-Agent': 'EstanteLeituras/1.0 (trabalho academico Flutter)',
        'Accept': 'application/json',
      }).timeout(timeout);
    } on TimeoutException {
      throw const AppException(
        FailureKind.timeout,
        'A busca demorou demais. Tente novamente.',
      );
    } on SocketException {
      throw const AppException(
        FailureKind.offline,
        'Sem conexão com a internet.',
      );
    } on http.ClientException {
      throw const AppException(
        FailureKind.offline,
        'Não foi possível conectar ao serviço de livros.',
      );
    }

    if (response.statusCode != 200) {
      throw AppException(
        FailureKind.server,
        'Serviço de livros indisponível (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return parse(response.body);
  }

  /// Converte o corpo da resposta. Público para facilitar os testes.
  static List<BookSearchResult> parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const AppException(
        FailureKind.invalidData,
        'Resposta inválida do serviço de livros.',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['docs'] is! List) {
      throw const AppException(
        FailureKind.invalidData,
        'Resposta inválida do serviço de livros.',
      );
    }

    final results = <BookSearchResult>[];
    for (final item in decoded['docs'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final key = item['key'];
      final title = item['title'];
      if (key is! String || title is! String || title.trim().isEmpty) continue;

      final authors = item['author_name'];
      final author = authors is List && authors.isNotEmpty
          ? authors.whereType<String>().take(3).join(', ')
          : 'Autor desconhecido';

      final year = item['first_publish_year'];
      final coverId = item['cover_i'];

      results.add(BookSearchResult(
        workKey: key,
        title: title.trim(),
        author: author.isEmpty ? 'Autor desconhecido' : author,
        year: year is int ? year : null,
        coverUrl: coverId is int
            ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
            : null,
      ));
    }
    return results;
  }
}
