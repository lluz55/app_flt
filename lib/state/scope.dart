import 'package:flutter/widgets.dart';

import 'notes_controller.dart';
import 'settings_controller.dart';

/// Disponibiliza o [NotesController] para a árvore de widgets.
class NotesScope extends InheritedNotifier<NotesController> {
  const NotesScope({
    super.key,
    required NotesController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Registra dependência: quem chama reconstrói a cada `notifyListeners()`.
  static NotesController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NotesScope>();
    assert(scope?.notifier != null, 'NotesScope não encontrado acima deste contexto.');
    return scope!.notifier!;
  }
}

/// Disponibiliza o [SettingsController] para a árvore de widgets.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Registra dependência: quem chama reconstrói a cada `notifyListeners()`.
  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(
      scope?.notifier != null,
      'SettingsScope não encontrado acima deste contexto.',
    );
    return scope!.notifier!;
  }
}