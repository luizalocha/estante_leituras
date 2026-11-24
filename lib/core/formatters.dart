String _two(int v) => v.toString().padLeft(2, '0');

/// Formata "dd/MM às HH:mm" sem depender do pacote intl.
String formatSavedAt(DateTime dt) {
  final local = dt.toLocal();
  return '${_two(local.day)}/${_two(local.month)} às '
      '${_two(local.hour)}:${_two(local.minute)}';
}
