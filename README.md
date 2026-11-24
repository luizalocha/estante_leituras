# Estante de Leituras

Aplicativo Flutter (Android) para organizar leituras pessoais. A pessoa entra com
e-mail e senha, busca livros na **Open Library**, adiciona à sua estante no
**Cloud Firestore**, marca o status (quero ler, lendo, lido), dá nota, escreve
anotações e pode fotografar a capa com a **câmera** (a foto fica só no aparelho).
Sem internet, a última estante salva aparece com o aviso de dados desatualizados.

Trabalho final de Desenvolvimento Mobile II — Unilavras, 2º semestre de 2026.
Autoria: **Luiza Cardoso da Locha** — matrícula **0031653**.

## Funcionalidades x requisitos

| Requisito | Onde está |
|---|---|
| MVVM | `lib/features/*/view` → `viewmodel` → `data` (Repository/Service) |
| Estados loading/sucesso/vazio/erro | `lib/features/shelf/viewmodel/shelf_view_model.dart`, `lib/features/search/viewmodel/search_view_model.dart` |
| Serviço Web | `lib/features/search/data/open_library_service.dart` |
| Cache / offline | `lib/features/shelf/data/shelf_local_cache.dart`, `shelf_repository.dart` |
| Autenticação e sessão | `lib/features/auth/`, `lib/app.dart` (`AuthGate`) |
| CRUD no Firestore (por UID) | `lib/features/shelf/data/firestore_shelf_source.dart` |
| Regras de segurança | `firestore.rules`, testes em `firestore_rules_test/` |
| Recurso nativo (câmera) | `lib/features/cover_photo/data/cover_photo_service.dart` |
| Testes de unidade e widget | `test/` |
| Teste de integração | `integration_test/app_test.dart` |

## Ambiente

- Flutter estável (versão exata registrada no relatório: `flutter --version`)
- Android SDK 23+ (emulador ou aparelho)
- Projeto Firebase com Authentication (e-mail/senha) e Cloud Firestore

## Como reproduzir a partir de um clone limpo

```bash
git clone <URL_DO_REPOSITORIO>
cd estante_leituras
git checkout m2-final          # tag avaliada
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter run                    # com emulador/aparelho conectado
```

O arquivo `lib/firebase_options.dart` e `android/app/google-services.json`
identificam o projeto Firebase (não são segredos; a proteção dos dados é feita
pelas regras do Firestore). Para usar **outro** projeto Firebase, rode
`flutterfire configure` e publique `firestore.rules` nele.

### Teste de integração (jornada completa)

```bash
flutter test integration_test/app_test.dart -d <id-do-emulador>
```

Cria uma conta descartável `e2e_<timestamp>@teste.example.com`, adiciona, edita
e remove um livro, faz logout e apaga a conta no final.

### Testes das regras do Firestore (opcional, requer Java 11+)

```bash
npm install -g firebase-tools
cd firestore_rules_test
npm install
npm run test:emulador
```

### Release

O APK/AAB de release é assinado com uma chave própria. O arquivo
`android/key.properties` e o `.jks` **não** estão no Git (ver `.gitignore`).
Para gerar a sua própria chave, siga a seção "Release" do guia do projeto e
depois:

```bash
flutter build apk --release
flutter build appbundle --release
```

## Privacidade

- A foto da capa é guardada apenas no armazenamento privado do app, reduzida
  para no máximo 1080 px, e apagada quando a foto ou o livro são removidos.
  Ela não é enviada ao Firestore.
- O cache local é separado por usuário e apagado no logout.
- Nenhum token, senha, caminho de arquivo ou dado pessoal é escrito em log.

## Fontes e recursos externos

- Flutter e Dart — documentação oficial (docs.flutter.dev, dart.dev)
- Firebase (Authentication, Cloud Firestore, Emulator Suite) — firebase.google.com/docs
- Open Library Search API — openlibrary.org/dev/docs/api/search
- Pacotes: provider, http, shared_preferences, firebase_core, firebase_auth,
  cloud_firestore, image_picker, permission_handler, path_provider,
  integration_test, flutter_lints
- Assistente de IA (Claude, Anthropic) usado como apoio na estruturação do
  código, dos testes e da documentação; o código foi revisado, executado e
  testado pela autora.
