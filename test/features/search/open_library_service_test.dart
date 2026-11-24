import 'dart:convert';

import 'package:estante_leituras/core/app_exception.dart';
import 'package:estante_leituras/features/search/data/open_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final okBody = jsonEncode({
    'numFound': 2,
    'docs': [
      {
        'key': '/works/OL1W',
        'title': 'Dom Casmurro',
        'author_name': ['Machado de Assis'],
        'first_publish_year': 1899,
        'cover_i': 12345,
      },
      {
        // sem autor, sem ano e sem capa
        'key': '/works/OL2W',
        'title': 'Obra anônima',
      },
      {
        // inválido: sem título → ignorado
        'key': '/works/OL3W',
      },
    ],
  });

  TypeMatcher<AppException> failureOf(FailureKind kind) =>
      isA<AppException>().having((e) => e.kind, 'kind', kind);

  test('converte a resposta 200 em BookSearchResult', () async {
    late Uri chamada;
    final service = OpenLibraryService(
      client: MockClient((request) async {
        chamada = request.url;
        return http.Response(okBody, 200);
      }),
    );

    final results = await service.search('dom casmurro');

    expect(chamada.host, 'openlibrary.org');
    expect(chamada.queryParameters['q'], 'dom casmurro');
    expect(results, hasLength(2));
    expect(results[0].title, 'Dom Casmurro');
    expect(results[0].author, 'Machado de Assis');
    expect(results[0].year, 1899);
    expect(
      results[0].coverUrl,
      'https://covers.openlibrary.org/b/id/12345-M.jpg',
    );
    expect(results[1].author, 'Autor desconhecido');
    expect(results[1].coverUrl, isNull);
  });

  test('HTTP 503 vira falha de servidor', () async {
    final service = OpenLibraryService(
      client: MockClient((_) async => http.Response('indisponível', 503)),
    );

    await expectLater(
      service.search('x y'),
      throwsA(failureOf(FailureKind.server)
          .having((e) => e.statusCode, 'statusCode', 503)),
    );
  });

  test('demora acima do limite vira timeout', () async {
    final service = OpenLibraryService(
      timeout: const Duration(milliseconds: 50),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(okBody, 200);
      }),
    );

    await expectLater(
      service.search('lento'),
      throwsA(failureOf(FailureKind.timeout)),
    );
  });

  test('falha de conexão vira offline', () async {
    final service = OpenLibraryService(
      client: MockClient((_) async => throw http.ClientException('sem rede')),
    );

    await expectLater(
      service.search('sem rede'),
      throwsA(failureOf(FailureKind.offline)),
    );
  });

  test('JSON inválido vira invalidData', () async {
    final service = OpenLibraryService(
      client: MockClient((_) async => http.Response('<html>erro</html>', 200)),
    );

    await expectLater(
      service.search('html'),
      throwsA(failureOf(FailureKind.invalidData)),
    );
  });

  test('JSON sem a lista docs vira invalidData', () {
    expect(
      () => OpenLibraryService.parse('{"resultado": []}'),
      throwsA(failureOf(FailureKind.invalidData)),
    );
  });
}
