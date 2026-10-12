import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/note_repository.dart';
import 'state/notes_controller.dart';
import 'state/settings_controller.dart';

/// Força um tema via `--dart-define=FORCE_THEME=dark|light`.
/// Vazio (padrão) = respeita a preferência do sistema.
const String _forceTheme = String.fromEnvironment('FORCE_THEME');

/// Popula o app com notas de exemplo via `--dart-define=SEED_DEMO=true`.
/// Útil para screenshots e para demonstrar o app sem digitar nada.
const bool _seedDemo = bool.fromEnvironment('SEED_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Persistência local: Hive (puro Dart, funciona em Android, Web e Linux).
  //
  // Abrir as boxes é o único ponto do app que ainda não tem como se recuperar de
  // uma falha: box corrompida, falta de permissão ou disco indisponível
  // lançavam aqui e derrubavam o `main` antes da primeira tela. Tudo o mais já
  // devolve `bool` e mostra aviso; aqui a resposta é uma tela de erro com
  // "Tentar de novo".
  final (HiveNoteRepository? repository, SettingsController? settings) =
      await _openLocalStorage();

  if (repository == null || settings == null) {
    runApp(const _StartupFailedApp());
    return;
  }

  await _applyForcedTheme(settings);

  final notesController = NotesController(repository);
  await notesController.load();
  if (_seedDemo) {
    await _seedDemoNotes(notesController);
  }

  runApp(
    AnotadorApp(
      notesController: notesController,
      settingsController: settings,
    ),
  );
}

/// Tenta abrir as duas boxes. Devolve `null` em qualquer parte quando o
/// armazenamento local não respondeu.
Future<(HiveNoteRepository?, SettingsController?)> _openLocalStorage() async {
  try {
    final repository = await HiveNoteRepository.open();
    final settings = await SettingsController.load();
    return (repository, settings);
  } on Object {
    return (null, null);
  }
}

/// Tela mostrada quando o armazenamento local não abre.
///
/// Sem ela o app morreria em uma tela branca, sem texto e sem caminho de
/// recuperação.
class _StartupFailedApp extends StatelessWidget {
  const _StartupFailedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.sd_storage_outlined, size: 40),
                  const SizedBox(height: 20),
                  Text(
                    'Não foi possível abrir suas notas',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'O armazenamento local não respondeu. Verifique se há espaço '
                    'disponível e abra o app novamente.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _applyForcedTheme(SettingsController settings) async {
  switch (_forceTheme) {
    case 'dark':
      await settings.setThemeMode(ThemeMode.dark);
    case 'light':
      await settings.setThemeMode(ThemeMode.light);
  }
}

/// Insere um conjunto inicial de notas apenas quando o app está vazio.
Future<void> _seedDemoNotes(NotesController controller) async {
  if (controller.notes.isNotEmpty) return;

  final now = DateTime.now();

  final samples = <({
    String title,
    String body,
    List<String> tags,
    int colorIndex,
    bool pinned,
    Duration ago,
  })>[
    (
      title: 'Bem-vindo ao Anotador',
      body:
          'Seu cantinho para ideias, listas e rascunhos.\n\n'
          'Toque em uma nota para editar. Use o ícone de alfinete para manter '
          'no topo o que importa agora, e a lixeira para guardar o que ainda '
          'não quer descartar de vez.',
      tags: ['início'],
      colorIndex: 0,
      pinned: true,
      ago: const Duration(minutes: 12),
    ),
    (
      title: 'Lista do mercado',
      body: 'Café em grão\nAvelã\nLeite de aveia\nPães de forma\nManteiga',
      tags: ['pessoal', 'compras'],
      colorIndex: 2,
      pinned: false,
      ago: const Duration(hours: 3),
    ),
    (
      title: 'Ideias para o projeto',
      body:
          '• Modo foco com cronômetro\n'
          '• Sincronizar entre dispositivos\n'
          '• Etiquetas coloridas com atalhos\n'
          '• Exportar tudo em um arquivo .json',
      tags: ['trabalho', 'ideias'],
      colorIndex: 5,
      pinned: true,
      ago: const Duration(hours: 9),
    ),
    (
      title: 'Livros para ler',
      body:
          '"Dune" — Frank Herbert\n'
          '"O Programador Pragmático" — Hunt & Thomas\n'
          '"A Cor do Vento" — Patrick Rothfuss',
      tags: ['leitura'],
      colorIndex: 7,
      pinned: false,
      ago: const Duration(days: 2),
    ),
    (
      title: 'Reunião de segunda',
      body:
          'Pauta:\n'
          '1. Revisão do trimestre\n'
          '2. Cronograma de entregas\n'
          '3. Próximas contratações',
      tags: ['trabalho'],
      colorIndex: 4,
      pinned: false,
      ago: const Duration(days: 5),
    ),
    (
      title: 'Treino de hoje',
      body: 'Corrida 5 km — 26 min\nAlongamento\n5x flexão\n3x prancha',
      tags: ['saúde'],
      colorIndex: 1,
      pinned: false,
      ago: const Duration(days: 8),
    ),
  ];

  for (final sample in samples) {
    final created = (await controller.createNote()).note;
    final updated = created.copyWith(
      title: sample.title,
      body: sample.body,
      tags: sample.tags,
      colorIndex: sample.colorIndex,
      pinned: sample.pinned,
      updatedAt: now.subtract(sample.ago),
    );
    await controller.updateNote(updated);
  }
}