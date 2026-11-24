import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app_dependencies.dart';
import '../../../core/formatters.dart';
import '../../auth/viewmodel/session_view_model.dart';
import '../../search/view/search_page.dart';
import '../data/shelf_book.dart';
import '../data/shelf_repository.dart';
import '../viewmodel/shelf_view_model.dart';
import 'book_cover.dart';
import 'book_detail_page.dart';

/// Tela principal (protegida): a estante do usuário autenticado.
class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  ShelfViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<ShelfViewModel>();
    if (!identical(vm, _vm)) {
      _vm?.removeListener(_showMessage);
      _vm = vm..addListener(_showMessage);
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_showMessage);
    super.dispose();
  }

  void _showMessage() {
    final message = _vm?.takeMessage();
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSearch() {
    final shelf = context.read<ShelfViewModel>();
    final deps = context.read<AppDependencies>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: shelf,
        child: SearchPage.withViewModel(deps.searchRepository),
      ),
    ));
  }

  void _openDetail(ShelfBook book) {
    final shelf = context.read<ShelfViewModel>();
    final deps = context.read<AppDependencies>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: shelf,
        child: BookDetailPage.withViewModel(
          book: book,
          shelf: shelf,
          photos: deps.coverPhotos,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShelfViewModel>();
    final state = vm.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha estante'),
        actions: [
          IconButton(
            key: const Key('refresh_button'),
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: state is ShelfLoading ? null : vm.load,
          ),
          IconButton(
            key: const Key('logout_button'),
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<SessionViewModel>().signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('open_search'),
        onPressed: vm.canWrite ? _openSearch : null,
        backgroundColor: vm.canWrite
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        icon: const Icon(Icons.search),
        label: const Text('Buscar livros'),
      ),
      body: switch (state) {
        ShelfLoading() => const Center(
            child: CircularProgressIndicator(key: Key('shelf_loading')),
          ),
        ShelfError(:final message) => _ErrorView(
            message: message,
            onRetry: vm.retry,
          ),
        ShelfEmpty(:final origin, :final savedAt) => Column(
            children: [
              if (origin == DataOrigin.cache) _OfflineBanner(savedAt: savedAt),
              const Expanded(child: _EmptyView()),
            ],
          ),
        ShelfLoaded(:final books, :final origin, :final savedAt) => Column(
            children: [
              if (origin == DataOrigin.cache) _OfflineBanner(savedAt: savedAt),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vm.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _BookTile(
                      book: books[i],
                      onTap: () => _openDetail(books[i]),
                    ),
                  ),
                ),
              ),
            ],
          ),
      },
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap});

  final ShelfBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('book_${book.id}'),
      onTap: onTap,
      leading: BookCover(url: book.coverUrl, width: 40, height: 60),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${book.author} · ${book.status.label}'),
      trailing: book.rating > 0 ? Text('★ ${book.rating}') : null,
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.savedAt});

  final DateTime savedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('offline_banner'),
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sem conexão — exibindo dados salvos em ${formatSavedAt(savedAt)}. '
              'Somente leitura.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'Sua estante está vazia',
              key: Key('shelf_empty'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Toque em "Buscar livros" para adicionar o primeiro.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              key: const Key('shelf_error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
