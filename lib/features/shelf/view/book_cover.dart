import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Capa do livro: foto local (se houver) → capa da Open Library → ícone.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.localPath,
    this.url,
    this.width = 48,
    this.height = 72,
  });

  final String? localPath;
  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book_outlined),
    );

    Widget image;
    if (localPath != null) {
      image = Image.file(
        File(localPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else if (url != null) {
      image = Image.network(
        url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      image = placeholder;
    }

    return ClipRRect(borderRadius: BorderRadius.circular(6), child: image);
  }
}
