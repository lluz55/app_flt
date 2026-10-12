import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../state/scope.dart';
import '../widgets/aurora_background.dart';
import 'editor_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';

/// Destino do shell: rótulo em pt-BR e o par de ícones do destino.
typedef _Destination = ({
  String label,
  IconData icon,
  IconData selectedIcon,
});

const List<_Destination> _destinations = <_Destination>[
  (
    label: 'Notas',
    icon: Icons.edit_note_rounded,
    selectedIcon: Icons.auto_awesome_rounded,
  ),
  (
    label: 'Lixeira',
    icon: Icons.delete_outline_rounded,
    selectedIcon: Icons.delete_outline_rounded,
  ),
  (label: 'Ajustes', icon: Icons.tune_rounded, selectedIcon: Icons.tune_rounded),
];

/// Abaixo desta largura a navegação fica na barra inferior; acima dela vira
/// rail lateral, e a partir de [_extendedBreakpoint] o rail ganha rótulos.
const double _wideBreakpoint = 900;
const double _extendedBreakpoint = 1200;

/// Duração única das animações do shell.
const Duration _transitionDuration = Duration(milliseconds: 280);

/// Moldura do app: navegação + as três abas dentro da aurora.
///
/// O shell é a `home` da `MaterialApp`, então existe **um único** [Navigator]:
/// as abas vivem num [IndexedStack] e o editor é empilhado por cima. Um
/// `Navigator` por aba quebraria esse empilhamento.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  void _createNote() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A largura vem do `MediaQuery`, e não de um `LayoutBuilder`: este shell é a
    // `home` da `MaterialApp` e ocupa a tela inteira, então o `LayoutBuilder`
    // seria pai direto do `Scaffold` — e a máquina do FAB acaba pedindo
    // dimensões intrínsecas, que `LayoutBuilder` não sabe responder.
    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= _wideBreakpoint;
    final bool extended = width >= _extendedBreakpoint;

    // Sem chave por índice de propósito: recriá-la derrubaria a posição
    // do scroll e o estado de cada aba ao trocar de destino.
    final Widget tabs = IndexedStack(
      index: _index,
      children: const <Widget>[
        NotesScreen(),
        TrashScreen(),
        SettingsScreen(),
      ],
    );

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: wide
            ? Row(
                children: <Widget>[
                  _rail(extended: extended),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
                  ),
                  Expanded(child: tabs),
                ],
              )
            : tabs,
        bottomNavigationBar: wide ? null : _bar(),
        floatingActionButton: _fabGate(extended: wide),
      ),
    );
  }

  Widget _rail({required bool extended}) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _select,
      extended: extended,
      minWidth: 76,
      minExtendedWidth: 208,
      groupAlignment: -1,
      // Translúcido de verdade: com `alpha: 0.5` a barra virava uma placa
      // quase opaca e, no tema claro, a emenda com o conteúdo aparecia como
      // um degrau de 1px. Bem mais leve, a aurora atravessa sem costura.
      backgroundColor: extended
          ? AppPalette.surface(theme.brightness).withValues(alpha: 0.18)
          : Colors.transparent,
      indicatorColor: theme.colorScheme.primary.withValues(
        alpha: isDark ? 0.30 : 0.16,
      ),
      useIndicator: true,
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
      unselectedIconTheme: IconThemeData(
        color: AppPalette.muted(theme.brightness),
      ),
      selectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
        color: AppPalette.muted(theme.brightness),
      ),
      destinations: <NavigationRailDestination>[
        for (final _Destination destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }

  Widget _bar() {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: <Widget>[
        for (final _Destination destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }

  /// O FAB pertence à aba Notas: nas outras duas ele encolhe e some, para não
  /// ficar pairando sobre a lixeira ou os ajustes.
  ///
  /// Ele também some quando a lista está vazia: o estado vazio já traz o seu
  /// próprio "Criar primeira nota", e dois botões para a mesma ação no mesmo
  /// ponto de atenção é só competição.
  Widget _fabGate({required bool extended}) {
    final bool show = _index == 0 && NotesScope.of(context).notes.isNotEmpty;
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final Duration duration =
        animate ? _transitionDuration : Duration.zero;

    final Widget fab = extended
        ? FloatingActionButton.extended(
            onPressed: _createNote,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova nota'),
          )
        : FloatingActionButton(
            onPressed: _createNote,
            tooltip: 'Nova nota',
            child: const Icon(Icons.add_rounded),
          );

    // `show` decide escala e opacidade, e não um retorno antecipado: com
    // `SizedBox.shrink()` no lugar o botão sumia de um golpe ao trocar de aba e
    // as duas animações nunca tinham o que animar.
    return AnimatedScale(
      scale: show ? 1 : 0.2,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        // O Scaffold reserva 16px para o FAB, mas o conteúdo usa 20: sem estes
        // 4px o botão fica 6px mais para dentro que os cartões, e o desalinhamento
        // aparecia em todas as capturas com FAB.
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          // Mesma técnica dos cartões de vidro: gradiente vertical atrás do
          // botão, em vez de `BoxShadow`. Com `blurRadius` a sombra saía como
          // duas faixas chapadas de 8px com degrau duro embaixo do botão — o
          // defeito mais conspícuo das telas que têm FAB. `Clip.none` é o que
          // deixa a faixa passar da borda do `Stack`.
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                top: 0,
                bottom: -_fabShadowSpread,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        _fabShadow(Theme.of(context)),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 0.80, 1.0],
                    ),
                  ),
                ),
              ),
              fab,
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantos pixels a faixa de sombra do FAB avança para baixo do botão.
const double _fabShadowSpread = 14;

/// Cor da faixa de sombra do FAB.
///
/// Precisa ser da paleta: com a sombra padrão do Material, o contorno saía em
/// preto puro — a única cor fora da paleta do app.
Color _fabShadow(ThemeData theme) => theme.brightness == Brightness.dark
    ? Colors.white.withValues(alpha: 0.26)
    : const Color(0xFF2B1B45).withValues(alpha: 0.26);