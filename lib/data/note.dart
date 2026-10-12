/// Modelo de nota do Anotador.
///
/// Imutável, sem geração de código: a persistência usa apenas
/// `Map<String, dynamic>` (datas como ISO-8601 em `String`).
class Note {
  /// Quantidade de cores de cartão disponíveis (`AppPalette.noteColors`).
  static const int colorCount = 8;

  /// Maior índice de cor válido.
  static const int maxColorIndex = colorCount - 1;

  /// Tamanho aproximado da prévia usada nas listas.
  static const int previewMaxLength = 160;

  /// Título usado quando a nota não tem título nem primeira linha útil.
  static const String untitledFallback = 'Sem título';

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final bool pinned;
  final bool trashed;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.tags = const <String>[],
    this.pinned = false,
    this.trashed = false,
    this.colorIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Note copyWith({
    String? title,
    String? body,
    List<String>? tags,
    bool? pinned,
    bool? trashed,
    int? colorIndex,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      trashed: trashed ?? this.trashed,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Reconstrói uma nota a partir de dados persistidos.
  ///
  /// Tolerante a registros legados: chaves ausentes, `null` no lugar de
  /// strings e números chegando como `int` ou `double` não lançam erro.
  factory Note.fromJson(Map<String, dynamic> json) {
    final createdAt = _readDate(json['createdAt']);
    final updatedAt = _readDate(json['updatedAt'], fallback: createdAt);
    final id = _readString(json['id']).trim();
    return Note(
      id: id.isEmpty ? _fallbackId() : id,
      title: _readString(json['title']),
      body: _readString(json['body']),
      tags: _readTags(json['tags']),
      pinned: _readBool(json['pinned']),
      trashed: _readBool(json['trashed']),
      colorIndex: _readInt(json['colorIndex']).clamp(0, maxColorIndex),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Serializa para persistência (sem `DateTime`: o Hive usa string ISO-8601).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'tags': List<String>.of(tags),
      'pinned': pinned,
      'trashed': trashed,
      'colorIndex': colorIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Título exibido: o título, ou a 1ª linha útil do corpo, ou "Sem título".
  String get displayTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    for (final line in body.split('\n')) {
      final candidate = line.trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return untitledFallback;
  }

  /// Prévia de texto corrido, com no máximo [previewMaxLength] caracteres.
  ///
  /// Quebras de linha viram " · " em vez de espaço: em listas ("Pães de forma"
  /// / "Manteiga") um espaço simples faz o leitor achar que é um item só.
  String get preview {
    final lines = body
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty);
    final joined = lines.join(' · ');
    if (joined.isEmpty) return '';
    if (joined.length <= previewMaxLength) return joined;
    return '${joined.substring(0, previewMaxLength).trimRight()}…';
  }

  /// true se título, corpo ou alguma tag contêm [query]
  /// (case-insensitive e acento-insensitive). Consulta vazia casa com tudo.
  bool matches(String query) {
    final needle = foldAccents(query.trim());
    if (needle.isEmpty) return true;
    if (foldAccents(title).contains(needle)) return true;
    if (foldAccents(body).contains(needle)) return true;
    for (final tag in tags) {
      if (foldAccents(tag).contains(needle)) return true;
    }
    return false;
  }

  /// Título e corpo vazios.
  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Quantidade de palavras do corpo.
  int get wordCount {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  String toString() => 'Note($id, $displayTitle)';
}

/// Normaliza [input] para comparação: minúsculas e sem acentos.
///
/// A dobradura funciona em duas etapas complementares: (1) `toLowerCase()`
/// resolve maiúsculas; (2) cada caractere vira a letra base correspondente e
/// marcas combinantes Unicode são descartadas. Texto já decomposto (NFD) é
/// tratado só pela segunda etapa.
String foldAccents(String input) {
  final lowered = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lowered.runes) {
    if (_isCombiningMark(rune)) continue;
    final char = String.fromCharCode(rune);
    buffer.write(_accentMap[char] ?? char);
  }
  return buffer.toString();
}

/// Verdadeiro para os intervalos Unicode de `Mn`/`Me`/`Mc` (marcas combinantes).
bool _isCombiningMark(int rune) {
  return (rune >= 0x0300 && rune <= 0x036F) || // Combining Diacritical Marks
      (rune >= 0x0483 && rune <= 0x0489) ||
      (rune >= 0x0591 && rune <= 0x05BD) ||
      (rune >= 0x0610 && rune <= 0x061A) ||
      (rune >= 0x064B && rune <= 0x065F) ||
      (rune >= 0x1AB0 && rune <= 0x1AFF) ||
      (rune >= 0x1DC0 && rune <= 0x1DFF) ||
      (rune >= 0x20D0 && rune <= 0x20FF) ||
      (rune >= 0xFE20 && rune <= 0xFE2F);
}

/// Letras latinas precompostas (NFD = base) e suas bases em minúsculas.
///
/// Cobre apenas o repertório de português/inglês comum — não é um mapa de todas
/// as letras do alfabeto: o resto do mundo continua funcionando, apenas sem
/// dobradura. Ligaduras caem na letra base (`æ`→`a`, `ß`→`s`) para manter o
/// pareamento 1:1 com [_accentBases]; texto já decomposto (NFD) é tratado só
/// pela remoção de marcas combinantes. Duas `String` paralelas mantêm os dados
/// legíveis e o `assert` garante que nunca fiquem desalinhadas.
const String _precomposed =
    'àáâãäåāăą'
    'æ'
    'çćĉċč'
    'ďđ'
    'èéêëēĕėęě'
    'ĝğġģ'
    'ĥħ'
    'ìíîïĩīĭįı'
    'ĳ'
    'ĵ'
    'ķĸ'
    'ĺļľł'
    'ñńņňŉ'
    'òóôõöøōŏő'
    'œ'
    'ŕŗř'
    'śŝşš'
    'ţťŧ'
    'ùúûüũūŭůűų'
    'ŵ'
    'ýÿŷ'
    'źżž'
    'ß'
    'þ';

const String _accentBases =
    'aaaaaaaaa'
    'a'
    'ccccc'
    'dd'
    'eeeeeeeee'
    'gggg'
    'hh'
    'iiiiiiiii'
    'i'
    'j'
    'kk'
    'llll'
    'nnnnn'
    'ooooooooo'
    'o'
    'rrr'
    'ssss'
    'ttt'
    'uuuuuuuuuu'
    'w'
    'yyy'
    'zzz'
    's'
    't';

final Map<String, String> _accentMap = _buildAccentMap();

Map<String, String> _buildAccentMap() {
  assert(
    _precomposed.length == _accentBases.length,
    'Tabela de acentos desalinhada.',
  );
  final map = <String, String>{};
  final precomposed = _precomposed.runes.toList();
  final bases = _accentBases.runes.toList();
  for (var i = 0; i < precomposed.length && i < bases.length; i++) {
    map[String.fromCharCode(precomposed[i])] = String.fromCharCode(bases[i]);
  }
  return map;
}

String _fallbackId() =>
    'nota-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

String _readString(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return '';
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

DateTime _readDate(Object? value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is double) return DateTime.fromMillisecondsSinceEpoch(value.round());
  if (value is String) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

List<String> _readTags(Object? value) {
  final raw = switch (value) {
    final List<Object?> list => list,
    final String single => <Object?>[single],
    _ => const <Object?>[],
  };
  final tags = <String>[];
  final seen = <String>{};
  for (final item in raw) {
    final tag = _readString(item).trim();
    if (tag.isEmpty) continue;
    if (seen.add(tag.toLowerCase())) tags.add(tag);
  }
  return List<String>.unmodifiable(tags);
}