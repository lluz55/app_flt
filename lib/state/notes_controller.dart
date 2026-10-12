import 'package:flutter/foundation.dart';

import '../data/note.dart';
import '../data/note_repository.dart';

/// Estado da lista de notas: carregamento, filtros, ordenação e mutações.
class NotesController extends ChangeNotifier {
  NotesController(this._repository);

  final NoteRepository _repository;

  /// Tudo que foi carregado do repositório, inclusive a lixeira.
  final List<Note> _all = <Note>[];

  /// Tags ativas no filtro (AND).
  final Set<String> _activeTags = <String>{};

  bool _isLoading = false;
  String _query = '';
  Object? _lastError;

  /// Último erro de leitura/escrita, para a UI reagir com segurança.
  Object? get lastError => _lastError;

  bool get isLoading => _isLoading;

  String get query => _query;

  /// true se há busca textual ou filtro de tags ativo.
  bool get isFiltering => _query.trim().isNotEmpty || _activeTags.isNotEmpty;

  List<String> get activeTags => _activeTags.toList(growable: false);

  /// Carrega do repositório. Seguro para chamar mais de uma vez.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final loaded = await _repository.loadAll();
      _all
        ..clear()
        ..addAll(loaded);
      _lastError = null;
    } on Object catch (error) {
      // Mantém a lista em memória consistente e não derruba o app.
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ativas, já filtradas e ordenadas: fixadas primeiro, depois `updatedAt` desc.
  List<Note> get notes {
    final result = _all.where((note) => _passesFilters(note)).toList();
    result.sort(_compareForList);
    return result;
  }

  /// Notas na lixeira, mais recentes primeiro.
  List<Note> get trash {
    final result = _all.where((note) => note.trashed).toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  /// Total de notas ativas, independentemente dos filtros.
  int get activeCount => _all.where((note) => !note.trashed).length;

  /// Tags distintas das notas ativas, sem acentos ou espaços sobrando.
  List<String> get allTags {
    final byKey = <String, String>{};
    for (final note in _all) {
      if (note.trashed) continue;
      for (final raw in note.tags) {
        final tag = raw.trim();
        if (tag.isEmpty) continue;
        // A primeira grafia encontrada vence; variantes de caixa colapsam.
        byKey.putIfAbsent(foldAccents(tag.toLowerCase()), () => tag);
      }
    }
    final tags = byKey.values.toList();
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void toggleTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty) return;
    if (!_activeTags.remove(value)) _activeTags.add(value);
    notifyListeners();
  }

  void clearFilters() {
    if (!isFiltering) return;
    _query = '';
    _activeTags.clear();
    notifyListeners();
  }

  /// Cria, persiste e devolve uma nota em branco.
  ///
  /// O registro traz a nota e se ela **chegou ao disco**. O `bool` é o que
  /// permite ao editor reagir certo: quando a criação falha e a gravação do
  /// conteúdo falha junto, não existe cópia em branco órfã para remover, e
  /// dizer o contrário acusaria uma nota que o usuário nunca teve. A nota é
  /// devolvida de qualquer forma — quem chamou decide o que fazer.
  Future<({Note note, bool persisted})> createNote() async {
    final now = DateTime.now();
    final note = Note(
      id: 'nota-${now.microsecondsSinceEpoch.toRadixString(36)}',
      colorIndex: _nextColorIndex(),
      createdAt: now,
      updatedAt: now,
    );
    final ok = await _persist(note);
    if (ok) {
      _all.add(note);
      notifyListeners();
    }
    return (note: note, persisted: ok);
  }

  /// Grava [note] e devolve `true` quando deu certo.
  ///
  /// O `bool` é o contrato com a UI: sem ele a tela só teria como mentir
  /// "salvo!" para uma gravação que na verdade falhou.
  Future<bool> updateNote(Note note) async {
    final ok = await _persist(note);
    if (!ok) return false;
    _upsert(note);
    notifyListeners();
    return true;
  }

  Future<bool> togglePin(String id) => _mutate(id, (note) {
    return note.copyWith(
      pinned: !note.pinned,
      updatedAt: DateTime.now(),
    );
  });

  Future<bool> toggleTrash(String id) => _mutate(id, (note) {
    return note.copyWith(
      trashed: !note.trashed,
      updatedAt: DateTime.now(),
    );
  });

  Future<bool> restore(String id) => _mutate(id, (note) {
    return note.copyWith(trashed: false, updatedAt: DateTime.now());
  });

  Future<bool> deleteForever(String id) async {
    try {
      await _repository.delete(id);
    } on Object catch (error) {
      _lastError = error;
      notifyListeners();
      return false;
    }
    _lastError = null;
    _all.removeWhere((note) => note.id == id);
    notifyListeners();
    return true;
  }

  Future<bool> emptyTrash() async {
    try {
      await _repository.emptyTrash();
    } on Object catch (error) {
      _lastError = error;
      notifyListeners();
      return false;
    }
    _lastError = null;
    _all.removeWhere((note) => note.trashed);
    notifyListeners();
    return true;
  }

  /// Persiste e devolve `true` quando deu certo; em caso de falha mantém
  /// o estado em memória intacto e registra [lastError].
  Future<bool> _persist(Note note) async {
    try {
      await _repository.save(note);
      _lastError = null;
      return true;
    } on Object catch (error) {
      _lastError = error;
      notifyListeners();
      return false;
    }
  }

  /// Aplica [transform] na nota [id] e devolve `true` se a gravação passou.
  Future<bool> _mutate(String id, Note Function(Note note) transform) async {
    final index = _all.indexWhere((note) => note.id == id);
    if (index < 0) return false;
    final updated = transform(_all[index]);
    final ok = await _persist(updated);
    if (!ok) return false;
    _upsert(updated);
    notifyListeners();
    return true;
  }

  void _upsert(Note note) {
    final index = _all.indexWhere((item) => item.id == note.id);
    if (index < 0) {
      _all.add(note);
    } else {
      _all[index] = note;
    }
  }

  bool _passesFilters(Note note) {
    if (note.trashed) return false;
    if (_activeTags.isNotEmpty) {
      final tags = note.tags.map((tag) => foldAccents(tag.toLowerCase()));
      // Semântica AND: a nota precisa conter todas as tags ativas.
      if (!_activeTags.every((active) => tags.contains(
            foldAccents(active.toLowerCase()),
          ))) {
        return false;
      }
    }
    if (_query.trim().isNotEmpty && !note.matches(_query)) return false;
    return true;
  }

  /// Fixadas primeiro; dentro de cada grupo, mais recentes primeiro.
  static int _compareForList(Note a, Note b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  /// Escolhe a menor cor livre entre as 8 mais recentes.
  ///
  /// Reaproveitar a cor da nota que acabou de ser criada faz a lista piscar
  /// numa cor só; alternar entre as cores livres mantém cada cartão novo
  /// visualmente distinto do que está no topo. Se as 8 estiverem em uso,
  /// gira pela contagem para variar.
  int _nextColorIndex() {
    final recent = _all.length > Note.colorCount
        ? (_all.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
            .take(Note.colorCount)
        : _all;
    final used = recent.map((note) => note.colorIndex).toSet();
    for (var i = 0; i < Note.colorCount; i++) {
      if (!used.contains(i)) return i;
    }
    return _all.length % Note.colorCount;
  }
}