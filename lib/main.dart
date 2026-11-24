import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await bootstrap();
  runApp(EstanteApp(deps: deps));
}
