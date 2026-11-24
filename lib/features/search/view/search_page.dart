import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../shelf/view/book_cover.dart';
import '../../shelf/viewmodel/shelf_view_model.dart';
import '../data/book_search_repository.dart';
import '../data/book_search_result.dart';
import '../viewmodel/search_view_model.dart';

/// Busca de livros no serviço Web e inclusão na estante.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  /// Cria a página já com o seu ViewModel.
  static Widget withViewModel(BookSearchRepository repository) {
    return ChangeNotifierProvider(
      create: (_) => SearchViewModel(repository),
      child: const SearchPage(),
    );
  }

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    context.read<SearchViewModel>().search(_controller.text);
  }

  Future<void> _add(BookSearchResult result) async {
    final shelf = context.read<ShelfViewModel>();
    await shelf.addFromSearch(result);
    // A mensagem de sucesso/erro é exibida pela estante (snackbar global).
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final shelf = context.watch<ShelfViewModel>();
    final state = vm.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar livros')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('search_field'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Título ou autor',
                border: const OutlineInputBorder(),
                errorText: vm.validationMessage,
                suffixIcon: IconButton(
                  key: const Key('search_submit'),
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (state) {
              SearchIdle() => const _Message(
                  icon: Icons.travel_explore,
                  text: 'Pesquise na Open Library pelo título ou autor.',
                ),
              SearchLoading() => const Center(
                  child: CircularProgressIndicator(key: Key('search_loading')),
                ),
              SearchEmpty(:final query) => _Message(
                  icon: Icons.search_off,
                  text: 'Nenhum livro encontrado para "$query".',
                ),
              SearchError(:final message) => _Message(
                  icon: Icons.wifi_off,
                  text: message,
                  action: FilledButton.icon(
                    key: const Key('search_retry'),
                    onPressed: vm.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              SearchSuccess(:final results) => ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final r = results[i];
                    final added = shelf.containsWork(r.workKey);
                    return ListTile(
                      leading:
                          BookCover(url: r.coverUrl, width: 40, height: 60),
                      title: Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        r.year == null ? r.author : '${r.author} · ${r.year}',
                      ),
                      trailing: added
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton(
                              key: Key('add_${r.workKey}'),
                              tooltip: 'Adicionar à estante',
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: shelf.canWrite ? () => _add(r) : null,
                            ),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
