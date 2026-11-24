import 'package:flutter/foundation.dart';

import '../../cover_photo/data/cover_photo_service.dart';
import '../data/shelf_book.dart';
import 'shelf_view_model.dart';

/// ViewModel da tela de detalhes: edição (status, nota, anotação),
/// remoção e foto da capa (recurso nativo).
class BookDetailViewModel extends ChangeNotifier {
  BookDetailViewModel({
    required this.book,
    required ShelfViewModel shelf,
    required CoverPhotoService photos,
  })  : _shelf = shelf,
        _photos = photos,
        _status = book.status,
        _rating = book.rating,
        _notes = book.notes;

  final ShelfBook book;
  final ShelfViewModel _shelf;
  final CoverPhotoService _photos;

  ReadingStatus _status;
  int _rating;
  String _notes;
  String? _photoPath;
  bool _photoBusy = false;
  String? _photoMessage;
  bool _showSettingsShortcut = false;
  bool _disposed = false;

  ReadingStatus get status => _status;
  int get rating => _rating;
  String get notes => _notes;
  String? get photoPath => _photoPath;
  bool get photoBusy => _photoBusy;
  String? get photoMessage => _photoMessage;
  bool get showSettingsShortcut => _showSettingsShortcut;
  bool get canEdit => _shelf.canWrite;
  bool get saving => _shelf.saving;

  Future<void> init() async {
    _photoPath = await _photos.existingCover(book.ownerId, book.id);
    _notify();
  }

  void setStatus(ReadingStatus value) {
    _status = value;
    _notify();
  }

  void setRating(int value) {
    // Tocar na mesma estrela de novo remove a nota.
    _rating = value == _rating ? 0 : value;
    _notify();
  }

  void setNotes(String value) {
    _notes = value;
  }

  Future<void> takePhoto() =>
      _photoAction(() => _photos.takePhoto(book.ownerId, book.id));

  Future<void> pickFromGallery() =>
      _photoAction(() => _photos.pickFromGallery(book.ownerId, book.id));

  Future<void> _photoAction(Future<PhotoResult> Function() action) async {
    _photoBusy = true;
    _photoMessage = null;
    _showSettingsShortcut = false;
    _notify();
    final result = await action();
    switch (result.outcome) {
      case PhotoOutcome.saved:
        _photoPath = result.path;
        _photoMessage = 'Foto salva somente neste aparelho.';
      case PhotoOutcome.cancelled:
        _photoMessage = 'Nenhuma foto foi escolhida.';
      case PhotoOutcome.denied:
        _photoMessage = 'Permissão da câmera negada. Você pode escolher uma '
            'imagem da galeria ou continuar sem foto.';
      case PhotoOutcome.permanentlyDenied:
        _photoMessage = 'A câmera está bloqueada para este app. Libere nas '
            'Configurações ou use a galeria.';
        _showSettingsShortcut = true;
      case PhotoOutcome.unavailable:
        _photoMessage = 'Câmera indisponível neste aparelho. Use a galeria.';
    }
    _photoBusy = false;
    _notify();
  }

  Future<void> removePhoto() async {
    await _photos.deleteCover(book.ownerId, book.id);
    _photoPath = null;
    _photoMessage = 'Foto removida do aparelho.';
    _notify();
  }

  Future<void> openSettings() async {
    await _photos.openSettings();
  }

  Future<bool> save() => _shelf.updateBook(
        book.copyWith(status: _status, rating: _rating, notes: _notes.trim()),
      );

  Future<bool> delete() => _shelf.deleteBook(book);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
