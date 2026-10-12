import 'package:flutter/material.dart';

/// Esmaece o conteúdo na borda direita, sinalizando que a faixa rola.
///
/// Sem isso a última etiqueta ou o último seletor de cor aparece cortado por
/// um corte duro, que se lê como defeito de layout em vez de "tem mais".
/// Em temas claros o contraste do fundo é baixo, então o efeito é sutil de
/// propósito — ele existe para não quebrar, não para chamar atenção.
class FadeRightEdge extends StatelessWidget {
  const FadeRightEdge({
    super.key,
    required this.child,
    this.fadeFraction = 0.12,
  });

  final Widget child;

  /// Fração da largura em que o esmaecimento acontece.
  final double fadeFraction;

  @override
  Widget build(BuildContext context) {
    final double stop = (1 - fadeFraction).clamp(0.0, 1.0);
    return ShaderMask(
      shaderCallback: (Rect bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: <double>[0.0, stop, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
