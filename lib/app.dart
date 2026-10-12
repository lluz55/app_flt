import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'state/notes_controller.dart';
import 'state/settings_controller.dart';
import 'state/scope.dart';
import 'ui/screens/home_shell.dart';

/// Raiz do Anotador.
///
/// Publica os controladores na árvore via [NotesScope] e [SettingsScope] para
/// que qualquer widget abaixo possa observá-los, e reconstrói a `MaterialApp`
/// quando o tema muda.
class AnotadorApp extends StatelessWidget {
  const AnotadorApp({
    super.key,
    required this.notesController,
    required this.settingsController,
  });

  final NotesController notesController;
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return NotesScope(
      controller: notesController,
      child: SettingsScope(
        controller: settingsController,
        child: const _ThemedApp(),
      ),
    );
  }
}

/// `MaterialApp` que reage ao [ThemeMode] persistido.
///
/// Chamar [SettingsScope.of] dentro do `build` é o que registra a dependência:
/// sem isso a `MaterialApp` não seria reconstruída quando o tema mudasse.
class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    return MaterialApp(
      title: 'Anotador',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const HomeShell(),
    );
  }
}