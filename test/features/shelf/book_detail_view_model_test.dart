import 'package:estante_leituras/features/cover_photo/data/cover_photo_service.dart';
import 'package:estante_leituras/features/shelf/data/shelf_book.dart';
import 'package:estante_leituras/features/shelf/viewmodel/book_detail_view_model.dart';
import 'package:estante_leituras/features/shelf/viewmodel/shelf_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeShelfRemoteSource remote;
  late FakeCoverPhotoService photos;
  late ShelfViewModel shelf;
  late BookDetailViewModel vm;

  setUp(() async {
    remote = FakeShelfRemoteSource([fakeBook('1')]);
    photos = FakeCoverPhotoService();
    shelf = ShelfViewModel(
      repository: buildRepository(remote: remote, covers: photos),
      uid: 'uid-a',
    );
    await shelf.load();
    vm = BookDetailViewModel(
        book: shelf.books.first, shelf: shelf, photos: photos);
  });

  group('foto da capa (recurso nativo)', () {
    test('foto autorizada é associada ao livro', () async {
      await vm.takePhoto();

      expect(vm.photoPath, '/fake/capa.jpg');
      expect(vm.photoMessage, contains('somente neste aparelho'));
    });

    test('permissão negada oferece a galeria como alternativa', () async {
      photos.nextCameraResult = const PhotoResult(PhotoOutcome.denied);

      await vm.takePhoto();

      expect(vm.photoPath, isNull);
      expect(vm.photoMessage, contains('galeria'));
      expect(vm.showSettingsShortcut, isFalse);

      await vm.pickFromGallery();
      expect(vm.photoPath, '/fake/galeria.jpg');
    });

    test('negação permanente mostra atalho para Configurações', () async {
      photos.nextCameraResult =
          const PhotoResult(PhotoOutcome.permanentlyDenied);

      await vm.takePhoto();
      await vm.openSettings();

      expect(vm.showSettingsShortcut, isTrue);
      expect(photos.settingsOpened, 1);
    });

    test('cancelar não cria foto', () async {
      photos.nextCameraResult = const PhotoResult(PhotoOutcome.cancelled);

      await vm.takePhoto();

      expect(vm.photoPath, isNull);
    });

    test('remover foto apaga o arquivo local', () async {
      await vm.takePhoto();
      await vm.removePhoto();

      expect(vm.photoPath, isNull);
      expect(photos.deleted, ['uid-a_1']);
    });
  });

  test('salvar envia status, nota e anotação ao servidor', () async {
    vm
      ..setStatus(ReadingStatus.read)
      ..setRating(4)
      ..setNotes('  Releitura ótima  ');

    final ok = await vm.save();

    expect(ok, isTrue);
    final salvo = remote.books.single;
    expect(salvo.status, ReadingStatus.read);
    expect(salvo.rating, 4);
    expect(salvo.notes, 'Releitura ótima');
  });

  test('tocar na mesma estrela remove a nota', () {
    vm.setRating(3);
    vm.setRating(3);
    expect(vm.rating, 0);
  });
}
