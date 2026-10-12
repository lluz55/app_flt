import 'package:flutter/material.dart';

/// Paleta expressiva do Anotador.
///
/// Os tons são vivos e saturados de propósito: eles aparecem tanto no fundo
/// "aurora" quanto em marcadores coloridos sobre ele, onde tons pastéis ou
/// quase brancos sumiriam no contraste.
abstract final class AppPalette {
  const AppPalette._();

  // Acentos ------------------------------------------------------------------

  /// Violeta — cor primária e semente do esquema Material.
  static const Color violet = Color(0xFF7C4DFF);

  /// Fúcsia — o tom "quente" do gradiente.
  static const Color fuchsia = Color(0xFFD93BF0);

  /// Ciano — o "frio" do gradiente, usado em destaques e acentos.
  static const Color cyan = Color(0xFF22D3EE);

  static const Color amber = Color(0xFFF7B32B);
  static const Color lime = Color(0xFF9BE564);
  static const Color coral = Color(0xFFFF6B5B);
  static const Color sky = Color(0xFF38BDF8);
  static const Color pink = Color(0xFFFF5CA8);

  /// Cores de acento por nota. A ordem importa: `Note.colorIndex` indexa aqui.
  ///
  /// São tons médios (croma alto, luminosidade média) de propósito: funcionam
  /// como ponto ou chip tanto sobre o fundo claro quanto sobre o escuro.
  static const List<Color> noteColors = <Color>[
    Color(0xFF7C5CFF), // violeta
    Color(0xFFC13BD4), // fúcsia
    Color(0xFF0EA5C6), // ciano
    Color(0xFFDE9100), // âmbar
    Color(0xFF6DB31B), // limão
    Color(0xFFEE523F), // coral
    Color(0xFF2D7FF0), // céu
    Color(0xFFE33E8C), // rosa
  ];

  /// Cor de acento para o [index], dando a volta na lista quando necessário.
  ///
  /// Aceita índices negativos e fora de rango sem lançar.
  static Color noteColor(int index) {
    final int count = noteColors.length;
    return noteColors[((index % count) + count) % count];
  }

  // Base por brilho ----------------------------------------------------------

  static const Color _backgroundLight = Color(0xFFF6F3FF);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _onSurfaceLight = Color(0xFF1A1523);
  static const Color _mutedLight = Color(0xFF6B6478);

  static const Color _backgroundDark = Color(0xFF0A0714);
  static const Color _surfaceDark = Color(0xFF17122A);
  static const Color _onSurfaceDark = Color(0xFFF3F0FB);
  static const Color _mutedDark = Color(0xFFA79FC4);

  /// Fundo base da aplicação sob o gradiente aurora.
  static Color background(Brightness brightness) => switch (brightness) {
    Brightness.dark => _backgroundDark,
    Brightness.light => _backgroundLight,
  };

  /// Superfície padrão (cards, campos, folhas).
  static Color surface(Brightness brightness) => switch (brightness) {
    Brightness.dark => _surfaceDark,
    Brightness.light => _surfaceLight,
  };

  /// Texto principal — contraste ≥ 4.5:1 sobre [background] e [surface].
  static Color onSurface(Brightness brightness) => switch (brightness) {
    Brightness.dark => _onSurfaceDark,
    Brightness.light => _onSurfaceLight,
  };

  /// Texto secundário (metadados, legendas). Contraste ≥ 4.5:1 nos dois temas.
  static Color muted(Brightness brightness) => switch (brightness) {
    Brightness.dark => _mutedDark,
    Brightness.light => _mutedLight,
  };

  // Aurora -------------------------------------------------------------------

  /// Gradiente do fundo. Escuro: violeta profundo → índigo → teal.
  /// Claro: a mesma família em tons pastel, mantendo o texto legível.
  static LinearGradient auroraGradient(Brightness brightness) =>
      switch (brightness) {
        Brightness.dark => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1A0B3D),
            Color(0xFF2A0F55),
            Color(0xFF13124A),
            Color(0xFF06283F),
          ],
        ),
        Brightness.light => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF4EDFF),
            Color(0xFFE9F1FF),
            Color(0xFFFDEBFA),
            Color(0xFFE4FAFF),
          ],
        ),
      };

  /// Cores dos 4 blobs flutuantes do fundo.
  static List<Color> auroraBlobs(Brightness brightness) => switch (brightness) {
    Brightness.dark => const <Color>[violet, fuchsia, cyan, pink],
    Brightness.light => const <Color>[
      Color(0xFFB7A4FF),
      Color(0xFFF5A8F0),
      Color(0xFF8FE4F7),
      Color(0xFFFFB6D5),
    ],
  };
}