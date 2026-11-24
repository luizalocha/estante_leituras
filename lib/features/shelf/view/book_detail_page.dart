import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../cover_photo/data/cover_photo_service.dart';
import '../data/shelf_book.dart';
import '../viewmodel/book_detail_view_model.dart';
import '../viewmodel/shelf_view_model.dart';
import 'book_cover.dart';

/// Detalhes do livro: editar status/nota/anotação, foto da capa e remover.
class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key});

  static Widget withViewModel({
    required ShelfBook book,
    required ShelfViewModel shelf,
    required CoverPhotoService photos,
  }) {
    return ChangeNotifierProvider(
      create: (_) =>
          BookDetailViewModel(book: book, shelf: shelf, photos: photos)..init(),
      child: const BookDetailPage(),
    );
  }

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(
      text: context.read<BookDetailViewModel>().notes,
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await context.read<BookDetailViewModel>().save();
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover livro?'),
        content: const Text(
          'O livro sai da sua estante e a foto da capa salva neste aparelho '
          'também é apagada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm_delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<BookDetailViewModel>().delete();
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookDetailViewModel>();
    // Observa a estante para refletir "salvando" e modo offline.
    context.watch<ShelfViewModel>();
    final book = vm.book;
    final theme = Theme.of(context);
    final editable = vm.canEdit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes'),
        actions: [
          IconButton(
            key: const Key('delete_book'),
            tooltip: 'Remover da estante',
            icon: const Icon(Icons.delete_outline),
            onPressed: editable ? _delete : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                localPath: vm.photoPath,
                url: book.coverUrl,
                width: 96,
                height: 144,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(book.author),
                    if (book.year != null) Text('Publicado em ${book.year}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PhotoSection(vm: vm),
          const Divider(height: 32),
          if (!editable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Sem conexão: edição desativada até a estante ser atualizada.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          Text('Status', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ReadingStatus>(
            segments: [
              for (final s in ReadingStatus.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {vm.status},
            onSelectionChanged:
                editable ? (selection) => vm.setStatus(selection.first) : null,
          ),
          const SizedBox(height: 16),
          Text('Nota', style: theme.textTheme.titleMedium),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('rating_$i'),
                  tooltip: '$i estrela${i > 1 ? 's' : ''}',
                  onPressed: editable ? () => vm.setRating(i) : null,
                  icon: Icon(
                    i <= vm.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('notes_field'),
            controller: _notes,
            enabled: editable,
            maxLines: 4,
            maxLength: ShelfBook.maxNotes,
            onChanged: vm.setNotes,
            decoration: const InputDecoration(
              labelText: 'Anotações',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('save_book'),
            onPressed: editable ? _save : null,
            icon: vm.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Salvar alterações'),
          ),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.vm});

  final BookDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto da capa', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Opcional. A foto fica guardada só neste aparelho e não é enviada '
          'para a nuvem.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('photo_camera'),
              onPressed: vm.photoBusy ? null : vm.takePhoto,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Câmera'),
            ),
            OutlinedButton.icon(
              key: const Key('photo_gallery'),
              onPressed: vm.photoBusy ? null : vm.pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Galeria'),
            ),
            if (vm.photoPath != null)
              TextButton.icon(
                key: const Key('photo_remove'),
                onPressed: vm.photoBusy ? null : vm.removePhoto,
                icon: const Icon(Icons.hide_image_outlined),
                label: const Text('Remover foto'),
              ),
          ],
        ),
        if (vm.photoMessage != null) ...[
          const SizedBox(height: 8),
          Text(vm.photoMessage!, key: const Key('photo_message')),
        ],
        if (vm.showSettingsShortcut)
          TextButton(
            key: const Key('open_settings'),
            onPressed: vm.openSettings,
            child: const Text('Abrir Configurações do app'),
          ),
      ],
    );
  }
}
