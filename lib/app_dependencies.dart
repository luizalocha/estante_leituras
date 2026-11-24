import 'features/auth/data/auth_service.dart';
import 'features/cover_photo/data/cover_photo_service.dart';
import 'features/search/data/book_search_repository.dart';
import 'features/shelf/data/shelf_repository.dart';

/// Dependências do app, montadas em `bootstrap.dart`.
/// Nos testes, cada item pode ser trocado por uma versão falsa.
class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.searchRepository,
    required this.shelfRepository,
    required this.coverPhotos,
  });

  final AuthService auth;
  final BookSearchRepository searchRepository;
  final ShelfRepository shelfRepository;
  final CoverPhotoService coverPhotos;
}
