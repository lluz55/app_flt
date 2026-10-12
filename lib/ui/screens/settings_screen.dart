import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../state/notes_controller.dart';
import '../../state/scope.dart';
import '../../state/settings_controller.dart';
import '../widgets/glass_card.dart';

/// Preferências do app: aparência, densidade da lista e informações do app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Versão injetada em tempo de build; o padrão cobre `flutter run` local.
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const double _maxColumnWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverAppBar(floating: true, title: Text('Ajustes')),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxColumnWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const <Widget>[
                      _AppearanceSection(),
                      SizedBox(height: 16),
                      _ListSection(),
                      SizedBox(height: 16),
                      _AboutSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Persiste uma preferência e avisa quando a gravação falha.
///
/// A escolha já vale na sessão (o controller notifica antes de escrever), mas
/// sem persistir ela se perde no próximo reinício — e o usuário precisa saber
/// disso em vez de achar que o tema ficou salvo.
Future<void> _save(BuildContext context, Future<bool> Function() write) async {
  // O messenger é resolvido antes do `await`: depois dele o `context` já pode
  // ter saído da árvore, e a tela de ajustes pode ter sido fechada.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  if (await write()) return;
  if (!messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Não foi possível salvar a preferência. Tente de novo.'),
      ),
    );
}

/// Bloco "Aparência": tema do sistema, claro ou escuro.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = SettingsScope.of(context);
    final ThemeData theme = Theme.of(context);

    return _Section(
      icon: Icons.palette_outlined,
      title: 'Aparência',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Escolha como o Anotador se adapta à sua tela.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.muted(theme.brightness),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            // Sem ícones e com padding enxuto: os três segmentos com ícone
            // estouravam ~4px numa tela de 430px.
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              visualDensity: const VisualDensity(horizontal: -2, vertical: 0),
              // Sem contorno lateral, a faixa selecionada encostava no contorno
              // externo do controle e o comia — a borda de 1px sumia de um lado.
              side: WidgetStatePropertyAll<BorderSide>(BorderSide.none),
              // A seleção usa as cores do esquema, não um roxo fixo: assim ela acompanha
              // o acento de cada tema (#CBB8FE no escuro, violeta no claro) em
              // vez de introduzir um tom que não existe em nenhuma outra tela.
              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => states.contains(WidgetState.selected)
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => states.contains(WidgetState.selected)
                    ? theme.colorScheme.onPrimary
                    : AppPalette.muted(theme.brightness),
              ),
            ),
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('Sistema'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Claro'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Escuro'),
              ),
            ],
            selected: <ThemeMode>{settings.themeMode},
            onSelectionChanged: (Set<ThemeMode> selection) {
              unawaited(_save(context, () => settings.setThemeMode(selection.first)));
            },
          ),
        ],
      ),
    );
  }
}

/// Bloco "Lista": densidade dos cartões.
class _ListSection extends StatelessWidget {
  const _ListSection();

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = SettingsScope.of(context);
    final bool compact = settings.compactMode;

    return _Section(
      icon: Icons.view_list_rounded,
      title: 'Lista',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: compact,
        onChanged: (bool value) => unawaited(_save(context, () => settings.setCompactMode(value))),
        title: const Text('Modo compacto'),
        subtitle: Text(
          'Cartões menores, com mais notas visíveis por tela.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppPalette.muted(Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }
}

/// Bloco "Sobre": identidade do app, origem dos dados e números atuais.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final NotesController notes = NotesScope.of(context);
    final ThemeData theme = Theme.of(context);
    final Color muted = AppPalette.muted(theme.brightness);
    final int noteCount = notes.activeCount;
    final int tagCount = notes.allTags.length;

    return _Section(
      icon: Icons.info_outline_rounded,
      title: 'Sobre',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      theme.colorScheme.primary,
                      AppPalette.fuchsia,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.sticky_note_2_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Anotador',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'Versão ${SettingsScreen.version}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Suas notas ficam salvas apenas neste dispositivo, em um banco '
            'local (Hive). Não existe conta, login nem sincronização na '
            'nuvem: nada do que você escreve sai do aparelho.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Stat(
                icon: Icons.sticky_note_2_outlined,
                label: noteCount == 1 ? '1 nota ativa' : '$noteCount notas ativas',
              ),
              _Stat(
                icon: Icons.sell_outlined,
                label: tagCount == 1 ? '1 tag' : '$tagCount tags',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cartão de vidro com cabeçalho (ícone + título) e conteúdo.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GlassCard(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Selo com um número: notas ativas, tags.
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}