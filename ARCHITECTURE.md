# Anotador — Contrato de Arquitetura

> Este arquivo é a **fonte da verdade** da API pública do app. Todos os módulos
> são escritos em paralelo contra estes contratos. **Não desvie destes nomes.**

## Stack

- Flutter 3.47.4 / Dart 3.13.3 (via `nix develop`)
- Persistência: `hive_ce` (puro Dart; funciona em Android, Web e Linux)
- Estado: `ChangeNotifier` + `InheritedNotifier` (sem Riverpod/provider)
- Tipografia: família **Inter** (já declarada no `pubspec.yaml`)
- Comandos sempre via `nix develop -c ...`

## Estrutura de pastas

```
lib/
  main.dart
  app.dart
  core/
    theme/palette.dart
    theme/app_theme.dart
    utils/date_x.dart
  data/
    note.dart
    note_repository.dart
  state/
    notes_controller.dart
    settings_controller.dart
    scope.dart
  ui/
    screens/…      (wave 2)
    widgets/…      (wave 1)
```

## Contrato 1 — Modelo (`lib/data/note.dart`)

```dart
class Note {
  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final bool pinned;
  final bool trashed;
  final int colorIndex;        // índice 0..7 em AppPalette.noteColors
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({required this.id, this.title = '', this.body = '', this.tags = const [],
    this.pinned = false, this.trashed = false, this.colorIndex = 0,
    required this.createdAt, required this.updatedAt});

  Note copyWith({String? title, String? body, List<String>? tags, bool? pinned,
    bool? trashed, int? colorIndex, DateTime? updatedAt});

  factory Note.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  /// Título para exibição: o título, ou a 1ª linha do corpo, ou "Sem título".
  String get displayTitle;
  /// Prévia de 2–3 linhas do corpo, sem quebras de linha extras.
  String get preview;
  /// true se título, corpo ou alguma tag contêm `query` (case/acento-insensitive).
  bool matches(String query);
  bool get isEmpty;           // título e corpo vazios
  int get wordCount;
}
```

## Contrato 2 — Repositório (`lib/data/note_repository.dart`)

```dart
abstract class NoteRepository {
  Future<List<Note>> loadAll();
  Future<void> save(Note note);
  Future<void> delete(String id);
  Future<void> emptyTrash();
}

class HiveNoteRepository implements NoteRepository {
  static const String boxName = 'notes';
  HiveNoteRepository(this._box);
  static Future<HiveNoteRepository> open();   // Hive.initFlutter + openBox
}
```

Armazena **Maps** (`note.toJson()`) sob o `id` — **sem** `TypeAdapter` e **sem**
`build_runner`/geração de código.

## Contrato 3 — Estado (`lib/state/`)

```dart
class NotesController extends ChangeNotifier {
  NotesController(this._repository);
  Future<void> load();

  List<Note> get notes;          // ativas, já filtradas e ordenadas
  List<Note> get trash;          // na lixeira
  int get activeCount;
  bool get isLoading;

  String get query;
  void setQuery(String value);   // notifica
  bool get isFiltering;
  List<String> get activeTags;
  void toggleTag(String tag);    // notifica
  void clearFilters();           // limpa query + tags, notifica

  // `persisted` diz se a nota em branco chegou ao disco: sem isso o editor
// não consegue distinguir "criou e o conteúdo falhou" (órfã a remover) de
// "nada foi gravado" (não há o que limpar).
Future<(Note note, bool persisted)> createNote();
  // Toda mutação devolve `bool`: a UI só anuncia sucesso ("foi para a
  // lixeira", "salvou") **depois** do `await` que confirmou a gravação.
  // Antes elas devolviam `void` e o app engolia falhas de I/O em silêncio.
  Future<bool> updateNote(Note note);
  Future<bool> togglePin(String id);
  Future<bool> toggleTrash(String id);   // manda para/da lixeira
  Future<bool> deleteForever(String id);
  Future<bool> restore(String id);
  Future<bool> emptyTrash();
  List<String> get allTags;      // tags existentes nas notas ativas, ordenadas
}

class SettingsController extends ChangeNotifier {
  ThemeMode get themeMode;
  // `false` quando a gravação falhou: o estado em memória já mudou (a UI
  // refletiu), mas a preferência não sobrevive ao reinício e precisa ser avisada.
  Future<bool> setThemeMode(ThemeMode mode);   // persiste no Hive
  bool get compactMode;                         // densidade da lista
  Future<bool> setCompactMode(bool value);
}
```

