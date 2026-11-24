import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../viewmodel/session_view_model.dart';

/// Tela de login e cadastro. Não acessa o Firebase: só conversa com o
/// [SessionViewModel].
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final vm = context.read<SessionViewModel>();
    if (_createAccount) {
      vm.signUp(_email.text, _password.text);
    } else {
      vm.signIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SessionViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Estante de Leituras',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _createAccount
                          ? 'Crie sua conta'
                          : 'Entre para ver sua estante',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('login_email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => SessionViewModel.validateEmail(v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login_password'),
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha (mínimo 6 caracteres)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          SessionViewModel.validatePassword(v ?? ''),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (vm.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        vm.errorMessage!,
                        key: const Key('login_error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('login_submit'),
                      onPressed: vm.busy ? null : _submit,
                      child: vm.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_createAccount ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('login_toggle'),
                      onPressed: vm.busy
                          ? null
                          : () {
                              setState(() => _createAccount = !_createAccount);
                              vm.clearError();
                            },
                      child: Text(
                        _createAccount
                            ? 'Já tenho conta — entrar'
                            : 'Não tenho conta — criar agora',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
