import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;

import '../../core/theme/palette.dart';
import '../../data/note.dart';
import '../../state/notes_controller.dart';
import '../../state/scope.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_card.dart';
import '../widgets/search_field.dart';
import '../widgets/tag_filter_bar.dart';
import 'editor_screen.dart';

/// Lista principal: cabeçalho recolhível, busca, filtro de tags e as notas.
///
/// A escolha entre grade e coluna usa o `crossAxisExtent` do
/// [SliverLayoutBuilder] — a largura que sobra depois das margens — e nunca a
/// tamanho da janela, para o layout reagir também a painéis divididos.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  /// Largura de conteúdo a partir da qual as notas viram grade.
  static const double gridBreakpoint = 700;

  /// Largura de conteúdo a partir da qual a grade ganha uma terceira coluna.
  static const double wideGridBreakpoint = 1100;

  static const double _gutter = 20;

  @override
  Widget build(BuildContext context) {
    final NotesController controller = NotesScope.of(context);
    final bool compact = SettingsScope.of(context).compactMode;
    final List<Note> notes = controller.notes;
    // Capturado aqui: o `SnackBar` de "Desfazer" continua válido mesmo se o
    // cartão sair da árvore no meio da animação de dispensa.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          expandedHeight: 148,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: _NotesHeader(subtitle: _subtitle(controller, notes)),
        ),
        const SliverToBoxAdapter(child: SearchField()),
        const SliverToBoxAdapter(child: TagFilterBar()),
        // Carregando e lista vazia são decididos *fora* do `SliverLayoutBuilder`:
        // ele é internamente um `LayoutBuilder`, e um `SliverFillRemaining`
        // dentro dele pediria dimensões intrínsecas — que `LayoutBuilder` não
        // sabe responder.
        if (controller.isLoading && notes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (notes.isEmpty && controller.lastError != null)
          // A carga falhou, não é ausência de notas. Sem esta distinção o app
          // mostrava "Sua primeira nota começa aqui" como se o banco estivesse
          // vazio, e as notas do usuário só reapareceriam no próximo reinício.
          SliverFillRemaining(
            hasScrollBody: false,
            child: _LoadFailed(onRetry: () => controller.load()),
          )
        else if (notes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, controller),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 4, _gutter, 0),
            sliver: SliverLayoutBuilder(
              builder: (BuildContext context, SliverConstraints constraints) {
                final int columns = _columnsFor(constraints.crossAxisExtent);
                if (columns == 1) {
                  return _list(context, controller, notes, compact, messenger);
                }
                return _grid(
                  context,
                  controller,
                  notes,
                  compact,
                  messenger,
                  columns,
                );
              },
            ),
          ),
        // Folga para o FAB não cobrir o último cartão.
        SliverToBoxAdapter(child: SizedBox(height: compact ? 84 : 104)),
      ],
    );
  }

  /// "12 notas" ou, filtrando, "3 de 12 notas".
  static String _subtitle(NotesController controller, List<Note> notes) {
    final int total = controller.activeCount;
    final String noun = total == 1 ? 'nota' : 'notas';
    if (controller.isFiltering && notes.length != total) {
      return '${notes.length} de $total $noun';
    }
    return '$total $noun';
  }

  static int _columnsFor(double crossAxisExtent) => switch (crossAxisExtent) {
    >= wideGridBreakpoint => 3,
    >= gridBreakpoint => 2,
    _ => 1,
  };

  Widget _list(
    BuildContext context,
    NotesController controller,
    List<Note> notes,
    bool compact,
    ScaffoldMessengerState messenger,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(context, controller, notes[index], compact, messenger),
        ),
        childCount: notes.length,
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    NotesController controller,
    List<Note> notes,
    bool compact,
    ScaffoldMessengerState messenger,
    int columns,
  ) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        // Altura fixa: a grade não mede o conteúdo, então a folga máxima
        // (título + prévia + rodapé de duas linhas de etiquetas) é fixa aqui.
        mainAxisExtent: compact ? 176 : 232,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) =>
            _card(context, controller, notes[index], compact, messenger),
        childCount: notes.length,
      ),
    );
  }

  Widget _card(
    BuildContext context,
    NotesController controller,
    Note note,
    bool compact,
    ScaffoldMessengerState messenger,
  ) {
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    return Dismissible(
      key: ValueKey<String>('nota-${note.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: 0.35,
      },
      resizeDuration: animate
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      // O gesto é só `endToStart`, mas o Flutter exige `background` não nulo
      // sempre que `secondaryBackground` existe.
      background: const SizedBox.shrink(),
      secondaryBackground: _TrashPanel(title: note.displayTitle),
      // `confirmDismiss` em vez de `onDismissed`: o `Dismissible` se remove da
      // árvore assim que o gesto termina, e se a gravação falhasse depois disso o
      // controller ainda tinha a nota ativa — o rebuild devolvia um
      // `Dismissible` já dispensado, que jogava um `ErrorWidget` na lista e
      // sumia com as notas vizinhas junto. Devolvendo `false`, o cartão volta.
      confirmDismiss: (_) => _sendToTrash(controller, note, messenger),
      child: GestureDetector(
        onLongPress: () => _sendToTrash(controller, note, messenger),
        child: NoteCard(
          note: note,
          compact: compact,
          onTap: () => _openEditor(context, note),
          onTogglePin: () => _togglePin(controller, note, messenger),
          onDelete: () => _sendToTrash(controller, note, messenger),
        ),
      ),
    );
  }

  static void _openEditor(BuildContext context, Note note) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditorScreen(note: note)),
    );
  }

  static void _openEmptyEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
    );
  }

  /// Manda para a lixeira e oferece o caminho de volta.
  ///
  /// Devolve `true` quando a gravação foi confirmada e `false` quando foi
  /// recusada. O `false` é o que o `confirmDismiss` do gesto de arrasto usa para
  // devolver o cartão à lista: sem ele, o `Dismissible` já teria se removido da
  // árvore e a nota continuaria ativa no controller.
  ///
  /// O "foi para a lixeira" só aparece **depois** que o repositório confirma a
  /// gravação: anunciando antes, uma falha silenciosa fazia o cartão sumir da
  /// lista sem explicar por quê.
  static Future<bool> _sendToTrash(
    NotesController controller,
    Note note,
    ScaffoldMessengerState messenger,
  ) async {
    final bool ok = await controller.toggleTrash(note.id);
    messenger.hideCurrentSnackBar();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível mover a nota para a lixeira. Tente de novo.'),
        ),
      );
      return false;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('“${note.displayTitle}” foi para a lixeira.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _undoTrash(controller, note, messenger),
        ),
      ),
    );
    return true;
  }

  /// Desfaz a dispensa, com o mesmo tratamento de falha da lixeira: se a
  /// gravação não confirmar, a nota continua na lixeira e o usuário precisa
  /// saber disso — senão ele fica esperando um retorno que não aconteceu.
  static Future<void> _undoTrash(
    NotesController controller,
    Note note,
    ScaffoldMessengerState messenger,
  ) async {
    if (await controller.toggleTrash(note.id)) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Não foi possível devolver a nota para a lista. '
              'Tente de novo.'),
        ),
      );
  }

  /// Fixa ou desfixa. Sem isto, uma falha de gravação deixaria o alfinete
  /// paradoxalmente desligado e a interface sem nenhuma explicação.
  static Future<void> _togglePin(
    NotesController controller,
    Note note,
    ScaffoldMessengerState messenger,
  ) async {
    if (await controller.togglePin(note.id)) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar a nota. Tente de novo.'),
        ),
      );
  }

  Widget _emptyState(BuildContext context, NotesController controller) {
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final Duration duration =
        animate ? const Duration(milliseconds: 300) : Duration.zero;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: controller.isFiltering
          ? EmptyState(
              key: const ValueKey<String>('sem-resultados'),
              icon: Icons.search_off_rounded,
              title: 'Nenhuma nota encontrada',
              message:
                  'Nada corresponde à busca ou às tags ativas. Ajuste os filtros '
                  'para ver as notas de novo.',
              actionLabel: 'Limpar filtros',
              onAction: controller.clearFilters,
            )
          : EmptyState(
              key: const ValueKey<String>('sem-notas'),
              icon: Icons.auto_awesome_rounded,
              title: 'Sua primeira nota começa aqui',
              message:
                  'O Anotador guarda tudo no seu aparelho. Anote uma ideia, '
                  'uma lista, um lembrete — comece escrevendo.',
              actionLabel: 'Criar primeira nota',
              onAction: () => _openEmptyEditor(context),
            ),
    );
  }
}

