import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../state/notes_controller.dart';
import '../../state/scope.dart';
import 'fade_right_edge.dart';

/// Filtro por tags: rolagem horizontal de `ChoiceChip`s sobre [allTags].
///
/// Cada tag recebe uma cor estável derivada do próprio texto, para o filtro
/// parecer parte da paleta "aurora" e não uma fileira de botões iguais. A barra
/// inteira some (altura + opacidade) quando não há tag alguma.
class TagFilterBar extends StatelessWidget {
  const TagFilterBar({super.key});

  /// Índice de cor determinístico para [tag]: soma dos code units módulo 997,
  /// o que dá a mesma cor para a mesma tag em todas as execuções.
  static Color colorFor(String tag) {
    var sum = 0;
    for (final int unit in tag.codeUnits) {
      sum = (sum + unit) % 997;
    }
    return AppPalette.noteColor(sum);
  }

  @override
  Widget build(BuildContext context) {
    final NotesController controller = NotesScope.of(context);
    final List<String> tags = controller.allTags;
    final Set<String> active = controller.activeTags.toSet();
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final Duration duration =
        animate ? const Duration(milliseconds: 260) : Duration.zero;
    final bool visible = tags.isNotEmpty;

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: visible
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: FadeRightEdge(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (int i = 0; i < tags.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 8),
                          _TagChip(
                            tag: tags[i],
                            selected: active.contains(tags[i]),
                            onSelected: () => controller.toggleTag(tags[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

/// Chip de tag: a seleção troca fundo, borda e peso do rótulo — a cor viva
/// vem do preenchimento, não apenas do check.
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.selected,
    required this.onSelected,
  });

  final String tag;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = TagFilterBar.colorFor(tag);

    return ChoiceChip(
      label: Text(tag),
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: DecoratedBox(
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 8),
      ),
      showCheckmark: selected,
      checkmarkColor: accent,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.26 : 0.6),
      selectedColor: accent.withValues(alpha: isDark ? 0.32 : 0.18),
      side: BorderSide(
        color: selected
            ? accent
            : scheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.8),
        width: selected ? 1.6 : 1,
      ),
      // Rótulo no contraste do tema: a cor viva fica no fundo e na borda,
      // garantindo leitura nos dois brilhos.
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}