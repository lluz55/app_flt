import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';

/// Estado vazio de uma lista: selo de ícone, título, mensagem e ação opcional.
///
/// O conteúdo é rolável e centrado dentro da altura disponível, então o mesmo
/// widget serve tanto para o resto de uma lista vazia quanto para o centro de
/// uma tela inteira.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A ação só existe quando há rótulo e callback juntos.
  bool get _hasAction => onAction != null && (actionLabel?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    final TextTheme text = theme.textTheme;

    // Sem `LayoutBuilder`: este widget também é usado como filho de
    // `SliverFillRemaining(hasScrollBody: false)`, que pede dimensões
    // intrínsecas ao filho — e `LayoutBuilder` não sabe responder a isso.
    // A centralização vertical vem do próprio `SliverFillRemaining`; o
    // `minHeight` fixo só evita o estado colado no topo em viewports baixos.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 280),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _IconBadge(icon: icon, brightness: brightness),
                const SizedBox(height: 22),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: AppPalette.muted(brightness),
                    ),
                  ),
                ],
                if (_hasAction) ...<Widget>[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo circular com gradiente da paleta: dá presença ao ícone sem competir
/// com o texto, que fica sempre no contraste do tema.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.brightness});

  final IconData icon;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final bool isDark = brightness == Brightness.dark;
    final Color border = isDark
        ? const Color(0x4DFFFFFF)
        : const Color(0x337C4DFF);

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppPalette.violet.withValues(alpha: isDark ? 0.38 : 0.20),
            AppPalette.cyan.withValues(alpha: isDark ? 0.26 : 0.14),
          ],
        ),
        border: Border.all(color: border, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppPalette.violet.withValues(alpha: isDark ? 0.30 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(icon, size: 42, color: AppPalette.onSurface(brightness)),
    );
  }
}
