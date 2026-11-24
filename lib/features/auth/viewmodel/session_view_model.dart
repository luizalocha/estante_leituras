import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';

enum SessionStatus { unknown, signedOut, signedIn }

/// Controla cadastro, login, sessão e logout.
///
/// A sessão é restaurada automaticamente: o Firebase mantém o usuário
/// conectado entre execuções e [AuthService.authStateChanges] emite o
/// usuário atual assim que o app abre.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._auth, {Future<void> Function(String uid)? onSignOut})
      : _onSignOut = onSignOut {
    _subscription = _auth.authStateChanges().listen(_onUserChanged);
  }

  final AuthService _auth;
  final Future<void> Function(String uid)? _onSignOut;
  StreamSubscription<AppUser?>? _subscription;
  bool _disposed = false;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  String? _errorMessage;

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  static String? validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Informe o e-mail.';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return 'E-mail inválido.';
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Informe a senha.';
    if (value.length < 6) return 'A senha precisa de pelo menos 6 caracteres.';
    return null;
  }

  void _onUserChanged(AppUser? user) {
    _user = user;
    _status = user == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    _notify();
  }

  Future<void> signIn(String email, String password) =>
      _run(email, password, () => _auth.signIn(email.trim(), password));

  Future<void> signUp(String email, String password) =>
      _run(email, password, () => _auth.signUp(email.trim(), password));

  Future<void> _run(
    String email,
    String password,
    Future<void> Function() action,
  ) async {
    final validation = validateEmail(email) ?? validatePassword(password);
    if (validation != null) {
      _errorMessage = validation;
      _notify();
      return;
    }
    _busy = true;
    _errorMessage = null;
    _notify();
    try {
      await action();
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } on Exception {
      _errorMessage = 'Não foi possível concluir. Tente novamente.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Encerra a sessão e remove os dados locais (cache) da conta.
  Future<void> signOut() async {
    final uid = _user?.uid;
    _busy = true;
    _notify();
    try {
      if (uid != null) await _onSignOut?.call(uid);
      await _auth.signOut();
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
