import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum PhotoOutcome { saved, cancelled, denied, permanentlyDenied, unavailable }

class PhotoResult {
  const PhotoResult(this.outcome, {this.path});

  final PhotoOutcome outcome;
  final String? path;
}

/// Recurso nativo: foto da capa do livro (câmera ou galeria).
abstract interface class CoverPhotoService {
  Future<PhotoResult> takePhoto(String uid, String bookId);
  Future<PhotoResult> pickFromGallery(String uid, String bookId);
  Future<String?> existingCover(String uid, String bookId);
  Future<void> deleteCover(String uid, String bookId);
  Future<bool> openSettings();
}

/// Implementação com permission_handler + image_picker.
///
/// Privacidade:
/// * a foto fica SOMENTE no armazenamento privado do app (não vai para o
///   Firestore nem para outro servidor);
/// * a imagem é reduzida (máx. 1080 px, qualidade 80) — só o necessário para
///   exibir a capa;
/// * existe no máximo um arquivo por livro; ele é apagado quando a foto é
///   removida ou quando o livro sai da estante;
/// * caminhos de arquivo não são registrados em logs.
class DeviceCoverPhotoService implements CoverPhotoService {
  DeviceCoverPhotoService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PhotoResult> takePhoto(String uid, String bookId) async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const PhotoResult(PhotoOutcome.permanentlyDenied);
    }
    if (!status.isGranted) {
      return const PhotoResult(PhotoOutcome.denied);
    }
    return _pick(ImageSource.camera, uid, bookId);
  }

  /// A galeria usa o seletor de fotos do sistema (Android Photo Picker),
  /// que não exige permissão de armazenamento: o app só recebe a imagem
  /// escolhida. É a alternativa quando a câmera é negada.
  @override
  Future<PhotoResult> pickFromGallery(String uid, String bookId) =>
      _pick(ImageSource.gallery, uid, bookId);

  Future<PhotoResult> _pick(
    ImageSource source,
    String uid,
    String bookId,
  ) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 80,
      );
    } on PlatformException {
      return const PhotoResult(PhotoOutcome.unavailable);
    }
    if (file == null) return const PhotoResult(PhotoOutcome.cancelled);

    await deleteCover(uid, bookId);
    final dir = await _coversDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = '${dir.path}/${_prefix(uid, bookId)}$stamp.jpg';
    await file.saveTo(target);
    // Remove a cópia temporária criada pelo image_picker.
    try {
      await File(file.path).delete();
    } on FileSystemException {
      // arquivo temporário já removido pelo sistema
    }
    return PhotoResult(PhotoOutcome.saved, path: target);
  }

  @override
  Future<String?> existingCover(String uid, String bookId) async {
    final files = await _filesFor(uid, bookId);
    return files.isEmpty ? null : files.last.path;
  }

  @override
  Future<void> deleteCover(String uid, String bookId) async {
    for (final f in await _filesFor(uid, bookId)) {
      await f.delete();
    }
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  String _prefix(String uid, String bookId) => '${uid}_${bookId}_';

  Future<Directory> _coversDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/covers');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> _filesFor(String uid, String bookId) async {
    final dir = await _coversDir();
    final prefix = _prefix(uid, bookId);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith(prefix))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
