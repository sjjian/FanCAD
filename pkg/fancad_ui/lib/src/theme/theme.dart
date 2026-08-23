import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the application [ThemeData] from a token set.
///
/// Material's own component defaults assume a content-first mobile layout with
/// generous padding; a CAD shell needs the opposite. Rather than fight the
/// defaults at every call site, the density and the component themes are pinned
/// once here.
class FanCadTheme {
  const FanCadTheme._();

  static ThemeData dark() => _build(FanCadTokens.dark, Brightness.dark);
  static ThemeData light() => _build(FanCadTokens.light, Brightness.light);

  static ThemeData of(FanCadTokens tokens) => _build(
    tokens,
    tokens.isDark ? Brightness.dark : Brightness.light,
  );

  static ThemeData _build(FanCadTokens tokens, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.accentText,
      secondary: tokens.accent,
      onSecondary: tokens.accentText,
      error: tokens.danger,
      onError: Colors.white,
      surface: tokens.surface,
      onSurface: tokens.text,
      surfaceContainerHighest: tokens.surfaceRaised,
      outline: tokens.border,
      outlineVariant: tokens.borderStrong,
    );

    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.canvas,
      // A CAD window is a dense information display; the standard vertical
      // density would cost roughly a third of the panel area to padding.
      visualDensity: VisualDensity.compact,
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
    );

    return base.copyWith(
      extensions: [FanCadThemeExtension(tokens)],
      textTheme: base.textTheme.apply(
        bodyColor: tokens.text,
        displayColor: tokens.text,
        fontSizeFactor: 1,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: tokens.textMuted, size: 16),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: tokens.surfaceOverlay,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        ),
        textStyle: tokens.bodyStyle,
        padding: const EdgeInsets.symmetric(
          horizontal: FanCadTokens.space2,
          vertical: FanCadTokens.space1,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          tokens.textFaint.withValues(alpha: 0.5),
        ),
        crossAxisMargin: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: tokens.surfaceRaised,
        hintStyle: tokens.labelStyle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FanCadTokens.space2,
          vertical: FanCadTokens.space2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          borderSide: BorderSide(color: tokens.accent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.text,
          textStyle: tokens.bodyStyle,
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentText,
          textStyle: tokens.bodyStyle,
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: tokens.borderStrong),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.accent
              : Colors.transparent,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: tokens.bodyStyle,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.surfaceOverlay),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceOverlay,
        textStyle: tokens.bodyStyle,
        labelTextStyle: WidgetStatePropertyAll(tokens.bodyStyle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          side: BorderSide(color: tokens.borderStrong),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceOverlay,
        titleTextStyle: tokens.bodyStyle.copyWith(fontSize: 15),
        contentTextStyle: tokens.labelStyle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
      ),
    );
  }
}