/// Falha ao carregar as notas.
///
/// Diferente do estado vazio de verdade: aqui existe algo no banco que não pôde
/// ser lido, e a diferença é o que separa "crie sua primeira nota" de "tente de
/// novo". Sem ela o app mentiria — mostrando um banco vazio para dados que
/// continuam no dispositivo.
class _LoadFailed extends StatefulWidget {
  const _LoadFailed({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_LoadFailed> createState() => _LoadFailedState();
}

class _LoadFailedState extends State<_LoadFailed> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await widget.onRetry();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppPalette.muted(theme.brightness),
            ),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar suas notas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Nada foi apagado. Tente de novo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppPalette.muted(theme.brightness),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: _busy ? null : _retry,
              child: Text(_busy ? 'Tentando…' : 'Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fundo da dispensa: leitura imediata de "vai para a lixeira".
///
/// O fundo é **opaco** por opção, não por estética: o gradiente anterior,
/// translúcido (coral 0,75 → fúcsia 0,45) deixava a aurora clara aparecer por
/// baixo e o branco sobre coral pastel media só ~2,3:1 — bem abaixo dos 4,5:1
/// que a WCAG AA exige para texto.
///
/// Aqui o painel assenta sobre `0xFF2B0A18` (opaco) e o gradiente escuro vai
/// por cima. O pior ponto do gradiente é a ponta coral, o mais claro, com
/// luminância relativa 0,1142: o branco sobre ele dá **6,39:1** (≥ 4,5:1 para
/// texto e ≥ 3:1 exigido para o ícone, que usa a mesma cor). Como nada é
/// translúcido, o contraste é idêntico nos dois temas e independe do que a
/// aurora estiver fazendo atrás.
class _TrashPanel extends StatelessWidget {
  const _TrashPanel({required this.title});

  final String title;

  /// Base opaca do painel.
  static const Color _base = Color(0xFF2B0A18);

  /// Ponta coral do gradiente — o tom mais claro e, portanto, o pior caso.
  static const Color _coral = Color(0xFFAE3226);

  /// Ponta fúcsia do gradiente.
  static const Color _fuchsia = Color(0xFF4C0F45);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _base,
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: const <Color>[_coral, _fuchsia],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Mover para a lixeira',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho recolhível com a marca "Anotador" e o total de notas.
///
/// O [LayoutBuilder] recebe a altura corrente do sliver: `progress` vai de 1
/// (expandido) a 0 (colapsado na barra) e comanda o cross-fade entre a marca
/// grande e a compacta, além do véu que garante legibilidade na barra fixa.
class _NotesHeader extends StatelessWidget {
  const _NotesHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double top = MediaQuery.paddingOf(context).top;
    final double collapsed = kToolbarHeight + top;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double range = constraints.maxHeight - collapsed;
        // 1 = expandido, 0 = colapsado na barra.
        final double progress = range <= 0
            ? 0
            : ((constraints.maxHeight - collapsed) / range).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Véu que aparece quando o cabeçalho colapsa.
            Opacity(
              opacity: 1 - progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppPalette.surface(theme.brightness).withValues(alpha: 0.9),
                      AppPalette.surface(theme.brightness)
                          .withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                    stops: const <double>[0, 0.6, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Opacity(
                  opacity: progress,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const _WordmarkBadge(),
                          const SizedBox(width: 10),
                          // `Flexible`: em telas estreitas (≈360px) o título em
                          // `displaySmall` somava o badge e estourava a linha.
                          Flexible(
                            child: Text(
                              'Anotador',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppPalette.muted(theme.brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: top + (kToolbarHeight - 22) / 2,
              child: Opacity(
                opacity: 1 - progress,
                child: Text(
                  'Anotador',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Marca quadrada com gradiente da paleta ao lado do nome.
class _WordmarkBadge extends StatelessWidget {
  const _WordmarkBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppPalette.violet, AppPalette.fuchsia],
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 19,
        color: Colors.white,
      ),
    );
  }
}