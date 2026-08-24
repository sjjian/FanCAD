import 'package:flutter/material.dart';

/// The FanCAD colour, spacing and typography scale.
///
/// A CAD shell is mostly chrome around one very dark canvas, so the palette is
/// built as a ladder of surfaces rather than from a Material seed colour: the
/// canvas is the darkest value, panels step up from it, and the accent is used
/// sparingly enough that a selected entity on the canvas is never competing
/// with the UI for attention.
@immutable
class FanCadTokens {
  const FanCadTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentText,
    required this.success,
    required this.warning,
    required this.danger,
    required this.isDark,
  });

  /// The FanCAD dark theme. Canvas is a desaturated near-black rather than
  /// pure black so that ACI 7 white geometry does not bloom against it.
  static const FanCadTokens dark = FanCadTokens(
    canvas: Color(0xFF1B1D21),
    surface: Color(0xFF23262B),
    surfaceRaised: Color(0xFF2B2F35),
    surfaceOverlay: Color(0xFF33383F),
    border: Color(0xFF34383F),
    borderStrong: Color(0xFF454B54),
    text: Color(0xFFE6E8EB),
    textMuted: Color(0xFF9BA3AD),
    textFaint: Color(0xFF6B7280),
    accent: Color(0xFF3B9DFF),
    accentText: Color(0xFFFFFFFF),
    success: Color(0xFF4ED07E),
    warning: Color(0xFFFFB347),
    danger: Color(0xFFFF6B6B),
    isDark: true,
  );

  static const FanCadTokens light = FanCadTokens(
    canvas: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F3F6),
    surfaceOverlay: Color(0xFFFFFFFF),
    border: Color(0xFFDDE1E7),
    borderStrong: Color(0xFFBFC6D0),
    text: Color(0xFF1B1D21),
    textMuted: Color(0xFF5A626C),
    textFaint: Color(0xFF8B939D),
    accent: Color(0xFF1668D6),
    accentText: Color(0xFFFFFFFF),
    success: Color(0xFF1E9E58),
    warning: Color(0xFFB4700A),
    danger: Color(0xFFD03636),
    isDark: false,
  );

  /// The drawing area behind the geometry.
  final Color canvas;

  /// Panels, the activity bar and the status bar.
  final Color surface;

  /// Tab strips, toolbars and hovered rows.
  final Color surfaceRaised;

  /// Dialogs, the command palette and menus.
  final Color surfaceOverlay;

  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color accentText;
  final Color success;
  final Color warning;
  final Color danger;

  final bool isDark;

  // A four-point spacing grid. Everything in the shell is a multiple of these,
  // which is what keeps a window full of dense panels from looking noisy.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;

  static const double radiusSmall = 4;
  static const double radius = 6;
  static const double radiusLarge = 10;

  /// Chrome heights. Three tracks so title, tabs and footers line up instead
  /// of each bar inventing its own size and stealing the canvas.
  static const double titleBarHeight = 32;
  static const double tabBarHeight = 32;
  static const double commandLineHeight = 24;
  static const double statusBarHeight = 24;
  static const double rowHeight = 26;
  static const double activityBarWidth = 48;

  /// Width reserved for the native traffic lights on a macOS hidden title bar.
  ///
  /// The cluster is about 70px; the extra 8px is a gap so the first toolbar
  /// icon does not sit against the green button.
  static const double macTrafficLightsWidth = 78;

  /// Hit area for pane splitters. Wider than the 1px rule so it can be grabbed.
  static const double splitterHit = 7;

  /// Icon sizes used in chrome. Dense controls, default tools, activity bar.
  static const double iconSmall = 12;
  static const double iconMedium = 16;
  static const double iconLarge = 20;

  /// The default and permitted range for the side panel width.
  static const double sidePanelWidth = 240;
  static const double sidePanelMinWidth = 180;
  static const double sidePanelMaxWidth = 560;

  TextStyle get bodyStyle => TextStyle(
    fontSize: 12,
    height: 1.35,
    color: text,
    fontFamily: uiFontFamily,
  );

  TextStyle get labelStyle => TextStyle(
    fontSize: 11,
    height: 1.3,
    color: textMuted,
    fontFamily: uiFontFamily,
  );

  TextStyle get sectionTitleStyle => TextStyle(
    fontSize: 11,
    height: 1.3,
    letterSpacing: 0.6,
    fontWeight: FontWeight.w600,
    color: textMuted,
    fontFamily: uiFontFamily,
  );

  /// Coordinates, entity ids and command-line entry. A tabular figure font
  /// keeps a live coordinate readout from jittering as digits change.
  TextStyle get monoStyle => TextStyle(
    fontSize: 12,
    height: 1.3,
    color: text,
    fontFamily: monoFontFamily,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Left null so the platform default is used; naming a font that is not
  /// bundled would silently fall back anyway, and worse, differently per OS.
  static const String? uiFontFamily = null;

  /// The one font family that is safe to name: every desktop platform resolves
  /// this alias to its own fixed-pitch face.
  static const String monoFontFamily = 'monospace';

  /// A colour for a row that is hovered or otherwise softly emphasised.
  Color get hover => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);

  Color get pressed => isDark
      ? Colors.white.withValues(alpha: 0.09)
      : Colors.black.withValues(alpha: 0.08);

  /// The tint behind a selected list row.
  Color get selection => accent.withValues(alpha: isDark ? 0.22 : 0.14);
}

/// Makes [FanCadTokens] available to the widget tree.
///
/// A theme extension rather than a plain [InheritedWidget] so that tokens
/// travel with `Theme.of`, which means a plugin-contributed panel gets the
/// right colours without having to be wrapped in anything.
@immutable
class FanCadThemeExtension extends ThemeExtension<FanCadThemeExtension> {
  const FanCadThemeExtension(this.tokens);

  final FanCadTokens tokens;

  @override
  FanCadThemeExtension copyWith({FanCadTokens? tokens}) =>
      FanCadThemeExtension(tokens ?? this.tokens);

  @override
  FanCadThemeExtension lerp(
    ThemeExtension<FanCadThemeExtension>? other,
    double t,
  ) {
    // The two themes are structurally different rather than interpolable, so
    // snapping at the midpoint is both correct and cheaper than a per-channel
    // lerp of twenty colours.
    if (other is! FanCadThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// Reads the FanCAD tokens out of the ambient theme.
extension FanCadThemeAccess on BuildContext {
  FanCadTokens get tokens =>
      Theme.of(this).extension<FanCadThemeExtension>()?.tokens ??
      FanCadTokens.dark;
}
