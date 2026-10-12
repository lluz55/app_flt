import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Temas claro e escuro do Anotador.
///
/// Ambos compartilham os mesmos raios, elevações e a mesma família de cor —
/// muda apenas a luminosidade e o contraste, de modo que o modo escuro seja
/// uma decisão de design e não uma inversão automática.
abstract final class AppTheme {
  const AppTheme._();

  /// Raios usados em campos, chips, cartões e folhas.
  static const double _radiusSmall = 14;
  static const double _radius = 18;
  static const double _radiusLarge = 20;

  /// Família tipográfica do app (declarada no `pubspec.yaml`).
  static const String _family = 'Inter';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = _colorScheme(brightness);
    final TextTheme text = _textTheme(scheme, isDark).apply(fontFamily: _family);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _family,
      scaffoldBackgroundColor: AppPalette.background(brightness),
      canvasColor: AppPalette.surface(brightness),
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark
            ? const Color(0x14FFFFFF)
            : scheme.primary.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        // Bordas discretas: o preenchimento é a separação, não o contorno.
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error, width: 1.2),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
        hintStyle: text.bodyMedium?.copyWith(
          color: AppPalette.muted(brightness),
        ),
        labelStyle: text.bodyMedium?.copyWith(
          color: AppPalette.muted(brightness),
        ),
        floatingLabelStyle: text.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        // A sombra do FAB é desenhada à mão em `home_shell.dart`. A do Material
        // saía em preto puro — a única cor fora da paleta, visível como um
        // contorno sólido ao redor do botão em todas as capturas que o têm.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        splashColor: scheme.onPrimary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        extendedTextStyle: text.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        // No estado desligado o polegar ficava em 2,06:1 sobre a faixa escura —
        // abaixo do mínimo de 3:1 para elemento gráfico, deixando o estado
        // ambíguo. Aqui os dois estados são explícitos: faixa apagada com
        // contorno, e ligado com o acento do tema.
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : AppPalette.muted(brightness),
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : AppPalette.surface(brightness),
        ),
        trackOutlineColor: WidgetStatePropertyAll<Color>(
          scheme.outline.withValues(alpha: 0.9),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? const Color(0x14FFFFFF)
            : scheme.primary.withValues(alpha: 0.07),
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.16),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: AppPalette.onSurface(brightness),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSmall),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconColor: scheme.primary,
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // Escuro nos dois temas: mantém a hierarquia e não compete com a aurora.
        backgroundColor: const Color(0xFF241E3A),
        contentTextStyle: text.bodyMedium?.copyWith(color: const Color(0xFFEDE9F7)),
        actionTextColor: AppPalette.cyan,
        closeIconColor: AppPalette.muted(Brightness.dark),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppPalette.surface(brightness),
        modalBackgroundColor: AppPalette.surface(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface(brightness).withValues(
          alpha: isDark ? 0.72 : 0.86,
        ),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.26 : 0.14),
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          text.labelMedium!,
        ),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : AppPalette.muted(brightness),
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
    );
  }

  /// Esquema derivado do violeta e depois "vestido" com os tons da paleta.
  static ColorScheme _colorScheme(Brightness brightness) {
    final ColorScheme seed = ColorScheme.fromSeed(
      seedColor: AppPalette.violet,
      brightness: brightness,
    );

    return switch (brightness) {
      Brightness.dark => seed.copyWith(
        primary: const Color(0xFFCBB8FF),
        onPrimary: const Color(0xFF341067),
        primaryContainer: const Color(0xFF4B2A9E),
        onPrimaryContainer: const Color(0xFFE7DEFF),
        secondary: const Color(0xFFF5A8F0),
        onSecondary: const Color(0xFF4B0B45),
        secondaryContainer: const Color(0xFF6B1A62),
        onSecondaryContainer: const Color(0xFFFFDFF7),
        tertiary: const Color(0xFF7ED7E8),
        onTertiary: const Color(0xFF00363F),
        tertiaryContainer: const Color(0xFF0B5460),
        onTertiaryContainer: const Color(0xFFC5F2FB),
        surface: const Color(0xFF17122A),
        onSurface: const Color(0xFFF3F0FB),
        surfaceContainerLowest: const Color(0xFF100C1F),
        surfaceContainerLow: const Color(0xFF1A1530),
        surfaceContainer: const Color(0xFF1E1932),
        surfaceContainerHigh: const Color(0xFF241E3A),
        surfaceContainerHighest: const Color(0xFF2A2342),
        outline: const Color(0xFF5A5372),
        outlineVariant: const Color(0xFF39324B),
      ),
      Brightness.light => seed.copyWith(
        primary: const Color(0xFF6D3BFF),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFE7DEFF),
        onPrimaryContainer: const Color(0xFF25005C),
        secondary: const Color(0xFFB31FCC),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFFFDFF7),
        onSecondaryContainer: const Color(0xFF35003A),
        tertiary: const Color(0xFF00879E),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFC5F2FB),
        onTertiaryContainer: const Color(0xFF00363F),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1A1523),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFFBF9FF),
        surfaceContainer: const Color(0xFFF4F0FA),
        surfaceContainerHigh: const Color(0xFFEEE9F5),
        surfaceContainerHighest: const Color(0xFFE8E3EF),
        outline: const Color(0xFF7A7389),
        outlineVariant: const Color(0xFFD6CFE0),
      ),
    };
  }

  /// Tipografia Inter. Títulos grandes ganham tracking negativo (ar moderno);
  /// corpo e rótulos ficam com tracking neutro ou levemente positivo.
  static TextTheme _textTheme(ColorScheme scheme, bool isDark) {
    // `material2021` fixo (em vez de `englishLike`) mantém a tipografia igual
    // em todas as plataformas, inclusive web e Linux.
    final Typography typography = Typography.material2021(colorScheme: scheme);
    final TextTheme base = isDark ? typography.white : typography.black;

    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        height: 1.1,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.7,
        height: 1.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.25,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}