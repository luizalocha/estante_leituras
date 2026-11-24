import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_dependencies.dart';
import 'core/key_value_store.dart';
import 'features/auth/data/auth_service.dart';
import 'features/cover_photo/data/cover_photo_service.dart';
import 'features/search/data/book_search_repository.dart';
import 'features/search/data/open_library_service.dart';
import 'features/shelf/data/firestore_shelf_source.dart';
import 'features/shelf/data/shelf_local_cache.dart';
import 'features/shelf/data/shelf_repository.dart';
import 'firebase_options.dart';

/// `flutter run --dart-define=USE_EMULATOR=true` usa o Firebase Emulator Suite.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_EMULATOR');

/// Inicializa Firebase e monta as dependências reais do app.
///
/// [searchService] permite que o teste de integração use uma busca
/// determinística, sem depender da disponibilidade da Open Library.
Future<AppDependencies> bootstrap({BookSearchService? searchService}) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  // Cache do Firestore desligado: o comportamento offline é controlado
  // explicitamente pelo ShelfLocalCache (origem dos dados sinalizada na tela).
  firestore.settings = const Settings(persistenceEnabled: false);

  if (useFirebaseEmulator) {
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    firestore.useFirestoreEmulator(host, 8080);
  }

  final prefs = await SharedPreferences.getInstance();
  final covers = DeviceCoverPhotoService();

  return AppDependencies(
    auth: FirebaseAuthService(FirebaseAuth.instance),
    searchRepository:
        BookSearchRepository(searchService ?? OpenLibraryService()),
    shelfRepository: ShelfRepository(
      remote: FirestoreShelfSource(firestore),
      cache: ShelfLocalCache(SharedPreferencesStore(prefs)),
      covers: covers,
    ),
    coverPhotos: covers,
  );
}
