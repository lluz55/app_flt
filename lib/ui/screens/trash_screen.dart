import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../data/note.dart';
import '../../state/notes_controller.dart';
import '../../state/scope.dart';
import '../widgets/glass_card.dart';

/// Notas excluídas: dá para restaurar ou apagar para sempre.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  /// Measure da coluna em telas largas.
  static const double _maxColumnWidth = 720;

  @override
  Widget build(BuildContext context) {
    final NotesController notes = NotesScope.of(context);
    final List<Note> items = notes.trash;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            title: const Text('Lixeira'),
            actions: <Widget>[
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Esvaziar lixeira',
                  onPressed: () => _confirmEmptyTrash(context, notes, items.length),
                ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxColumnWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    items.isEmpty
                        ? 'Nada guardado por aqui.'
                        : '${_plural(items.length, 'nota guardada', 'notas guardadas')} — saem do dispositivo quando você esvazia a lixeira.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.muted(Theme.of(context).brightness),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _EmptyTrash())
          else
            SliverPadding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 32,
              ),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int _) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final Note note = items[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxColumnWidth),
                      child: _TrashRow(
                        note: note,
                        onRestore: () => _restore(context, notes, note),
                        onDelete: () => _confirmDelete(context, notes, note),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Ações ------------------------------------------------------------------

  static Future<void> _restore(
    BuildContext context,
    NotesController notes,
    Note note,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // Só confirma depois que o repositório aceitou a gravação: restaurar sem
    // erro aparente deixaria a nota na lixeira sem explicação.
    final bool ok = await notes.restore(note.id);
    if (!ok) {
      _reportError(messenger, 'Não foi possível restaurar a nota. Tente de novo.');
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Nota restaurada'),
        action: SnackBarAction(
          label: 'Desfazer',
          // Devolve a nota para a lixeira. O retorno é verificado: um
          // "desfazer" que falha em silêncio enganaria o usuário.
          onPressed: () => unawaited(
            notes.toggleTrash(note.id).then((bool undone) {
              if (!undone) {
                _reportError(messenger, 'Não foi possível voltar a nota para a lixeira.');
              }
            }),
          ),
        ),
      ),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    NotesController notes,
    Note note,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Excluir esta nota?'),
          content: Text(
            '“${note.displayTitle}” será apagada para sempre. Não dá para desfazer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    if (answer != true) return;
    if (!await notes.deleteForever(note.id)) {
      _reportError(messenger, 'Não foi possível excluir a nota. Tente novamente.');
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Nota excluída')));
  }

  static Future<void> _confirmEmptyTrash(
    BuildContext context,
    NotesController notes,
    int count,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final String lost = count == 1
            ? '1 nota será apagada para sempre.'
            : '$count notas serão apagadas para sempre.';
        return AlertDialog(
          title: const Text('Esvaziar a lixeira?'),
          content: Text('$lost Não dá para desfazer.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Esvaziar'),
            ),
          ],
        );
      },
    );
    if (answer != true) return;
    if (!await notes.emptyTrash()) {
      _reportError(messenger, 'Não foi possível esvaziar a lixeira. Tente de novo.');
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('$count ${count == 1 ? 'nota removida' : 'notas removidas'}.')),
    );
  }

  /// Falha de escrita visível: sem ela a pessoa acharia que a exclusão deu
  /// certo enquanto a nota continuava guardada no aparelho.
  static void _reportError(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _plural(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';
}

/// Uma nota na lixeira: título, prévia, data e os dois ações destrutivas.
class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.note,
    required this.onRestore,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = AppPalette.muted(theme.brightness);
    final String preview = note.preview;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      borderRadius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: AppPalette.noteColor(note.colorIndex),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  note.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (preview.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Editada ${DateX.relative(note.updatedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          // `mainAxisSize.min` + `center`: sem isso a Column esticava os dois botões
          // pelas pontas do cartão — um alinhado ao título, outro solto perto do
          // rodapé, o que lia como dois elementos sem relação.
          // Na horizontal, como nos cartões da lista: empilhados, os dois botões ficavam
          // em pontas opostas de um cartão baixo e pareciam não pertencer um ao
          // outro.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.unarchive_outlined),
                tooltip: 'Restaurar nota',
                onPressed: onRestore,
                // 40px em vez dos 48px padrão: o par caberia lado a lado sem
                // espremer o texto em telas de 430px.
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                tooltip: 'Excluir para sempre',
                onPressed: onDelete,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estado vazio: sem botão destrutivo quando não há nada para apagar.
class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = AppPalette.muted(theme.brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 64),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'A lixeira está vazia',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Notas que você exclui ficam aqui até escolher apagá-las para sempre.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}