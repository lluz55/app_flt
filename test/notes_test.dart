import 'package:anotador/data/note.dart';
import 'package:anotador/state/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('Note.fromJson é tolerante a dados legados', () {
    test('preenche ausências com padrões seguros', () {
      final note = Note.fromJson(<String, dynamic>{});

      expect(note.id, isNotEmpty);
      expect(note.title, isEmpty);
      expect(note.body, isEmpty);
      expect(note.tags, isEmpty);
      expect(note.pinned, isFalse);
      expect(note.trashed, isFalse);
      expect(note.colorIndex, 0);
    });

    test('aceita null onde se espera string, número ou lista', () {
      final note = Note.fromJson(<String, dynamic>{
        'id': 'n1',
        'title': null,
        'body': null,
        'tags': null,
        'pinned': null,
        'trashed': null,
        'colorIndex': null,
        'createdAt': null,
        'updatedAt': null,
      });

      expect(note.id, 'n1');
      expect(note.title, isEmpty);
      expect(note.tags, isEmpty);
      expect(note.pinned, isFalse);
      expect(note.colorIndex, 0);
    });

    test('normaliza colorIndex para 0..7 mesmo com int ou double', () {
      expect(
        Note.fromJson(<String, dynamic>{'colorIndex': 99}).colorIndex,
        Note.maxColorIndex,
      );
      expect(
        Note.fromJson(<String, dynamic>{'colorIndex': -4}).colorIndex,
        0,
      );
      expect(
        Note.fromJson(<String, dynamic>{'colorIndex': 3.9}).colorIndex,
        4,
      );
      expect(
        Note.fromJson(<String, dynamic>{'colorIndex': '2'}).colorIndex,
        2,
      );
      expect(
        Note.fromJson(<String, dynamic>{'colorIndex': 'lixo'}).colorIndex,
        0,
      );
    });

    test('lê datas ISO-8601 e ignora datas inválidas', () {
      final valida = Note.fromJson(<String, dynamic>{
        'createdAt': '2026-03-04T10:00:00.000',
        'updatedAt': '2026-03-05T11:00:00.000',
      });
      expect(valida.createdAt, DateTime(2026, 3, 4, 10));
      expect(valida.updatedAt, DateTime(2026, 3, 5, 11));

      final invalida = Note.fromJson(<String, dynamic>{
        'createdAt': 'ontem',
        'updatedAt': 1767225600000,
      });
      expect(invalida.createdAt, isNotNull);
      expect(invalida.updatedAt.millisecondsSinceEpoch, 1767225600000);
    });

    test('descarta tags vazias e tipos inesperados', () {
      final note = Note.fromJson(<String, dynamic>{
        'tags': <Object?>['  trabalho  ', '', 42, null, 'Trabalho'],
      });

      // Vazias saem, não-string vira texto e a repetida por caixa é colapsada.
      expect(note.tags, <String>['trabalho', '42']);
    });
  });

  group('Note.toJson', () {
    test('guarda datas como ISO-8601 e tags como lista de texto', () {
      final note = fakeNote(
        id: 'n1',
        title: 'Título',
        tags: const <String>['a', 'b'],
        updatedAt: DateTime(2026, 2, 3, 8, 30),
      );
      final json = note.toJson();

      expect(json['createdAt'], isA<String>());
      expect(json['updatedAt'], DateTime(2026, 2, 3, 8, 30).toIso8601String());
      expect(json['tags'], <String>['a', 'b']);
      expect(Note.fromJson(json).title, 'Título');
    });
  });

  group('displayTitle e isEmpty', () {
    test('usa o título, depois a primeira linha útil, depois o fallback', () {
      expect(
        fakeNote(id: 'a', title: '  Título  ', body: 'corpo').displayTitle,
        'Título',
      );
      expect(
        fakeNote(id: 'b', title: '   ', body: '\n\nprimeira linha\nsegunda')
            .displayTitle,
        'primeira linha',
      );
      expect(
        fakeNote(id: 'c', title: '', body: '   \n  ').displayTitle,
        'Sem título',
      );
      expect(fakeNote(id: 'd').isEmpty, isTrue);
      expect(fakeNote(id: 'e', title: 'x').isEmpty, isFalse);
    });
  });

  group('preview', () {
    test('quebras viram separador e espaços das pontas são aparados', () {
      final note = fakeNote(id: 'a', body: 'linha um\n\n   linha   dois\t');
      // A prévia usa " · " entre linhas de propósito (uma lista não pode
      // parecer um item só); só as pontas de cada linha são aparadas.
      expect(note.preview, 'linha um · linha   dois');
    });

    test('corpo vazio devolve string vazia, sem lançar', () {
      expect(fakeNote(id: 'a').preview, isEmpty);
      expect(fakeNote(id: 'b', body: '   \n  ').preview, isEmpty);
    });

    test('trunca em ~160 caracteres com reticências', () {
      final note = fakeNote(id: 'a', body: 'palavra ' * 100);
      final preview = note.preview;

      expect(preview.length, lessThanOrEqualTo(Note.previewMaxLength + 1));
      expect(preview, endsWith('…'));
    });

    test('texto curto volta intacto', () {
      expect(fakeNote(id: 'a', body: 'curto').preview, 'curto');
    });
  });

  group('matches ignora caixa e acentos', () {
    test('ação casa com acao nos dois sentidos', () {
      final note = fakeNote(id: 'a', body: 'Ação rápida');

      expect(note.matches('acao'), isTrue);
      expect(note.matches('AÇÃO'), isTrue);
      expect(fakeNote(id: 'b', body: 'acao').matches('ação'), isTrue);
    });

    test('Ç casa com c, inclusive em maiúsculas', () {
      final nota = fakeNote(id: 'a', body: 'ÇEVİÇE');
      expect(nota.matches('c'), isTrue);
      expect(nota.matches('ç'), isTrue);
      expect(fakeNote(id: 'b', body: 'cevice').matches('ÇEVİÇE'), isTrue);
    });

    test('compara título, corpo e tags', () {
      final note = fakeNote(
        id: 'a',
        title: 'Compras',
        body: 'Leite e pão',
        tags: const <String>['Mercado'],
      );

      expect(note.matches('compras'), isTrue);
      expect(note.matches('leite'), isTrue);
      expect(note.matches('mercado'), isTrue);
      expect(note.matches('inexistente'), isFalse);
    });

    test('consulta vazia ou só com espaços casa com tudo', () {
      final note = fakeNote(id: 'a', body: 'qualquer coisa');
      expect(note.matches(''), isTrue);
      expect(note.matches('   '), isTrue);
      expect(fakeNote(id: 'b').matches(' '), isTrue);
    });

    test('texto decomposto (NFD) também casa', () {
      // "ação" com a marca combinante explícita, em vez do caractere pronto.
      final note = fakeNote(id: 'a', body: 'aça\u0308o');
      expect(note.matches('acao'), isTrue);
    });
  });

  group('wordCount', () {
    test('conta palavras e devolve zero para corpo vazio', () {
      expect(fakeNote(id: 'a', body: 'uma duas três').wordCount, 3);
      expect(fakeNote(id: 'b', body: '   \n  ').wordCount, 0);
    });
  });

  group('NotesController', () {
    test('ordena fixadas primeiro e, depois, por updatedAt decrescente', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[
          fakeNote(id: 'antiga', title: 'antiga', updatedAt: DateTime(2026, 1, 1)),
          fakeNote(
            id: 'fixada-antiga',
            title: 'fixada antiga',
            pinned: true,
            updatedAt: DateTime(2026, 1, 2),
          ),
          fakeNote(id: 'nova', title: 'nova', updatedAt: DateTime(2026, 3, 3)),
          fakeNote(
            id: 'fixada-nova',
            title: 'fixada nova',
            pinned: true,
            updatedAt: DateTime(2026, 4, 4),
          ),
        ]),
      );
      await controller.load();

      expect(
        controller.notes.map((note) => note.id).toList(),
        <String>['fixada-nova', 'fixada-antiga', 'nova', 'antiga'],
      );
    });

    test('não altera a lista de origem ao ordenar', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[
          fakeNote(id: 'a', updatedAt: DateTime(2026, 1, 1)),
          fakeNote(id: 'b', updatedAt: DateTime(2026, 2, 1)),
        ]),
      );
      await controller.load();

      final primeiro = controller.notes;
      final segundo = controller.notes;
      expect(primeiro, isNot(same(segundo)));
      expect(primeiro.map((note) => note.id).toList(),
          segundo.map((note) => note.id).toList());
    });

    test('filtra por tags com semântica AND', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[
          fakeNote(id: 'ambos', tags: const <String>['trabalho', 'urgente']),
          fakeNote(id: 'um', tags: const <String>['trabalho']),
          fakeNote(id: 'nenhum', tags: const <String>['pessoal']),
        ]),
      );
      await controller.load();

      controller.toggleTag('trabalho');
      expect(controller.notes.map((n) => n.id), <String>['ambos', 'um']);
      expect(controller.activeTags, <String>['trabalho']);
      expect(controller.isFiltering, isTrue);

      controller.toggleTag('urgente');
      expect(controller.notes.map((n) => n.id), <String>['ambos']);

      controller.clearFilters();
      expect(controller.isFiltering, isFalse);
      expect(controller.notes.length, 3);
    });

    test('combina tag ativa com a busca textual', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[
          fakeNote(id: 'a', title: 'Relatório mensal', tags: const <String>['trabalho']),
          fakeNote(id: 'b', title: 'Relatório anual', tags: const <String>['trabalho']),
          fakeNote(id: 'c', title: 'Relatório pessoal'),
        ]),
      );
      await controller.load();

      controller.toggleTag('trabalho');
      controller.setQuery('mensal');
      expect(controller.notes.map((n) => n.id), <String>['a']);
    });

    test('exclui a lixeira de notes e a lista em trash', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[
          fakeNote(id: 'ativa', title: 'ativa'),
          fakeNote(
            id: 'lixo',
            title: 'lixo',
            trashed: true,
            updatedAt: DateTime(2026, 5, 5),
          ),
        ]),
      );
      await controller.load();

      expect(controller.notes.map((n) => n.id), <String>['ativa']);
      expect(controller.trash.map((n) => n.id), <String>['lixo']);
      expect(controller.activeCount, 1);
      expect(controller.allTags, isEmpty);
    });

    test('allTags remove vazios e duplicatas por caixa/espaço', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[
          fakeNote(
            id: 'a',
            tags: const <String>[' Trabalho ', 'URGENTE', '   '],
          ),
          fakeNote(id: 'b', tags: const <String>['trabalho', 'Casa']),
          fakeNote(id: 'c', tags: const <String>['lixo'], trashed: true),
        ]),
      );
      await controller.load();

      expect(controller.allTags, <String>['Casa', 'Trabalho', 'URGENTE']);
    });

    test('toggleTrash, restore e emptyTrash refletem no repositório', () async {
      final repo = MemoryRepository(<Note>[
        fakeNote(id: 'a'),
        fakeNote(id: 'b', trashed: true),
      ]);
      final controller = NotesController(repo);
      await controller.load();

      await controller.toggleTrash('a');
      expect(repo.stored['a']!.trashed, isTrue);
      expect(controller.notes, isEmpty);

      await controller.restore('a');
      expect(repo.stored['a']!.trashed, isFalse);

      await controller.emptyTrash();
      expect(repo.stored.containsKey('b'), isFalse);
      expect(controller.trash, isEmpty);
    });

    test('deleteForever remove da memória e do repositório', () async {
      final repo = MemoryRepository(<Note>[fakeNote(id: 'a')]);
      final controller = NotesController(repo);
      await controller.load();

      await controller.deleteForever('a');
      expect(repo.stored, isEmpty);
      expect(controller.notes, isEmpty);
    });

    test('createNote persiste e escolhe cor distinta das recentes', () async {
      final repo = MemoryRepository(<Note>[
        for (var i = 0; i < 3; i++)
          fakeNote(
            id: 'n$i',
            colorIndex: 0,
            updatedAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
          ),
      ]);
      final controller = NotesController(repo);
      await controller.load();

      final (:note, :persisted) = await controller.createNote();
      expect(repo.stored.containsKey(note.id), isTrue);
      expect(persisted, isTrue);
      expect(controller.notes.first.id, note.id);
      expect(note.colorIndex, 1);
      expect(note.title, isEmpty);
    });

    test('createNote devolve persisted=false quando nada chegou ao disco', () async {
      // O editor usa este `bool` para não anunciar uma "cópia em branco órfã"
      // que nunca foi gravada.
      final repo = MemoryRepository()..failOnSave = true;
      final controller = NotesController(repo);
      await controller.load();

      final (:note, :persisted) = await controller.createNote();

      expect(persisted, isFalse);
      expect(repo.stored.containsKey(note.id), isFalse);
      expect(controller.notes, isEmpty);
    });

    test('updateNote e togglePin persistem e notificam', () async {
      final repo = MemoryRepository(<Note>[fakeNote(id: 'a')]);
      final controller = NotesController(repo);
      await controller.load();

      var notificacoes = 0;
      controller.addListener(() => notificacoes++);

      await controller.updateNote(
        repo.stored['a']!.copyWith(title: 'Novo título'),
      );
      expect(repo.stored['a']!.title, 'Novo título');

      await controller.togglePin('a');
      expect(repo.stored['a']!.pinned, isTrue);
      expect(notificacoes, 2);
    });

    test('falha do repositório notifica o erro e não aplica a mudança', () async {
      final repo = MemoryRepository(<Note>[fakeNote(id: 'a')]);
      final controller = NotesController(repo);
      await controller.load();

      var notificacoes = 0;
      controller.addListener(() => notificacoes++);

      repo.failOnSave = true;
      final bool ok = await controller.updateNote(
        repo.stored['a']!.copyWith(title: 'X'),
      );

      // O `bool` falso é o contrato que a UI checa antes de dizer "salvou".
      expect(ok, isFalse);
      // A notificação existe justamente para a tela mostrar `lastError` — o que
      // não pode acontecer é uma segunda notificação anunciando a alteração.
      expect(notificacoes, 1);
      expect(controller.notes.single.title, isEmpty);
      expect(controller.lastError, isNotNull);
    });

    test('falha no load mantém o app vivo e registra o erro', () async {
      final repo = MemoryRepository(<Note>[fakeNote(id: 'a')])..failOnLoad = true;
      final controller = NotesController(repo);

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.lastError, isNotNull);
      expect(controller.notes, isEmpty);
    });

    test('load() pode ser chamado duas vezes', () async {
      final controller = NotesController(
        MemoryRepository(<Note>[fakeNote(id: 'a')]),
      );

      await controller.load();
      await controller.load();

      expect(controller.notes.length, 1);
      expect(controller.isLoading, isFalse);
    });
  });
}