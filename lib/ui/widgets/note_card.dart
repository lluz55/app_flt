import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../data/note.dart';
import 'glass_card.dart';

/// Cartão de nota: cor de identidade, título, prévia e metadados.
///
/// **Esquema do [Hero]:** `note-card-<id da nota>`. Use [heroTag] para gerar a
/// etiqueta em vez de escrevê-la à mão — é o que permite ao editor animar a
/// transição a partir da lista.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    this.compact = false,
  });

  /// Máximo de etiquetas desenhadas antes de virar "+N".
  static const int maxVisibleTags = 3;

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  /// Densidade reduzida: menos padding e prévia de uma linha só.
  final bool compact;

  /// Etiqueta estável do [Hero]: `note-card-<id>`.
  static String heroTag(String noteId) => 'note-card-$noteId';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = AppPalette.noteColor(note.colorIndex);
    final bool pinned = note.pinned;
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final Duration duration = animate
        ? const Duration(milliseconds: 220)
        : Duration.zero;

    return Hero(
      tag: heroTag(note.id),
      child: GlassCard(
        onTap: onTap,
        borderRadius: 22,
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          compact ? 12 : 16,
          compact ? 6 : 8,
          compact ? 10 : 14,
        ),
        // Fixadas ganham um lavado na própria cor; soltas ficam neutras.
        tint: pinned ? Color.lerp(scheme.surface, accent, 0.12) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _TitleRow(
                      note: note,
                      accent: accent,
                      brightness: brightness,
                      duration: duration,
                      onTogglePin: onTogglePin,
                      onDelete: onDelete,
                    ),
                    if (note.preview.isNotEmpty) ...<Widget>[
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        note.preview,
                        maxLines: compact ? 1 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.78),
                          height: compact ? 1.3 : 1.45,
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? 8 : 12),
                    _Footer(note: note, accent: accent, brightness: brightness),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título + favoritar + excluir.
///
/// O bloco do título é fundido em um único nó de semântica para que o leitor de
/// tela anuncie "Nota fixada" junto do título, sem os botões embutidos.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.note,
    required this.accent,
    required this.brightness,
    required this.duration,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Note note;
  final Color accent;
  final Brightness brightness;
  final Duration duration;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = AppPalette.muted(brightness);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (note.pinned) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 6),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 15,
                      color: accent,
                      semanticLabel: 'Nota fixada',
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    note.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onTogglePin,
          tooltip: note.pinned ? 'Desafixar nota' : 'Fixar nota',
          color: note.pinned ? accent : muted,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: AnimatedScale(
            scale: note.pinned ? 1.12 : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: Icon(
              note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 19,
            ),
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Mover para a lixeira',
          color: muted,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.delete_outline_rounded, size: 19),
        ),
      ],
    );
  }
}

/// Rodapé: data relativa, contagem de palavras e etiquetas.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.note,
    required this.accent,
    required this.brightness,
  });

  final Note note;
  final Color accent;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final int visible = note.tags.take(NoteCard.maxVisibleTags).length;
    final int hidden = note.tags.length - visible;
    final String words =
        '${note.wordCount} ${note.wordCount == 1 ? 'palavra' : 'palavras'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // `Wrap` em vez de `Row`: datas longas nunca estouram a largura.
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: <Widget>[
            _MetaItem(
              icon: Icons.schedule_rounded,
              text: DateX.relative(note.updatedAt),
            ),
            _MetaItem(icon: Icons.notes_rounded, text: words),
          ],
        ),
        if (note.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String tag in note.tags.take(NoteCard.maxVisibleTags))
                _TagPill(tag: tag, accent: accent, brightness: brightness),
              if (hidden > 0)
                _TagPill(
                  tag: '+$hidden',
                  accent: accent,
                  brightness: brightness,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ícone + texto de metadado, mantidos juntos numa célula do [Wrap].
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = AppPalette.muted(theme.brightness);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: muted),
        const SizedBox(width: 5),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

/// Pílula de etiqueta na cor da nota; o texto puxa o acento na direção da cor
/// de texto do tema, mantendo contraste nos dois brilhos.
class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.tag,
    required this.accent,
    required this.brightness,
  });

  final String tag;
  final Color accent;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color label = Color.lerp(accent, theme.colorScheme.onSurface, 0.45)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: brightness == Brightness.dark ? 0.18 : 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: label,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
