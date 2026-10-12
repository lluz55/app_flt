import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../data/note.dart';
import '../../state/notes_controller.dart';
import '../../state/scope.dart';
import '../widgets/aurora_background.dart';
import '../widgets/fade_right_edge.dart';

/// Editor de notas.
///
/// [note] nulo significa "nota nova": nada é gravado no banco até a primeira
/// edição de verdade (texto, tag ou cor). A partir daí o `id` fica guardado em
/// [_draft] e todo salvamento seguinte é um `updateNote`.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.note});

  /// Nota aberta para edição; `null` para uma nota ainda não criada.
  final Note? note;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

/// Ações do menu de três pontos.
enum _EditorAction { toTrash, deleteForever }

/// Alvo de toque da amostra de cor.
///
/// Com 44px as oito amostras somavam 426px e não cabiam nos 394px úteis de um
/// celular de 430px: a última ficava cortada e, sob o esmaecimento da borda,
/// praticamente invisível. A 40px as oito cabem com folga.
const double _swatchTarget = 40;

/// Espaço entre duas amostras de cor.
const double _swatchGap = 8;

/// Fotografia do rascunho no instante em que ele precisa ser gravado.
///
/// Capturar o texto de forma síncrona (antes de qualquer `await`) é o que
/// permite salvar no `dispose`, quando os controllers já estão encerrados.
/// A nota-base **não** entra aqui: quem roda dentro da fila de gravação precisa
/// ler o `_base` vivo, senão um rascunho enfileirado enquanto a nota ainda nem
/// existia criaria uma segunda nota em vez de atualizar a primeira.
@immutable
class _Draft {
  const _Draft({
    required this.title,
    required this.body,
    required this.tags,
    required this.colorIndex,
    required this.colorTouched,
    required this.pinned,
    required this.touched,
  });

  final String title;
  final String body;
  final List<String> tags;
  final int colorIndex;
  final bool colorTouched;
  final bool pinned;

  /// true quando o usuário mexeu em algo nesta sessão de edição.
  final bool touched;

  /// Sem título, sem corpo e sem tags: não vale a pena guardar.
  ///
  /// Fixar e colorir também descartam o rascunho: são escolhas explícitas, e
  /// mandá-las para a lixeira ao fechar desfaria o que a pessoa acabou de pedir.
  /// É o complemento exato de [warrantsCreate] — se um aceitasse e o outro não,
  /// a nota nasceria no autosave e morreria na lixeira logo em seguida.
  bool get isBlank =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      tags.isEmpty &&
      !pinned &&
      !colorTouched;

  /// Texto, tag, fixar ou cor: a partir daqui existe algo para persistir.
  ///
  /// Fixar e colorir contam como escolha mesmo em nota sem texto — são ações
  /// explícitas do usuário, e descartá-las em silêncio faria a nota sumir junto
  /// com a escolha. Já "digitou e apagou tudo" não conta: o editor ainda
  /// reconhece isso como rascunho em branco e manda a nota para a lixeira.
  bool get warrantsCreate =>
      title.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      tags.isNotEmpty ||
      pinned ||
      colorTouched;
}

/// Contadores da linha de status (evita reconstruir a tela a cada tecla).
@immutable
class _Status {
  const _Status({
    required this.words,
    required this.characters,
    required this.stamp,
  });

  final int words;
  final int characters;
  final DateTime stamp;
}

class _EditorScreenState extends State<EditorScreen> {
  /// Intervalo do autosave: agrupa a digitação em uma gravação só.
  static const Duration _debounce = Duration(milliseconds: 400);

  static const int _maxTags = 12;
  static const int _maxTagLength = 24;

  /// Measure confortável para telas largas — o texto não se estica por 1400px.
  static const double _maxColumnWidth = 720;
  static const double _wideBreakpoint = 900;

  /// Abaixo disso (teclado aberto em tela baixa) o painel encolhe.
  static const double _roomyHeight = 520;

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagController;
  late final FocusNode _titleFocus;
  late final FocusNode _bodyFocus;
  late final ValueNotifier<_Status> _status;

