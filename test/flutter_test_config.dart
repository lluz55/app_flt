// Configuração comum a todos os testes.
//
// Este arquivo roda em `testExecutable`, fora do relógio virtual do
// `testWidgets`. É o único lugar onde I/O real (as fontes empacotadas) pode
// acontecer com segurança: dentro de um teste, esse `await` nunca completaria.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sem carregar as fontes, o `flutter_test` desenha texto com a fonte de
  // teste (blocos sólidos) e os ícones somem — as capturas ficam inúteis para
  // avaliar o visual. O manifesto cobre tanto a Inter quanto os ícones do
  // Material e do Cupertino.
  final String raw = await rootBundle.loadString('FontManifest.json');
  final List<dynamic> manifest = json.decode(raw) as List<dynamic>;

  // Um `FontLoader` por família: usar o nome '' registraria tudo numa família
  // só e a Inter deixaria de ser usada pelo tema.
  for (final dynamic family in manifest) {
    final Map<String, dynamic> entry = family as Map<String, dynamic>;
    final FontLoader loader = FontLoader(entry['family'] as String);
    for (final dynamic item in entry['fonts'] as List<dynamic>) {
      final String asset = (item as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await testMain();
}