// Dublês compartilhados pelos testes de widget e pelas capturas de tela.
//
// Ficam num arquivo só porque `widget_test.dart` e `golden_capture_test.dart`
// precisam exatamente dos mesmos dublês — duas cópias divergem sem ninguém
// perceber, e é aí que os testes começam a mentir.

import 'package:anotador/data/note.dart';
import 'package:anotador/data/note_repository.dart';

/// Data de referência das notas de teste.
///
/// Fixa para que os rótulos de data ("Editada 12 de mar de 2026") não mudem
/// conforme o dia em que a suíte roda.
final DateTime fakeNow = DateTime(2026, 3, 12, 14, 32);

/// Nota de teste.
///
/// As datas defaultam para [fakeNow], que é fixa: é isso que impede os rótulos
/// de data de mudarem conforme o dia em que a suíte roda. [ago] é o atalho para
/// "quanto tempo atrás"; [createdAt] e [updatedAt] servem para quando o teste
/// precisa de um instante absoluto e exato — ordenações, por exemplo.
Note fakeNote({
  required String id,
  String title = '',
  String body = '',
  List<String> tags = const <String>[],
  bool pinned = false,
  bool trashed = false,
  int colorIndex = 0,
  Duration ago = Duration.zero,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Note(
    id: id,
    title: title,
    body: body,
    tags: tags,
    pinned: pinned,
    trashed: trashed,
    colorIndex: colorIndex,
    createdAt: createdAt ?? fakeNow.subtract(ago),
    updatedAt: updatedAt ?? fakeNow.subtract(ago),
  );
}

/// Repositório em memória: nada toca em disco durante os testes.
///
/// As flags [failOnSave] e [failOnLoad] ligam o caminho de erro sem precisar de
/// uma classe nova para cada cenário de falha.
class MemoryRepository implements NoteRepository {
  MemoryRepository([List<Note> seed = const <Note>[]])
    : stored = {for (final note in seed) note.id: note};

  final Map<String, Note> stored;

  /// Faz toda gravação lançar, como disco cheio ou box corrompida.
  bool failOnSave = false;

  /// Faz a carga inicial lançar.
  bool failOnLoad = false;

  @override
  Future<List<Note>> loadAll() async {
    if (failOnLoad) throw StateError('falha ao carregar');
    return stored.values.toList();
  }

  @override
  Future<void> save(Note note) async {
    if (failOnSave) throw StateError('falha ao salvar');
    stored[note.id] = note;
  }

  @override
  Future<void> delete(String id) async => stored.remove(id);

  @override
  Future<void> emptyTrash() async {
    stored.removeWhere((_, Note note) => note.trashed);
  }
}

/// Repositório de **latência assimétrica**: a primeira gravação demora muito
/// mais que as seguintes.
///
/// Reproduz o aparelho real — disco lento na primeira vez, cache depois — e é o
/// que expõe escritas fora de ordem: um autosave ainda no ar que aterrissa
/// depois do fechamento e sobrescreve o rascunho final.
class SlowFirstWriteRepository extends MemoryRepository {
  SlowFirstWriteRepository([super.seed]);

  static const Duration _firstWriteDelay = Duration(milliseconds: 500);

  int _writes = 0;

  @override
  Future<void> save(Note note) async {
    _writes++;
    if (_writes == 1) await Future<void>.delayed(_firstWriteDelay);
    await super.save(note);
  }
}

/// Repositório que recusa toda escrita, para exercitar o caminho de erro da UI.
class FailingRepository extends MemoryRepository {
  FailingRepository([super.seed]);

  @override
  Future<void> save(Note note) async {
    throw StateError('sem espaço no armazenamento');
  }

  @override
  Future<void> delete(String id) async {
    throw StateError('sem espaço no armazenamento');
  }
}

/// Falha **só** na atualização, deixando a criação passar.
///
/// Reproduz a falha parcial que deixaria uma nota vazia órfã na lista: a nota
/// é criada no repositório, a gravação do conteúdo falha e o editor continua
/// sem `_base`, então o próximo autosave cria uma segunda nota.
class UpdateFailsRepository extends MemoryRepository {
  UpdateFailsRepository([super.seed]);

  @override
  Future<void> save(Note note) async {
    if (note.title.trim().isEmpty && note.body.trim().isEmpty) {
      await super.save(note); // criação (nota em branco) passa
      return;
    }
    throw StateError('falha ao gravar o conteúdo');
  }

  @override
  Future<void> delete(String id) async {
    await super.delete(id); // o rollback precisa conseguir limpar
  }
}