  List<String> _tags = <String>[];
  int _colorIndex = 0;
  bool _pinned = false;

  /// Última versão gravada da nota; `null` = ainda não existe no banco.
  Note? _base;

  NotesController? _notes;
  ScaffoldMessengerState? _messenger;
  Timer? _saveTimer;

  /// Fila de gravações: cada uma roda depois da anterior, sem cruzar escritas.
  Future<void> _writes = Future<void>.value();

  bool _colorTouched = false;
  bool _touched = false;
  bool _exitHandled = false;
  bool _skipExitCleanup = false;

  @override
  void initState() {
    super.initState();
    final Note? note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _tagController = TextEditingController();
    _titleFocus = FocusNode();
    _bodyFocus = FocusNode();
    _tags = List<String>.of(note?.tags ?? const <String>[]);
    _colorIndex = note?.colorIndex ?? 0;
    _pinned = note?.pinned ?? false;
    _base = note;
    _status = ValueNotifier<_Status>(_currentStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardados em campo: `dispose` precisa escrever no banco e avisar a pessoa
    // quando a gravação falha sem poder mais tocar no `context`.
    _notes = NotesScope.of(context);
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    // Rede de segurança: se a rota saiu por um caminho que não passou pelo
    // `PopScope`, ainda assim o rascunho é gravado (ou vai para a lixeira).
    final _Draft? pending = (_exitHandled || _skipExitCleanup)
        ? null
        : _draft();

    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _status.dispose();
    super.dispose();

    if (pending != null) {
      // Entra na MESMA fila do autosave. Disparar `_finalize` direto deixaria
      // uma gravação antiga ainda em voo pousar depois desta e sobrescrever o
      // rascunho final com uma versão velha.
      _writes = _enqueue(() => _finalize(pending));
      unawaited(_writes);
    }
  }

  // Rascunho ---------------------------------------------------------------

  /// Fotografia síncrona do estado atual.
  _Draft _draft() => _Draft(
    title: _titleController.text,
    body: _bodyController.text,
    tags: List<String>.unmodifiable(_tags),
    colorIndex: _colorIndex,
    colorTouched: _colorTouched,
    pinned: _pinned,
    touched: _touched,
  );

  _Status _currentStatus() {
    final String body = _bodyController.text;
    final String trimmed = body.trim();
    return _Status(
      words: trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length,
      characters: body.length,
      stamp: _base?.updatedAt ?? DateTime.now(),
    );
  }

  /// Atualiza só a linha de status, sem reconstruir a tela inteira.
  void _refreshStatus() {
    if (!mounted) return;
    _status.value = _currentStatus();
  }

  // Autosave ---------------------------------------------------------------

  void _onDraftChanged(String _) {
    _touched = true;
    _refreshStatus();
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, () => unawaited(_flush()));
  }

