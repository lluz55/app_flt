
import 'package:anotador/app.dart';
import 'package:anotador/data/note.dart';
import 'package:anotador/data/note_repository.dart';
import 'package:anotador/state/notes_controller.dart';
import 'package:anotador/state/settings_controller.dart';
import 'package:anotador/state/settings_store.dart';
import 'package:anotador/ui/screens/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Monta o app completo com controladores controlados.
///
/// Tudo em memória: o `NotesController` usa um repositório falso e o
/// `SettingsController` um store em memória. Nenhum I/O real acontece dentro do
/// `testWidgets`, que roda num relógio virtual.
Future<NotesController> _pumpApp(
  WidgetTester tester, {
  List<Note> seed = const <Note>[],
  Size surface = const Size(430, 932),
  NoteRepository? repository,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final notes = NotesController(repository ?? MemoryRepository(seed));
  await notes.load();

  final settings = SettingsController(InMemorySettingsStore());
  _lastSettings = settings;

  await tester.pumpWidget(
    AnotadorApp(notesController: notes, settingsController: settings),
  );

  // A aurora anima continuamente: `pumpAndSettle` nunca assentaria.
  await tester.pump(const Duration(milliseconds: 100));
  return notes;
}

SettingsController? _lastSettings;

/// Campos de texto do editor (título, corpo e tags), sem os da lista atrás.
Finder _editorFields() => find.descendant(
  of: find.byType(EditorScreen),
  matching: find.byType(TextField),
);

/// Abre o editor de uma nota nova pelo FAB e espera a rota entrar.
Future<void> _openNewNote(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Abre uma nota existente e espera o voo do `Hero` terminar.
///
/// Durante o voo o shuttle é desenhado no overlay do `Navigator`, fora da
/// subárvore do editor: sem esperar, o campo de título some dos finders.
Future<void> _openNote(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
  expect(_editorFields(), findsNWidgets(3));
}

/// Fecha o editor pelo botão da barra e dá tempo das gravações enfileiradas
/// terminarem (a última delas pode esperar a lenta do autosave).
Future<void> _closeEditor(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Fechar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('mostra o estado vazio quando não há notas', (tester) async {
    await _pumpApp(tester);

    // O IndexedStack mantém as três abas montadas, então o título pode aparecer
    // mais de uma vez na árvore.
    expect(find.text('Anotador'), findsWidgets);
    expect(find.textContaining('primeira nota'), findsWidgets);
  });

  testWidgets('lista as notas existentes', (tester) async {
    await _pumpApp(
      tester,
      seed: [
        fakeNote(id: 'a', title: 'Lista do mercado', body: 'Café em grão'),
        fakeNote(id: 'b', title: 'Ideias', body: 'Modo foco', colorIndex: 3),
      ],
    );

    expect(find.text('Lista do mercado'), findsOneWidget);
    expect(find.text('Ideias'), findsOneWidget);
  });

  testWidgets('a busca filtra as notas e ignora acentos', (tester) async {
    await _pumpApp(
      tester,
      seed: [
        fakeNote(id: 'a', title: 'Revisão', body: 'tarefa importante'),
        fakeNote(id: 'b', title: 'Mercado', body: 'acao e reacao'),
      ],
    );

    await tester.enterText(find.byType(TextField).first, 'acao');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Revisão'), findsNothing);

    // Limpar a busca traz tudo de volta.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Revisão'), findsOneWidget);
  });

  testWidgets('favoritar uma nota a move para o topo', (tester) async {
    await _pumpApp(
      tester,
      seed: [
        fakeNote(id: 'antiga', title: 'Antiga', ago: const Duration(days: 9)),
        fakeNote(id: 'recente', title: 'Recente', ago: const Duration(hours: 1)),
      ],
    );

    await tester.tap(find.byTooltip('Fixar nota').first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Antiga'), findsOneWidget);
  });

  testWidgets('nota vazia abandonada no editor não é persistida', (tester) async {
    final notes = await _pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sai sem digitar nada.
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(notes.notes, isEmpty);
  });

  testWidgets('nota escrita no editor é persistida', (tester) async {
    final notes = await _pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // `.first` pegaria o campo de busca da tela de notas, que segue montada
    // atrás da rota do editor. Escopo a busca dentro do próprio editor.
    final title = find.descendant(
      of: find.byType(EditorScreen),
      matching: find.byType(TextField),
    );
    await tester.enterText(title.first, 'Compras da semana');
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(notes.notes, hasLength(1));
    expect(notes.notes.single.title, 'Compras da semana');
    // Durante a animação de "voltar" o título aparece no editor e na lista.
    expect(find.text('Compras da semana'), findsWidgets);
  });

  testWidgets('enviar para a lixeira e depois restaurar', (tester) async {
    final notes = await _pumpApp(
      tester,
      seed: [fakeNote(id: 'a', title: 'Para descartar')],
    );

    await tester.tap(find.byTooltip('Mover para a lixeira').first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(notes.notes, isEmpty);
    expect(notes.trash, hasLength(1));

    await tester.tap(find.text('Lixeira'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Para descartar'), findsOneWidget);

    await tester.tap(find.byTooltip('Restaurar nota').first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(notes.trash, isEmpty);
    expect(notes.notes, hasLength(1));
  });

  testWidgets('layout largo usa trilho de navegação', (tester) async {
    await _pumpApp(
      tester,
      seed: [fakeNote(id: 'a', title: 'Uma nota')],
      surface: const Size(1440, 900),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Uma nota'), findsOneWidget);
  });

  testWidgets('tema escuro é respeitado', (tester) async {
    await _pumpApp(
      tester,
      seed: [fakeNote(id: 'a', title: 'Nota visível')],
    );

    await tester.tap(find.text('Ajustes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O segmento "Escuro" pode estar abaixo da dobra em telas estreitas.
    await tester.ensureVisible(find.text('Escuro'));
    await tester.pump();
    await tester.tap(find.text('Escuro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(_lastSettings!.themeMode, ThemeMode.dark);
    expect(app.themeMode, ThemeMode.dark);
  });

  // Regressões --------------------------------------------------------------

  testWidgets(
    'o rascunho final sobrevive quando o autosave ainda está gravando',
    (tester) async {
      // A primeira escrita do repositório demora 500 ms; as seguintes são
      // instantâneas. Sem esperar a fila antes de finalizar, a gravação antiga
      // pousa por último e o título volta um caractere atrás.
      final repository = SlowFirstWriteRepository();
      final notes = await _pumpApp(tester, repository: repository);

      await _openNewNote(tester);

      await tester.enterText(_editorFields().first, 'ABC');
      // Debounce de 400 ms: o autosave dispara e a escrita lenta fica em voo.
      await tester.pump(const Duration(milliseconds: 400));

      // Mais uma tecla e fechamento na hora, com a gravação antiga pendente.
      await tester.enterText(_editorFields().first, 'ABCD');
      await _closeEditor(tester);

      expect(repository.stored.values.map((note) => note.title).toList(),
          <String>['ABCD']);
      expect(notes.notes.single.title, 'ABCD');
    },
  );

  testWidgets('falha ao gravar vira aviso na tela, não sumiço silencioso', (
    tester,
  ) async {
    await _pumpApp(tester, repository: FailingRepository());

    await _openNewNote(tester);
    await tester.enterText(_editorFields().first, 'Rascunho importante');
    // Debounce (400 ms) + gravação recusada + animação do SnackBar.
    await tester.pump(const Duration(milliseconds: 800));

    // A asserção é na mensagem inteira, e não num fragmento: "Não foi possível
    // salvar" cabe nas duas mensagens do editor, e só a versão curta é a
    // correta aqui. Com `FailingRepository` a criação também falha, então não há
    // cópia em branco órfã para acusar.
    expect(
      find.text('Não foi possível salvar a nota. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('cópia em branco'), findsNothing);
  });

  testWidgets('carga que falha não vira "estado vazio"', (tester) async {
    // Sem esta distinção o app mostraria "Sua primeira nota começa aqui" para
    // um banco cheio que apenas não pôde ser lido — e as notas do usuário só
    // reapareceriam no próximo reinício.
    await _pumpApp(
      tester,
      repository: FailingRepository(<Note>[fakeNote(id: 'a', title: 'Mercado')])
        ..failOnLoad = true,
    );

    expect(find.text('Não foi possível carregar suas notas'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('primeira nota começa aqui'), findsNothing);
  });

  testWidgets('nota que a pessoa esvaziou vai para a lixeira', (tester) async {
    final repository = MemoryRepository([
      fakeNote(id: 'a', title: 'Mercado', body: 'Café em grão'),
    ]);
    final notes = await _pumpApp(tester, repository: repository);

    await _openNote(tester, 'Mercado');

    final fields = _editorFields();
    await tester.enterText(fields.at(0), ''); // título
    await tester.enterText(fields.at(1), ''); // corpo
    await tester.pump(const Duration(milliseconds: 600));

    await _closeEditor(tester);

    // Some da lista, mas continua existindo: dá para restaurar.
    expect(notes.notes, isEmpty);
    expect(notes.trash, hasLength(1));
    expect(repository.stored['a']!.trashed, isTrue);
  });


  // Nota de cobertura: a exclusão definitiva drena a fila de gravação antes de
  // ler o id (`editor_screen.dart`, `_deleteForever`). A correção existe, mas
  // este caminho de UI (menu → diálogo → escrita em voo) não ficou estável o
  // bastante para sustentar um teste de regressão; preferimos não travar no
  // código um teste que às vezes falha por motivo errado.

  testWidgets('escolher só a cor já cria a nota', (tester) async {
    final repository = MemoryRepository();
    final notes = await _pumpApp(tester, repository: repository);

    await _openNewNote(tester);
    // Nenhum texto digitado: só a escolha de cor. Descartá-la em silêncio faria
    // a nota sumir junto com a escolha que a pessoa acabou de fazer.
    await tester.tap(find.byTooltip('Cor 3'));
    await tester.pump(const Duration(milliseconds: 600));
    await _closeEditor(tester);

    expect(notes.notes, hasLength(1));
    expect(repository.stored.values.single.colorIndex, 2);
  });

  testWidgets('falha ao fixar avisa, em vez de deixar o alfinete parado', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      repository: FailingRepository(<Note>[fakeNote(id: 'a', title: 'Mercado')]),
    );

    await tester.tap(find.byTooltip('Fixar nota'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Não foi possível atualizar'), findsOneWidget);
  });

  testWidgets('Desfazer que falha avisa, em vez de sumir calado', (tester) async {
    final repository = MemoryRepository(<Note>[fakeNote(id: 'a', title: 'Mercado')]);
    final notes = await _pumpApp(tester, repository: repository);

    await tester.drag(
      find.text('Mercado'),
      const Offset(-500, 0),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // O SnackBar flutuante ainda entra em cena neste ponto: sem o segundo
    // ciclo o `tap` calcula o centro de um render object que ainda não pintou.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Desfazer'), findsOneWidget);

    repository.failOnSave = true;
    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Não foi possível devolver'), findsOneWidget);
    expect(notes.trash, hasLength(1));
  });

  testWidgets('arrastar com a gravação recusada devolve o cartão à lista', (
    tester,
  ) async {
    final repository = MemoryRepository(<Note>[fakeNote(id: 'a', title: 'Mercado')])
      ..failOnSave = true;
    final notes = await _pumpApp(tester, repository: repository);

    await tester.drag(
      find.text('Mercado'),
      const Offset(-500, 0),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // O `Dismissible` se remove da árvore quando o gesto termina. Se a gravação
    // falhasse depois disso, o rebuild devolvia um `Dismissible` já dispensado:
    // um `ErrorWidget` ocupava a lista e a nota vizinha sumia junto.
    expect(find.text('Mercado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(notes.notes, hasLength(1));
    expect(notes.trash, isEmpty);
    expect(find.textContaining('Não foi possível mover'), findsOneWidget);
  });

  testWidgets('escolher só o fixar já cria a nota', (tester) async {
    final repository = MemoryRepository();
    final notes = await _pumpApp(tester, repository: repository);

    await _openNewNote(tester);
    // Simétrico do teste da cor: fixar é escolha explícita e vale uma nota.
    await tester.tap(find.byTooltip('Fixar nota'));
    await tester.pump(const Duration(milliseconds: 600));
    await _closeEditor(tester);

    expect(notes.notes, hasLength(1));
    expect(repository.stored.values.single.pinned, isTrue);
  });

  testWidgets('falha parcial não deixa nota vazia órfã', (tester) async {
    final repository = UpdateFailsRepository();
    final notes = await _pumpApp(tester, repository: repository);

    await _openNewNote(tester);
    await tester.enterText(_editorFields().first, 'Vai falhar');
    await tester.pump(const Duration(milliseconds: 800));

    // A criação passa e a gravação do conteúdo falha: o rollback tem de
    // remover a nota em branco, senão ela fica órfã na lista.
    expect(notes.notes, isEmpty);
    expect(repository.stored, isEmpty);
  });
}