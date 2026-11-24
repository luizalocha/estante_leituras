import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_dependencies.dart';
import 'features/auth/view/login_page.dart';
import 'features/auth/viewmodel/session_view_model.dart';
import 'features/shelf/view/shelf_page.dart';
import 'features/shelf/viewmodel/shelf_view_model.dart';

class EstanteApp extends StatefulWidget {
  const EstanteApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  State<EstanteApp> createState() => _EstanteAppState();
}

class _EstanteAppState extends State<EstanteApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final SessionViewModel _session;
  SessionStatus _lastStatus = SessionStatus.unknown;

  @override
  void initState() {
    super.initState();
    _session = SessionViewModel(
      widget.deps.auth,
      onSignOut: widget.deps.shelfRepository.clearLocal,
    )..addListener(_onSessionChanged);
  }

  /// Ao perder a sessão, fecha qualquer tela aberta por cima da estante:
  /// nenhuma rota protegida fica visível depois do logout.
  void _onSessionChanged() {
    final status = _session.status;
    if (status == SessionStatus.signedOut &&
        _lastStatus == SessionStatus.signedIn) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    _lastStatus = status;
  }

  @override
  void dispose() {
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: widget.deps),
        ChangeNotifierProvider<SessionViewModel>.value(value: _session),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Estante de Leituras',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D4C41)),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide a tela inicial conforme a sessão (proteção de rota).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    switch (session.status) {
      case SessionStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case SessionStatus.signedOut:
        return const LoginPage();
      case SessionStatus.signedIn:
        final uid = session.user!.uid;
        final deps = context.read<AppDependencies>();
        return ChangeNotifierProvider<ShelfViewModel>(
          // Um ViewModel por conta: trocar de usuário recria o estado.
          key: ValueKey(uid),
          create: (_) =>
              ShelfViewModel(repository: deps.shelfRepository, uid: uid)
                ..load(),
          child: const ShelfPage(),
        );
    }
  }
}
