/// Formatação de datas em pt-BR, implementada sem nenhum pacote externo.
///
/// Cobre apenas o que o app precisa: texto relativo a agora ("há 3 min").
abstract final class DateX {
  const DateX._();

  /// Rótulo único para qualquer data no futuro (ex.: relógios adiantados).
  static const String _future = 'em breve';

  static const List<String> _monthsShort = <String>[
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  /// Data como texto relativo a [now] (padrão: agora).
  ///
  /// Datas no futuro viram [_future]; o que for mais antigo que ~5 semanas cai
  /// para "12 de mar", acrescentando o ano quando difere do ano corrente.
  static String relative(DateTime date, {DateTime? now}) {
    final DateTime target = date.toLocal();
    final DateTime reference = (now ?? DateTime.now()).toLocal();
    final Duration diff = reference.difference(target);

    if (diff.isNegative) {
      return _future;
    }
    if (diff.inMinutes < 1) {
      return 'agora';
    }
    if (diff.inHours < 1) {
      return 'há ${diff.inMinutes} min';
    }
    if (diff.inDays < 1) {
      return 'há ${diff.inHours} h';
    }
    if (diff.inDays < 7) {
      return 'há ${diff.inDays} d';
    }
    if (diff.inDays < 35) {
      return 'há ${diff.inDays ~/ 7} sem';
    }
    return _dayAndMonth(target, reference);
  }

  /// "12 de mar" no ano corrente; "12 de mar de 2024" em anos diferentes.
  static String _dayAndMonth(DateTime target, DateTime reference) {
    final String base = '${target.day} de ${_monthsShort[target.month - 1]}';
    return target.year == reference.year ? base : '$base de ${target.year}';
  }
}