import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'note.dart';

/// Contrato de armazenamento das notas.
abstract class NoteRepository {
  /// Carrega todas as notas persistidas (ativas e da lixeira).
  Future<List<Note>> loadAll();

  /// Grava/substitui uma nota pelo seu [Note.id].
  Future<void> save(Note note);

  /// Remove definitivamente a nota com o [id] informado.
  Future<void> delete(String id);

  /// Remove definitivamente apenas as notas marcadas como `trashed`.
  Future<void> emptyTrash();
}

/// Repositório sobre uma `Box` do Hive, guardando `Map<String, dynamic>`.
class HiveNoteRepository implements NoteRepository {
  /// Nome da box de notas.
  static const String boxName = 'notes';

  HiveNoteRepository(this._box);

  final Box<dynamic> _box;

  /// Abre (ou cria) a box e devolve o repositório pronto para uso.
  static Future<HiveNoteRepository> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>(boxName);
    return HiveNoteRepository(box);
  }

  @override
  Future<List<Note>> loadAll() async {
    final notes = <Note>[];
    // `values` é o acessor eficiente e também funciona na web.
    for (final entry in _box.values) {
      if (entry is! Map) continue;
      try {
        notes.add(Note.fromJson(Map<String, dynamic>.from(entry)));
      } on Object {
        // Registro legado corrompido: ignorado em vez de derrubar a lista.
        continue;
      }
    }
    return notes;
  }

  @override
  Future<void> save(Note note) async {
    await _box.put(note.id, note.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> emptyTrash() async {
    final trashedKeys = <dynamic>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is Map && value['trashed'] == true) trashedKeys.add(key);
    }
    if (trashedKeys.isEmpty) return;
    await _box.deleteAll(trashedKeys);
  }
}