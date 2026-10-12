import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Armazenamento das preferências do usuário.
///
/// Existe como interface para que o app não dependa do Hive diretamente: os
/// testes usam [InMemorySettingsStore] e assim não precisam de disco, I/O real
/// nem do relógio virtual do `flutter_test`.
abstract class SettingsStore {
  /// Valor bruto guardado em [key], ou `null` se não houver nada.
  Object? read(String key);

  /// Grava [value] em [key].
  Future<void> write(String key, Object value);
}

/// Implementação sobre uma box do Hive.
class HiveSettingsStore implements SettingsStore {
  HiveSettingsStore(this._box);

  final Box<dynamic> _box;

  @override
  Object? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, Object value) => _box.put(key, value);
}

/// Implementação em memória, usada nos testes.
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([Map<String, Object>? seed])
    : _values = <String, Object>{...?seed};

  final Map<String, Object> _values;

  @override
  Object? read(String key) => _values[key];

  @override
  Future<void> write(String key, Object value) async => _values[key] = value;
}