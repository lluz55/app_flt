// Captura de telas para revisão visual.
//
// Não há desktop environment neste host, então o app é renderizado pelo próprio
// Flutter (`flutter_tester`) e gravado em PNG — sem depender de navegador nem
// de GPU. Rode com:
//
//   nix develop -c flutter test test/golden_capture_test.dart --update-goldens
//
// As imagens saem em test/goldens/ e depois são copiadas para shots/.

import 'package:anotador/app.dart';
import 'package:anotador/data/note.dart';
import 'package:anotador/state/notes_controller.dart';
import 'package:anotador/state/settings_controller.dart';
import 'package:anotador/state/settings_store.dart';
import 'package:anotador/ui/screens/editor_screen.dart';
import 'package:anotador/ui/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

// As fontes reais e a box do Hive são preparadas em
// `test/flutter_test_config.dart`, fora do relógio virtual.

List<Note> _demoNotes() => <Note>[
  fakeNote(
    id: 'a',
    title: 'Bem-vindo ao Anotador',
    body:
        'Seu cantinho para ideias, listas e rascunhos.\n\n'
        'Toque em uma nota para editar. Use o alfinete para manter no topo o '
        'que importa agora.',
    tags: ['início'],
    colorIndex: 0,
    pinned: true,
    ago: const Duration(minutes: 12),
  ),
  fakeNote(
    id: 'b',
    title: 'Ideias para o projeto',
    body:
        '• Modo foco com cronômetro\n'
        '• Sincronizar entre dispositivos\n'
        '• Etiquetas coloridas com atalhos',
    tags: ['trabalho', 'ideias'],
    colorIndex: 5,
    pinned: true,
    ago: const Duration(hours: 3),
  ),
  fakeNote(
    id: 'c',
    title: 'Lista do mercado',
    body: 'Café em grão\nAvelã\nLeite de aveia\nPães de forma\nManteiga',
    tags: ['pessoal', 'compras'],
    colorIndex: 2,
    ago: const Duration(hours: 9),
  ),
  fakeNote(
    id: 'd',
    title: 'Livros para ler',
    body:
        '"Dune" — Frank Herbert\n'
        '"O Programador Pragmático" — Hunt & Thomas',
    tags: ['leitura'],
    colorIndex: 7,
    ago: const Duration(days: 2),
  ),
  fakeNote(
    id: 'e',
    title: 'Reunião de segunda',
    body: 'Pauta:\n1. Revisão do trimestre\n2. Cronograma de entregas',
    tags: ['trabalho'],
    colorIndex: 4,
    ago: const Duration(days: 5),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ThemeMode theme,
  List<Note> seed = const <Note>[],
}) async {
  // `tester.view` (e não `setSurfaceSize`): só ele atualiza o `MediaQuery` que o
// app usa para escolher entre trilho lateral e barra inferior. Com
// `setSurfaceSize` a interface desenhava no tamanho pedido mas o layout
// responsivo "achava" que estava no tamanho padrão.
tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final notes = NotesController(MemoryRepository(seed));
  await notes.load();

  final settings = SettingsController(InMemorySettingsStore());
  await settings.setThemeMode(theme);

  // O `RepaintBoundary` externo é o que o golden captura.
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('captura'),
      child: AnotadorApp(
        notesController: notes,
        settingsController: settings,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byKey(const Key('captura')),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  const phone = Size(430, 932);
  const desktop = Size(1440, 900);

  testWidgets('lista de notas — claro — celular', (tester) async {
    await _pump(tester, size: phone, theme: ThemeMode.light, seed: _demoNotes());
    await capture(tester, '01-lista-claro-celular');
  });

  testWidgets('lista de notas — escuro — celular', (tester) async {
    await _pump(tester, size: phone, theme: ThemeMode.dark, seed: _demoNotes());
    await capture(tester, '02-lista-escuro-celular');
  });

  testWidgets('lista de notas — escuro — desktop', (tester) async {
    await _pump(tester, size: desktop, theme: ThemeMode.dark, seed: _demoNotes());
    await capture(tester, '03-lista-escuro-desktop');
  });

  testWidgets('lista vazia — escuro — celular', (tester) async {
    await _pump(tester, size: phone, theme: ThemeMode.dark);
    await capture(tester, '04-vazio-escuro-celular');
  });

  testWidgets('editor — escuro — celular', (tester) async {
    await _pump(tester, size: phone, theme: ThemeMode.dark, seed: _demoNotes());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.descendant(
        of: find.byType(EditorScreen),
        matching: find.byType(TextField),
      ).first,
      'Roteiro da apresentação',
    );
    await tester.pump(const Duration(milliseconds: 700));

    await capture(tester, '05-editor-escuro-celular');
  });

  testWidgets('editor — claro — celular', (tester) async {
    await _pump(tester, size: phone, theme: ThemeMode.light, seed: _demoNotes());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.descendant(
        of: find.byType(EditorScreen),
        matching: find.byType(TextField),
      ).first,
      'Roteiro da apresentação',
    );
    await tester.pump(const Duration(milliseconds: 700));

    await capture(tester, '06-editor-claro-celular');
  });

  testWidgets('lixeira — claro — celular', (tester) async {
    await _pump(
      tester,
      size: phone,
      theme: ThemeMode.light,
      seed: <Note>[
        fakeNote(
          id: 'x',
          title: 'Rascunho descartado',
          body: 'Ideia que não vingou.',
          tags: ['ideias'],
          trashed: true,
          ago: const Duration(days: 1),
        ),
      ],
    );
    await tester.tap(find.text('Lixeira'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture(tester, '07-lixeira-claro-celular');
  });

  testWidgets('ajustes — escuro — celular', (tester) async {
    await _pump(tester, size: phone, theme: ThemeMode.dark, seed: _demoNotes());
    await tester.tap(find.text('Ajustes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture(tester, '08-ajustes-escuro-celular');
  });

  testWidgets('busca com filtro — claro — desktop', (tester) async {
    await _pump(tester, size: desktop, theme: ThemeMode.light, seed: _demoNotes());
    await tester.enterText(
      find.descendant(of: find.byType(SearchField), matching: find.byType(TextField)),
      'trabalho',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await capture(tester, '09-busca-claro-desktop');
  });
}