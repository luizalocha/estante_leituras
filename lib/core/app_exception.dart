/// Tipos de falha reconhecidos pelo app.
///
/// Os serviços convertem exceções de SDK (HTTP, Firebase, plugins) nestes
/// tipos antes de entregá-las aos repositórios e ViewModels. Assim a View
/// nunca precisa conhecer exceções de bibliotecas externas.
enum FailureKind {
  offline,
  timeout,
  server,
  invalidData,
  permissionDenied,
  auth,
  unknown,
}

class AppException implements Exception {
  const AppException(this.kind, this.message, {this.statusCode});

  final FailureKind kind;

  /// Mensagem pronta para ser exibida ao usuário (pt-BR).
  final String message;

  /// Código HTTP, quando a falha veio de um serviço Web.
  final int? statusCode;

  /// Falhas em que faz sentido recorrer ao cache local.
  bool get isConnectivity =>
      kind == FailureKind.offline || kind == FailureKind.timeout;

  @override
  String toString() =>
      'AppException($kind${statusCode == null ? '' : ', $statusCode'}): $message';
}
