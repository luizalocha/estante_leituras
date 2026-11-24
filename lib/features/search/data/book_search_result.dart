/// Livro retornado pela busca no serviço Web (Open Library).
class BookSearchResult {
  const BookSearchResult({
    required this.workKey,
    required this.title,
    required this.author,
    this.year,
    this.coverUrl,
  });

  /// Identificador da obra na Open Library, ex.: "/works/OL45804W".
  final String workKey;
  final String title;
  final String author;
  final int? year;
  final String? coverUrl;
}
