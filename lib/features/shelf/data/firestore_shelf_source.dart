import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app_exception.dart';
import 'shelf_book.dart';

/// Contrato da fonte remota da estante.
abstract interface class ShelfRemoteSource {
  Future<List<ShelfBook>> fetchAll(String uid);
  Future<ShelfBook> create(ShelfBook draft);
  Future<void> update(ShelfBook book);
  Future<void> delete(String bookId);
}

/// CRUD na coleção `books` do Cloud Firestore.
///
/// Cada documento tem o campo `ownerId` com o UID do dono. A consulta filtra
/// por esse campo, mas quem garante o isolamento entre usuários são as regras
/// em `firestore.rules`.
class FirestoreShelfSource implements ShelfRemoteSource {
  FirestoreShelfSource(
    this._db, {
    this.timeout = const Duration(seconds: 10),
  });

  final FirebaseFirestore _db;
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> get _books =>
      _db.collection('books');

  @override
  Future<List<ShelfBook>> fetchAll(String uid) => _guard(() async {
        // Source.server: força a ida ao servidor. Sem rede, falha e o
        // repositório decide usar o cache local (com origem sinalizada).
        final snapshot = await _books
            .where('ownerId', isEqualTo: uid)
            .get(const GetOptions(source: Source.server))
            .timeout(timeout);
        return snapshot.docs.map(_fromDoc).toList();
      });

  @override
  Future<ShelfBook> create(ShelfBook draft) => _guard(() async {
        final ref = _books.doc();
        await ref.set({
          ...draft.toFirestoreFields(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(timeout);
        final now = DateTime.now();
        return draft.copyWith(id: ref.id, createdAt: now, updatedAt: now);
      });

  @override
  Future<void> update(ShelfBook book) => _guard(() async {
        // Só os campos editáveis; as regras recusam mudança em outros campos.
        await _books.doc(book.id).update({
          'status': book.status.code,
          'rating': book.rating,
          'notes': book.notes,
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(timeout);
      });

  @override
  Future<void> delete(String bookId) => _guard(() async {
        await _books.doc(bookId).delete().timeout(timeout);
      });

  ShelfBook _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, Object?>.from(doc.data());
    for (final field in ['createdAt', 'updatedAt']) {
      final value = data[field];
      if (value is Timestamp) data[field] = value.toDate();
    }
    return ShelfBook.fromMap(doc.id, data);
  }

  /// Converte exceções do Firebase em [AppException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TimeoutException {
      throw const AppException(
        FailureKind.timeout,
        'O servidor não respondeu a tempo. Verifique a conexão.',
      );
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw const AppException(
            FailureKind.permissionDenied,
            'Acesso negado a este dado.',
          );
        case 'unavailable':
        case 'deadline-exceeded':
          throw const AppException(
            FailureKind.offline,
            'Sem conexão com o servidor.',
          );
        case 'not-found':
          throw const AppException(
            FailureKind.server,
            'Este livro não existe mais na estante.',
          );
        default:
          throw const AppException(
            FailureKind.unknown,
            'Erro ao acessar a estante. Tente novamente.',
          );
      }
    }
  }
}
