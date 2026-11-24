import 'package:firebase_auth/firebase_auth.dart';

/// Usuário autenticado, sem expor tipos do SDK do Firebase para as camadas de cima.
class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Contrato de autenticação usado pelo SessionViewModel.
abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}

/// Implementação com Firebase Authentication (e-mail e senha).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  AppUser? _map(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(messageForCode(e.code));
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(messageForCode(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Converte códigos do Firebase em mensagens para o usuário.
  /// Credenciais inválidas recebem a mesma mensagem para não revelar
  /// se um e-mail está ou não cadastrado.
  static String messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Já existe uma conta com este e-mail.';
      case 'weak-password':
        return 'Senha fraca: use pelo menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'operation-not-allowed':
        return 'Login por e-mail não está habilitado no Firebase.';
      default:
        return 'Não foi possível autenticar. Tente novamente.';
    }
  }
}
