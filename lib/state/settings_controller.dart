import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'settings_store.dart';

/// Preferências do usuário, persistidas em um [SettingsStore].
class SettingsController extends ChangeNotifier {
  SettingsController(this._store) {
    _themeMode = _readTheme(_store.read(_themeKey));
    _compactMode = _store.read(_compactKey) == true;
  }

  /// Nome da box de configurações (usada apenas pela implementação Hive).
  static const String boxName = 'settings';

  static const String _themeKey = 'themeMode';
  static const String _compactKey = 'compactMode';

  final SettingsStore _store;

  ThemeMode _themeMode = ThemeMode.system;
  bool _compactMode = false;

  /// Abre a box de configurações no Hive e devolve o controller pronto.
  static Future<SettingsController> load() async {
    await Hive.initFlutter();
    final Box<dynamic> box = await Hive.openBox<dynamic>(boxName);
    return SettingsController(HiveSettingsStore(box));
  }

  static ThemeMode _readTheme(Object? stored) {
    if (stored is String) {
      for (final mode in ThemeMode.values) {
        if (mode.name == stored) return mode;
      }
    }
    return ThemeMode.system;
  }

  /// `ThemeMode.system` por padrão.
  ThemeMode get themeMode => _themeMode;

  /// Densidade compacta da lista; `false` por padrão.
  bool get compactMode => _compactMode;

  /// Atualiza o tema **antes** de persistir.
  ///
  /// A gravação em disco é assíncrona; notificar só depois dela deixaria a
  /// interface aguardando o I/O para refletir a escolha. Por isso o estado em
  /// memória e o `notifyListeners()` vêm primeiro, e a escrita acontece logo em
  /// seguida.
  ///
  /// Devolve `false` quando a gravação falha: a escolha continua valendo nesta
  /// sessão, mas a tela precisa avisar que ela não sobrevive ao reinício.
  Future<bool> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return true;
    _themeMode = mode;
    notifyListeners();
    return _write(_themeKey, mode.name);
  }

  /// Mesma estratégia de [setThemeMode] para a densidade da lista.
  Future<bool> setCompactMode(bool value) async {
    if (_compactMode == value) return true;
    _compactMode = value;
    notifyListeners();
    return _write(_compactKey, value);
  }

  /// Grava a preferência sem deixar a exceção escapar.
  ///
  /// Os chamadores usam `unawaited`: uma exceção de I/O que escapasse por ali
  /// viraria erro assíncrono não tratado, sem aviso nenhum para o usuário.
  Future<bool> _write(String key, Object value) async {
    try {
      await _store.write(key, value);
      return true;
    } on Object {
      return false;
    }
  }
}