import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/palette.dart';

/// Fundo "aurora": gradiente base + blobs circulares que derivam lentamente.
///
/// Os blobs usam gradientes radiais (não [BackdropFilter]) para obter bordas
/// suaves sem custo de filtro, e ficam num widget à parte para que o [child]
/// não seja reconstruído a cada quadro.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child, this.animate = true});

  final Widget child;

  /// Quando falso, os blobs ficam parados mesmo se as animações do sistema
  /// estiverem habilitadas.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppPalette.auroraGradient(brightness),
          ),
        ),
        _AuroraBlobs(brightness: brightness, animate: animate),
        child,
      ],
    );
  }
}

/// Configuração de um blob: cor, ponto de partida e escala em relação ao
/// maior lado da tela.
typedef _Blob = ({Color color, Alignment origin, double size, double opacity});

class _AuroraBlobs extends StatefulWidget {
  const _AuroraBlobs({required this.brightness, required this.animate});

  final Brightness brightness;
  final bool animate;

  @override
  State<_AuroraBlobs> createState() => _AuroraBlobsState();
}

class _AuroraBlobsState extends State<_AuroraBlobs>
    with SingleTickerProviderStateMixin {
  /// Período longo e primos entre si para que os blobs nunca sincronizem.
  static const Duration _period = Duration(seconds: 32);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AuroraBlobs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Animar é opt-in: só com [AuroraBackground.animate] e sem a preferência
  /// de sistema "reduzir animações". O controlador é parado nos dois casos.
  void _syncAnimation() {
    final bool active =
        widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (active == _controller.isAnimating) {
      return;
    }
    if (active) {
      _controller.repeat();
      return;
    }
    _controller.stop();
    // Zerar durante o build dispararia setState no AnimatedBuilder; adia.
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _controller.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.brightness == Brightness.dark;
    final List<Color> colors = AppPalette.auroraBlobs(widget.brightness);
    // Cada blob começa em uma "fase" diferente do mesmo ciclo.
    final List<_Blob> blobs = <_Blob>[
      (
        color: colors[0],
        origin: const Alignment(-0.85, -0.75),
        size: 0.62,
        opacity: isDark ? 0.45 : 0.55,
      ),
      (
        color: colors[1],
        origin: const Alignment(0.75, -0.55),
        size: 0.50,
        opacity: isDark ? 0.34 : 0.45,
      ),
      (
        color: colors[2],
        origin: const Alignment(0.55, 0.70),
        size: 0.58,
        opacity: isDark ? 0.30 : 0.40,
      ),
      (
        color: colors[3],
        origin: const Alignment(-0.65, 0.85),
        size: 0.46,
        opacity: isDark ? 0.26 : 0.38,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double extent = math.max(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            return Stack(
              children: <Widget>[
                for (int i = 0; i < blobs.length; i++)
                  _buildBlob(blobs[i], extent, i, blobs.length),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBlob(_Blob blob, double extent, int index, int total) {
    final double t = (_controller.value + index / total) % 1.0;
    final double phase = t * 2 * math.pi;

    final Offset drift = Offset(
      math.sin(phase) * 36,
      math.cos(phase * 0.8) * 28,
    );
    final double scale = 1 + 0.12 * math.sin(phase * 1.3 + index);
    final double diameter = math.max(extent * blob.size, 1);

    return Align(
      alignment: blob.origin,
      child: Transform.translate(
        offset: drift,
        child: Transform.scale(
          scale: scale,
          child: SizedBox.square(
            dimension: diameter,
            child: DecoratedBox(
              // O próprio degradê radial é o "desfoque": borda macia de graça.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    blob.color.withValues(alpha: blob.opacity),
                    blob.color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