  Future<void> _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final _Draft draft = _draft();
    return _enqueue(() => _persist(draft));
  }

  /// Enfileira [action] atrás das gravações pendentes.
  ///
  /// O `onError` é obrigatório: sem ele um `throw` inesperado transformaria a
  /// cadeia numa Future já completada com erro e **todas** as gravações
  /// seguintes seriam descartadas em silêncio — o usuário veria a nota parar de
  /// salvar sem nenhuma indicação.
  Future<void> _enqueue(Future<void> Function() action) {
    _writes = _writes.then((_) => action()).onError((Object _, StackTrace _) {
      // Sem a guarda `mounted`: a falha pode chegar justamente na finalização
      // disparada pelo `dispose`, e é justamente ali que o ScaffoldMessenger
      // continua montado e o usuário mais precisa do aviso. `_reportError`
      // já checa a montagem do messenger antes de falar com ele.
      _reportError('Não foi possível salvar a nota. Tente novamente.');
    });
    return _writes;
  }

  /// Grava [draft] — cria a nota na primeira edição real e atualiza depois.
  ///
  /// O `_base` só passa a valer **depois** da confirmação do repositório: marcar
  /// antes faria o editor achar que salvou uma gravação que se perdeu, e a nota
  /// sumiria na próxima abertura.
  Future<void> _persist(_Draft draft) async {
    final NotesController? notes = _notes;
    final Note? base = _base;
    if (notes == null) return;

    if (base == null) {
      if (!draft.warrantsCreate) return; // ainda é só um rascunho na tela
      final (:note, :persisted) = await notes.createNote();
      final Note created = note;
      final bool createdPersisted = persisted;
      // Sem escolha explícita de cor, respeita a cor que o controller escolheu
      // para a nota nova. Usa o campo vivo (e não a foto) porque o usuário pode
      // ter tocado numa cor enquanto o `createNote` estava em voo.
      final int color = _colorTouched ? _colorIndex : created.colorIndex;
      if (!_colorTouched) _colorIndex = color;
      final Note next = Note(
        id: created.id,
        title: draft.title,
        body: draft.body,
        tags: draft.tags,
        pinned: draft.pinned,
        colorIndex: color,
        createdAt: created.createdAt,
        updatedAt: DateTime.now(),
      );
      if (!await notes.updateNote(next)) {
        if (!createdPersisted) {
          // A criação nem chegou ao disco, então não há cópia em branco para
          // limpar: acusar uma órfã que nunca existiu seria inventar problema.
          _reportError('Não foi possível salvar a nota. Tente novamente.');
          return;
        }
        // Rollback: `createNote` já deixou uma nota em branco no repositório.
        // Sem removê-la ela ficaria órfã na lista e, como `_base` continua
        // nulo, o próximo autosave criaria uma segunda nota vazia.
        final bool rolledBack = await notes.deleteForever(created.id);
        _reportError(
          rolledBack
              ? 'Não foi possível salvar a nota. Tente novamente.'
              : 'Não foi possível salvar a nota e a cópia em branco não pôde '
                    'ser removida. Ela pode reaparecer na lista.',
        );
        return;
      }
      _base = next;
      _refreshStatus();
      return;
    }

    if (base.title == draft.title &&
        base.body == draft.body &&
        base.colorIndex == draft.colorIndex &&
        base.pinned == draft.pinned &&
        _sameTags(base.tags, draft.tags)) {
      return; // nada mudou desde a última gravação
    }
    final Note next = base.copyWith(
      title: draft.title,
      body: draft.body,
      tags: draft.tags,
      pinned: draft.pinned,
      colorIndex: draft.colorIndex,
      updatedAt: DateTime.now(),
    );
    if (!await notes.updateNote(next)) {
      _reportError('Não foi possível salvar a nota. Tente novamente.');
      return;
    }
    _base = next;
    _refreshStatus();
  }

  /// Fecha a nota: grava o que sobrou ou manda para a lixeira.
  Future<void> _finalize(_Draft draft) async {
    final NotesController? notes = _notes;
    if (notes == null) return;

    final Note? base = _base;
    if (base == null) {
      // Nota ainda não gravada: só vira nota de verdade se tiver conteúdo real.
      await _persist(draft);
      return;
    }

    if (draft.isBlank) {
      // Esvaziar uma nota não pode destruí-la em silêncio: a lixeira é
      // reversível e tem "Desfazer", enquanto a remoção definitiva fica
      // reservada para o menu, que exige confirmação explícita.
      // Sem toque do usuário nada muda — ninguém pediu nada.
      if (!draft.touched || base.trashed) return;
      if (await notes.toggleTrash(base.id)) {
        _announceTrashed(base.id);
      } else {
        _reportError('Não foi possível mover a nota para a lixeira. Tente de novo.');
      }
      return;
    }

    await _persist(draft);
  }

  Future<void> _handlePop(bool didPop, Object? _) async {
    if (!didPop || _exitHandled) return;
    _exitHandled = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_skipExitCleanup) return;
    // Foto síncrona: os controllers continuam vivos aqui, mas não depois do
    // primeiro `await`.
    final _Draft draft = _draft();
    // Encadeia na MESMA fila do autosave. Chamar `_finalize` direto é o que
    // fazia a gravação antiga do autosave aterrissar por último e sobrescrever
    // o rascunho final com a versão anterior — ou, se a criação da nota ainda
    // estivesse em voo, criar uma segunda nota com o rascunho.
    _writes = _enqueue(() => _finalize(draft));
    return _writes;
  }

  // Avisos -----------------------------------------------------------------

  /// Erro de escrita visível: sem isto a pessoa sai do editor achando que o
  /// texto está salvo e o rascunho aparece incompleto na próxima abertura.
  void _reportError(String message) {
    final ScaffoldMessengerState? messenger = _messenger;
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _announceTrashed(String id) {
    final ScaffoldMessengerState? messenger = _messenger;
    final NotesController? notes = _notes;
    if (messenger == null || !messenger.mounted || notes == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Nota movida para a lixeira.'),
          action: SnackBarAction(
            label: 'Desfazer',
            // O retorno é verificado: um "desfazer" que falha em silêncio
            // deixaria o usuário achando que a nota voltou para a lista.
            onPressed: () => unawaited(
              notes.toggleTrash(id).then((bool ok) {
                if (!ok) _reportError('Não foi possível restaurar a nota.');
              }),
            ),
          ),
        ),
      );
  }

  // Ações ------------------------------------------------------------------

  void _close() => Navigator.of(context).pop();

  void _togglePin() {
    setState(() => _pinned = !_pinned);
    _touched = true;
    _refreshStatus();
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, () => unawaited(_flush()));
  }

  Future<void> _moveToTrash() async {
    final NotesController? notes = _notes;
    if (notes == null) return;
    final NavigatorState navigator = Navigator.of(context);

    await _flush();
    final String? id = _base?.id;
    _skipExitCleanup = true; // já resolvido aqui; o pop não repete o trabalho
    if (id != null && !await notes.toggleTrash(id)) {
      _skipExitCleanup = false; // a nota continua salva: o editor segue aberto
      _reportError('Não foi possível mover a nota para a lixeira. Tente de novo.');
      return;
    }
    if (!mounted) return;
    navigator.pop();
    if (id != null) _announceTrashed(id);
  }

  Future<void> _deleteForever() async {
    final NotesController? notes = _notes;
    if (notes == null) return;
    final NavigatorState navigator = Navigator.of(context);

    // Mesmo cuidado de [_moveToTrash], e na mesma ordem: primeiro congelar o
    // autosave e drenar a fila, **depois** ler o id. Ler o id antes faria a
    // nota (ainda sem id, se fosse nova) ser persistida pelo debounce durante
    // o diálogo e o "Excluir" não apagaria nada — ela voltaria na lista.
    _saveTimer?.cancel();
    await _flush();
    final String? id = _base?.id;

    final bool confirmed = await _confirm(
      title: 'Excluir permanentemente?',
      message: id == null
          ? 'A nota que você começou ainda não foi salva, então basta fechá-la.'
          : 'Esta nota será apagada para sempre. Não dá para desfazer.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed) return;

    _skipExitCleanup = true;
    if (id != null) {
      // Sem a confirmação do repositório não há exclusão: sair da tela
      // fingindo sucesso esconderia que a nota continua no aparelho.
      final bool ok = await notes.deleteForever(id);
      if (!ok) {
        _skipExitCleanup = false;
        _reportError('Não foi possível excluir a nota. Tente novamente.');
        return;
      }
      _base = null;
    }
    if (!mounted) return;
    navigator.pop();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return answer ?? false;
  }

  // Tags -------------------------------------------------------------------

  void _addTagFromInput() => _addTag(_tagController.text);

  bool _addTag(String raw) {
    final String? tag = _normalizeTag(raw);
    if (tag == null) return false;
    if (_hasTag(tag)) {
      _tagController.clear();
      return false;
    }
    if (_tags.length >= _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Máximo de $_maxTags tags por nota.')),
      );
      return false;
    }
    setState(() => _tags = <String>[..._tags, tag]);
    _tagController.clear();
    _onDraftChanged('');
    return true;
  }

  void _removeTag(String tag) {
    setState(() {
      _tags = _tags.where((item) => item != tag).toList(growable: false);
    });
    _onDraftChanged('');
  }

  bool _hasTag(String tag) {
    final String key = foldAccents(tag.toLowerCase());
    return _tags.any((item) => foldAccents(item.toLowerCase()) == key);
  }

  /// Apara espaços, corta o que passa de [_maxTagLength] e devolve `null`
  /// quando não sobra nada utilizável.
  static String? _normalizeTag(String raw) {
    final String collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return null;
    final String clipped = collapsed.length <= _maxTagLength
        ? collapsed
        : collapsed.substring(0, _maxTagLength).trimRight();
    return clipped.isEmpty ? null : clipped;
  }

  // Construção -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PopScope<void>(
      onPopInvokedWithResult: (bool didPop, Object? _) {
        unawaited(_handlePop(didPop, null));
      },
      // O editor é uma rota empilhada: ela é desenhada **acima** do
      // `AuroraBackground` do shell, dentro do overlay do Navigator. Sem um
      // fundo próprio, o `Scaffold` transparente deixaria passar a cor base do
      // `MaterialApp` e o texto de tema escuro ficaria ilegível.
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // O corpo encolhe com o teclado: o campo de texto continua visível.
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
              onPressed: _close,
            ),
            title: Text(
              _base == null ? 'Nova nota' : 'Editando',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppPalette.muted(theme.brightness),
              ),
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
                tooltip: _pinned ? 'Desafixar nota' : 'Fixar nota',
                onPressed: _togglePin,
              ),
              PopupMenuButton<_EditorAction>(
                tooltip: 'Mais ações',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (_EditorAction action) {
                  switch (action) {
                    case _EditorAction.toTrash:
                      unawaited(_moveToTrash());
                    case _EditorAction.deleteForever:
                      unawaited(_deleteForever());
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_EditorAction>>[
                      PopupMenuItem<_EditorAction>(
                        value: _EditorAction.toTrash,
                        // Sem nota salva ainda não há o que mandar para a lixeira.
                        enabled: _base != null,
                        child: const _MenuRow(
                          icon: Icons.delete_outline_rounded,
                          label: 'Mover para a lixeira',
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<_EditorAction>(
                        value: _EditorAction.deleteForever,
                        child: const _MenuRow(
                          icon: Icons.delete_forever_rounded,
                          label: 'Excluir permanentemente',
                          danger: true,
                        ),
                      ),
                    ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= _wideBreakpoint;
                // Com o teclado aberto sobra pouca altura: as sugestões de tag são
                // a primeira coisa a sair para o painel não estourar.
                final bool roomy = constraints.maxHeight >= _roomyHeight;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxColumnWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 32 : 18,
                        4,
                        wide ? 32 : 18,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildTitle(theme),
                          const SizedBox(height: 6),
                          Expanded(child: _buildBody(theme)),
                          const SizedBox(height: 12),
                          _buildColorPicker(),
                          const SizedBox(height: 14),
                          _buildTagEditor(theme, roomy),
                          const SizedBox(height: 14),
                          Divider(color: theme.colorScheme.outlineVariant),
                          const SizedBox(height: 10),
                          _buildStatusLine(theme),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    final Widget field = TextField(
      controller: _titleController,
      focusNode: _titleFocus,
      onChanged: _onDraftChanged,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      minLines: 1,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      decoration: const InputDecoration(
        hintText: 'Título',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
    );

    final Note? note = widget.note;
    if (note == null) return field;

    // O Hero só existe para notas já existentes: uma nota nova ainda não tem
    // `id` para casar com o cartão da lista.
    return Hero(
      tag: 'note-card-${note.id}',
      flightShuttleBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            HeroFlightDirection direction,
            BuildContext fromContext,
            BuildContext toContext,
          ) {
            return Material(
              type: MaterialType.transparency,
              child: Text(
                note.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
      child: field,
    );
  }

  Widget _buildBody(ThemeData theme) {
    return TextField(
      controller: _bodyController,
      focusNode: _bodyFocus,
      onChanged: _onDraftChanged,
      // `expands` preenche a altura disponível e o campo rola por dentro.
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
      decoration: const InputDecoration(
        hintText: 'Comece a escrever…',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _buildColorPicker() {
    const double spacing = _swatchGap;
    const double padding = 4; // `padding` do ListView, somado dos dois lados
    final double needed =
        AppPalette.noteColors.length * _swatchTarget +
        (AppPalette.noteColors.length - 1) * spacing +
        padding;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget row = ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: padding / 2),
          itemCount: AppPalette.noteColors.length,
          separatorBuilder: (BuildContext context, int _) =>
              const SizedBox(width: spacing),
          itemBuilder: (BuildContext context, int index) {
            return _ColorSwatch(
              color: AppPalette.noteColors[index],
              selected: index == _colorIndex,
              tooltip: 'Cor ${index + 1}',
              onTap: () {
                setState(() => _colorIndex = index);
                _colorTouched = true;
                _touched = true;
                _saveTimer?.cancel();
                _saveTimer = Timer(_debounce, () => unawaited(_flush()));
              },
            );
          },
        );

        return SizedBox(
          height: _swatchTarget,
          // O esmaecimento só entra quando a faixa realmente transborda. Aplicado
          // sempre, ele apagava a última amostra por completo mesmo com as oito
          // cabendo — era o que sumia na captura do editor.
          child: constraints.maxWidth < needed
              ? FadeRightEdge(child: row)
              : row,
        );
      },
    );
  }

  Widget _buildTagEditor(ThemeData theme, bool roomy) {
    final NotesController notes = NotesScope.of(context);
    final List<String> suggestions = roomy
        ? notes.allTags.where((tag) => !_hasTag(tag)).toList(growable: false)
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: roomy ? 96 : 60),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final String tag in _tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                    deleteButtonTooltipMessage: 'Remover a tag $tag',
                  ),
                SizedBox(
                  width: 132,
                  child: TextField(
                    controller: _tagController,
                    onSubmitted: (_) => _addTagFromInput(),
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'Nova tag',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            // Sem o esmaecimento a última sugestão aparece seccionada por uma
            // parede reta na borda, e é só a 5ª de 6 — o resto das etiquetas
            // ficava invisível sem nenhum aviso de que a faixa rola.
            child: FadeRightEdge(
              fadeFraction: 0.09,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (BuildContext context, int _) =>
                    const SizedBox(width: 6),
                itemBuilder: (BuildContext context, int index) {
                  final String tag = suggestions[index];
                  return ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: Text(tag),
                    onPressed: () => _addTag(tag),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusLine(ThemeData theme) {
    final Color muted = AppPalette.muted(theme.brightness);
    final TextStyle? style = theme.textTheme.labelMedium?.copyWith(
      color: muted,
    );

    return ValueListenableBuilder<_Status>(
      valueListenable: _status,
      builder: (BuildContext context, _Status status, Widget? _) {
        return Row(
          children: <Widget>[
            Icon(Icons.notes_rounded, size: 14, color: muted),
            const SizedBox(width: 6),
            Text(_plural(status.words, 'palavra', 'palavras'), style: style),
            Text(' · ', style: style),
            Flexible(
              child: Text(
                _plural(status.characters, 'caractere', 'caracteres'),
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 8),
            Text('Editada ${DateX.relative(status.stamp)}', style: style),
          ],
        );
      },
    );
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _plural(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';
}

/// Amostra de cor com anel e "check" na seleção.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ring = isDark ? Colors.white : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: _swatchTarget,
              child: Center(
                child: AnimatedContainer(
                  duration: animate
                      ? const Duration(milliseconds: 180)
                      : Duration.zero,
                  width: selected ? 32 : 26,
                  height: selected ? 32 : 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: ring, width: 2.5)
                        : null,
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de menu com ícone e rótulo.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color? color = danger ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        // Flexível: rótulos longos (e escala de texto grande) não estouram o menu.
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
