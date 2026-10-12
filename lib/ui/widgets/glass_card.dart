

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Cartão translúcido: desfoca o que está atrás, tinge e desenha uma borda
/// de 1px com leve gradiente.
///
/// O [BackdropFilter] é caro, então o [child] deve ser pequeno e o cartão não
/// deve ser aninhado dentro de outro cartão equivalente.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.onTap,
    this.tint,
    this.blur = 18,
    this.elevated = true,
  });

  final Widget child;

  /// Espaçamento interno entre a borda e [child].
  final EdgeInsetsGeometry padding;

  /// Raio do cartão; também define o recorte da borda e do ripple.
  final double borderRadius;

  /// Quando informado, o cartão fica clicável e mostra o ripple recortado.
  final VoidCallback? onTap;

  /// Cor base da camada translúcida. Padrão: a superfície do tema.
  final Color? tint;

  /// Raio do desfoque, em pixels.
  final double blur;

  /// `false` deixa o cartão plano, sem sombra.
  final bool elevated;

  /// Quantos pixels a faixa de sombra avança para baixo do cartão.
  static const double _shadowSpread = 18;

  /// Quantos pixels a faixa de sombra avança para baixo do cartão.


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color base = tint ?? theme.colorScheme.surface;

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // Leve brilho no topo: dá volume ao vidro sem escurecer o texto.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(
              base,
              Colors.white,
              isDark ? 0.14 : 0.55,
            )!.withValues(alpha: isDark ? 0.62 : 0.70),
            base.withValues(alpha: isDark ? 0.46 : 0.58),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.16),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: content,
        ),
      );
    }

    final Widget glass = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Stack(
          children: <Widget>[
            content,
            Positioned.fill(
              child: IgnorePointer(child: _GradientBorder(radius: radius)),
            ),
          ],
        ),
      ),
    );

    if (!elevated) return glass;

    // A sombra é pintada à mão, como um gradiente vertical atrás do cartão.
    //
    // Motivo medido, não presumido: um `BoxShadow` com `blurRadius` **não produz
    // sombra suave** no renderer de golden deste projeto. Amostrando os pixels
    // das capturas, o mesmo `BoxShadow` dá dois resultados: no cartão sai como
    // uma laje chapada de ~13px com degrau de 1px embaixo da borda (lia como
    // uma segunda aba colada), e no FAB simplesmente não aparece — a transição
    // do fundo para o botão é de 1px, sem nenhuma queda.
    //
    // Um gradiente é suave por construção e não depende de desfoque de caixa.
    // Dois detalhes fazem ele funcionar: o `Clip.none`, porque `Stack` recorta
    // em `hardEdge` por padrão e cortaria a faixa exatamente na borda do
    // cartão; e o `bottom` negativo, que estende a faixa para baixo do cartão.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          top: 0,
          bottom: -_shadowSpread,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : const Color(0xFF3B2A6B).withValues(alpha: 0.20),
                  Colors.transparent,
                ],
                stops: const <double>[0.0, 0.80, 1.0],
              ),
            ),
          ),
        ),
        glass,
      ],
    );
  }
}

/// Borda de 1px pintada com um gradiente da paleta.
///
/// `BoxDecoration` não aceita borda com gradiente, então o anel é desenhado
/// em branco e recortado pelo gradiente via [ShaderMask].
class _GradientBorder extends StatelessWidget {
  const _GradientBorder({required this.radius});

  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors = isDark
        ? const <Color>[Color(0x66FFFFFF), Color(0x14FFFFFF)]
        : const <Color>[Color(0x99FFFFFF), Color(0x1F1A1523)];

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(bounds),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }
}