## Contrato 4 — Injeção (`lib/state/scope.dart`)

```dart
class NotesScope extends InheritedNotifier<NotesController> {
  const NotesScope({super.key, required NotesController controller, required super.child});
  static NotesController of(BuildContext context);   // também registra dependência
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({super.key, required SettingsController controller, required super.child});
  static SettingsController of(BuildContext context);
}
```

## Contrato 5 — Sistema de design (`lib/core/theme/`)

```dart
// palette.dart
abstract final class AppPalette {
  static const Color violet, fuchsia, cyan, amber, lime, coral, sky, pink;
  /// 8 cores saturadas para o cartão de cada nota (ordem importa: colorIndex).
  static const List<Color> noteColors;
  static Color noteColor(int index);

  /// Cores base por brilho.
  static Color background(Brightness b);
  static Color surface(Brightness b);
  static Color onSurface(Brightness b);
  static Color muted(Brightness b);

  /// Gradiente do fundo (aurora).
  static LinearGradient auroraGradient(Brightness b);
  /// 4 cores dos blobs flutuantes do fundo.
  static List<Color> auroraBlobs(Brightness b);
}

// app_theme.dart
abstract final class AppTheme {
  static ThemeData light();
  static ThemeData dark();
}
```

Ambos devem definir `useMaterial3: true`, `fontFamily: 'Inter'`, e um
`ColorScheme` coerente com a paleta. Textos com **tracking** negativo em
títulos grandes (ex.: `displaySmall`, `headlineSmall`) para dar o ar moderno.

## Contrato 6 — Widgets compartilhados (wave 1)

```dart
// lib/ui/widgets/aurora_background.dart
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child, this.animate = true});
  // Empilhado atrás de `child`: gradiente + 3-4 blobs radializados e animados.
  // Respeita MediaQuery.disableAnimations.
}

// lib/ui/widgets/glass_card.dart
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24, this.onTap, this.tint, this.blur = 18, this.elevated = true});
  // ClipRRect + BackdropFilter + borda sutil com gradiente.
}
```

##Diretrizes visuais

- **Moderno e expressivo**: fundo "aurora" com gradientes vivos e blobs
  desfocados; cartões de vidro translúcidos sobre ele.
- **Hierarquia clara**: títulos grandes com peso 600–700, corpo em 400,
  metadados em 400–500 e tamanho menor com cor suave.
- **Microinterações**: `Hero` entre lista e editor, `AnimatedSwitcher` nos
  estados vazio/lista, `AnimatedContainer`/`TweenAnimationBuilder` em tags e
  no FAB, transição suave ao favoritar.
- **Responsivo**: `LayoutBuilder` — faixa de lista+detalhe lado a lado em
  largura ≥ 900px, coluna única abaixo disso.
- **Acessibilidade**: todo `IconButton` com `tooltip`; contraste do texto
  ≥ 4.5:1 nos dois temas; alvos de toque de 44px, com exceção documentada das
  amostras de cor e dos botões da lixeira (40px): as 8 amostras a 44px somavam
  426px e não cabiam nos 394px úteis de um celular de 430px — a última ficava
  cortada e, sob o esmaecimento, invisível.

## Regras de coding (obrigatórias)

- Português do Brasil em **toda** string visível ao usuário e em testes.
- `flutter_lints` ativo: `flutter analyze` precisa passar **sem** warnings.
- Nada de `print`/`debugPrint` no código de produção.
- Sem `build_runner`, sem geração de código.