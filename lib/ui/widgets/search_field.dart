import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../state/scope.dart';

/// Campo de busca arredondado e translúcido, ligado a [NotesScope].
///
/// A API é um [StatelessWidget], mas o [TextEditingController] precisa de
/// ciclo de vida: por isso o estado real mora em [_SearchInput], um widget
/// privado e sem const superficial. Sincronizar o texto no
/// `didChangeDependencies` cobre `clearFilters()` vindo de fora (botão
/// "Limpar filtros") sem pedir foco — o campo só é atualizado quando o valor
/// do controlador realmente diverge do texto digitado.
class SearchField extends StatelessWidget {
  const SearchField({super.key});

  @override
  Widget build(BuildContext context) => const _SearchInput();
}

class _SearchInput extends StatefulWidget {
  const _SearchInput();

  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'busca de notas');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String query = NotesScope.of(context).query;
    if (query == _text.text) return;
    // Adiado para o próximo quadro: mexer no controller durante o build
    // marcaria o EditableField como sujo e quebraria o quadro.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || query == _text.text) return;
      _text.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    NotesScope.of(context).setQuery('');
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final String query = NotesScope.of(context).query;
    final bool hasText = query.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: scheme.surface.withValues(alpha: isDark ? 0.34 : 0.66),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: hasText
                      ? scheme.primary
                      : AppPalette.muted(theme.brightness),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  onChanged: NotesScope.of(context).setQuery,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _focus.unfocus(),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: 'Buscar notas…',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.muted(theme.brightness),
                    ),
                  ),
                ),
              ),
              // Some por opacidade: o layout não muda ao limpar a busca.
              AnimatedOpacity(
                opacity: hasText ? 1 : 0,
                duration: animate
                    ? const Duration(milliseconds: 180)
                    : Duration.zero,
                child: IgnorePointer(
                  ignoring: !hasText,
                  child: IconButton(
                    onPressed: _clear,
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close_rounded, size: 19),
                    color: AppPalette.muted(theme.brightness),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
