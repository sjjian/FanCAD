import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:fancad_core/fancad_core.dart';

/// Maps AutoCAD Color Index values to screen colours.
///
/// Two details make this less trivial than a lookup table. Index 7 means
/// "the opposite of the background", so it has to be resolved against the
/// current theme rather than fixed. And a drawing authored for white paper is
/// usually being viewed on a dark canvas, so very dark colours are lifted
/// enough to stay legible without changing their hue.
class AciPalette {
  AciPalette({required this.background}) : _isDarkBackground = _isDark(background);

  /// The dark canvas most CAD applications default to, and the value FanCAD
  /// uses.
  static final AciPalette dark = AciPalette(
    background: const Color(0xFF1B1D21),
  );

  static final AciPalette light = AciPalette(
    background: const Color(0xFFFFFFFF),
  );

  final Color background;
  final bool _isDarkBackground;

  /// Indices 1 to 9 are the fixed primaries every CAD user recognises.
  static const List<int> _primaries = [
    0xFF0000, // 1 red
    0xFFFF00, // 2 yellow
    0x00FF00, // 3 green
    0x00FFFF, // 4 cyan
    0x0000FF, // 5 blue
    0xFF00FF, // 6 magenta
    0xFFFFFF, // 7 white or black, resolved against the background
    0x808080, // 8 dark grey
    0xC0C0C0, // 9 light grey
  ];

  /// Value levels of the 10 to 249 ramp, brightest first.
  static const List<double> _values = [1.0, 0.65, 0.5, 0.3, 0.15];

  static final Int32List _table = _buildTable();

  static Int32List _buildTable() {
    final table = Int32List(256);
    table[0] = 0x000000; // ByBlock, never drawn directly.
    for (var i = 0; i < _primaries.length; i++) {
      table[i + 1] = _primaries[i];
    }

    // 10 to 249 is a hue ramp: 24 hues at 15 degree intervals, each with five
    // value levels in a saturated and a desaturated variant. This reproduces
    // the structure of the AutoCAD palette rather than its exact byte values,
    // which is close enough that a drawing looks right and far more
    // maintainable than 240 magic numbers.
    for (var hueStep = 0; hueStep < 24; hueStep++) {
      final hue = hueStep * 15.0;
      for (var offset = 0; offset < 10; offset++) {
        final saturation = offset.isEven ? 1.0 : 0.45;
        final value = _values[offset ~/ 2];
        table[10 + hueStep * 10 + offset] = _hsvToRgb(hue, saturation, value);
      }
    }

    // 250 to 255 is a grey ramp.
    const greys = [0x333333, 0x505050, 0x696969, 0x828282, 0xBEBEBE, 0xFFFFFF];
    for (var i = 0; i < greys.length; i++) {
      table[250 + i] = greys[i];
    }
    return table;
  }

  static int _hsvToRgb(double hue, double saturation, double value) {
    final sector = hue / 60;
    final index = sector.floor() % 6;
    final fraction = sector - sector.floorToDouble();
    final p = value * (1 - saturation);
    final q = value * (1 - saturation * fraction);
    final t = value * (1 - saturation * (1 - fraction));
    final (r, g, b) = switch (index) {
      0 => (value, t, p),
      1 => (q, value, p),
      2 => (p, value, t),
      3 => (p, q, value),
      4 => (t, p, value),
      _ => (value, p, q),
    };
    return ((r * 255).round() << 16) |
        ((g * 255).round() << 8) |
        (b * 255).round();
  }

  static bool _isDark(Color color) {
    // Rec. 601 luma, which tracks perceived brightness well enough to decide
    // whether index 7 should be white or black.
    final luma =
        0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    return luma < 0.5;
  }

  /// The colour to draw a resolved style in.
  Color colorOf(CadColor color) => switch (color.kind) {
    ColorKind.trueColor => _lift(Color(0xFF000000 | color.value)),
    ColorKind.indexed => indexed(color.value),
    // Inheritance should already have been resolved; falling back to the
    // foreground is the visible-but-obviously-wrong choice.
    _ => foreground,
  };

  /// The colour of ACI [index].
  Color indexed(int index) {
    if (index == 7) return foreground;
    if (index < 0 || index > 255) return foreground;
    return _lift(Color(0xFF000000 | _table[index]));
  }

  /// Index 7, resolved against the background: white on a dark canvas,
  /// black on a light one.
  Color get foreground =>
      _isDarkBackground ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// Raises the luminance of colours that would vanish into the background.
  ///
  /// Without this, the very common practice of authoring a drawing in near
  /// black on white paper produces an apparently empty dark canvas.
  Color _lift(Color color) {
    if (!_isDarkBackground) return color;
    final luma = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    const floor = 0.22;
    if (luma >= floor) return color;
    if (luma <= 0.001) return foreground;
    final gain = floor / luma;
    return Color.from(
      alpha: color.a,
      red: (color.r * gain).clamp(0.0, 1.0),
      green: (color.g * gain).clamp(0.0, 1.0),
      blue: (color.b * gain).clamp(0.0, 1.0),
    );
  }
}
