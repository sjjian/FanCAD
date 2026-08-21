import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/vector.dart';

/// One stroked glyph from an SHX shape font.
class ShxGlyph {
  const ShxGlyph({
    required this.code,
    required this.name,
    required this.commands,
  });

  final int code;
  final String name;
  final List<ShxDraw> commands;
}

/// A pen movement in a glyph.
class ShxDraw {
  const ShxDraw({required this.to, required this.penDown});

  final Vec2 to;
  final bool penDown;
}

/// A parsed AutoCAD SHX shape or unifont.
///
/// SHX is the font format DWG drawings actually reference. Rendering TEXT
/// without it produces a substitute that is the wrong width, which then
/// misplaces every dimension that was laid out against the original font.
class ShxFont {
  ShxFont({
    required this.header,
    required this.glyphs,
    this.above = 1,
    this.below = 0,
  });

  final String header;
  final Map<int, ShxGlyph> glyphs;
  final double above;
  final double below;

  bool get isEmpty => glyphs.isEmpty;

  ShxGlyph? glyph(int code) => glyphs[code] ?? glyphs[code & 0xFF];

  /// Strokes [text] at [origin], scaled so a capital A is about [height] tall.
  List<List<Vec2>> layout(
    String text, {
    required Vec2 origin,
    required double height,
    double rotation = 0,
    double widthFactor = 1,
  }) {
    final scale = above == 0 ? height : height / above;
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    final polylines = <List<Vec2>>[];
    var cursor = 0.0;

    for (final unit in text.runes) {
      final glyph = this.glyph(unit) ?? this.glyph(0x3F);
      if (glyph == null) {
        cursor += height * 0.6 * widthFactor;
        continue;
      }
      var pen = Vec2.zero();
      var current = <Vec2>[];
      var maxX = 0.0;
      for (final command in glyph.commands) {
        pen = command.to;
        if (pen.x > maxX) maxX = pen.x;
        final world = Vec2(
          origin.x + (cursor + pen.x * widthFactor) * scale * cos -
              pen.y * scale * sin,
          origin.y + (cursor + pen.x * widthFactor) * scale * sin +
              pen.y * scale * cos,
        );
        if (command.penDown) {
          if (current.isEmpty) {
            final previous = glyph.commands.isEmpty
                ? origin
                : world;
            current.add(previous);
          }
          current.add(world);
        } else {
          if (current.length >= 2) polylines.add(current);
          current = [world];
        }
      }
      if (current.length >= 2) polylines.add(current);
      cursor += (maxX == 0 ? above : maxX) * widthFactor;
    }
    return polylines;
  }

  /// Parses a binary SHX buffer. Unknown or truncated files produce an empty
  /// font rather than throwing: a missing font must not prevent a drawing
  /// from opening.
  static ShxFont parse(Uint8List bytes) {
    if (bytes.length < 24) return ShxFont(header: '', glyphs: const {});
    final headerEnd = bytes.indexOf(0x1A);
    if (headerEnd < 0 || headerEnd > 128) {
      return ShxFont(header: '', glyphs: const {});
    }
    final header = latin1.decode(bytes.sublist(0, headerEnd));
    var offset = headerEnd + 1;
    if (offset + 6 > bytes.length) {
      return ShxFont(header: header, glyphs: const {});
    }

    final view = ByteData.sublistView(bytes);
    final low = view.getUint16(offset, Endian.little);
    final high = view.getUint16(offset + 2, Endian.little);
    final count = view.getUint16(offset + 4, Endian.little);
    offset += 6;

    final glyphs = <int, ShxGlyph>{};
    var above = 1.0;
    var below = 0.0;

    for (var i = 0; i < count && offset + 4 <= bytes.length; i++) {
      final code = view.getUint16(offset, Endian.little);
      final length = view.getUint16(offset + 2, Endian.little);
      offset += 4;
      if (length <= 0 || offset + length > bytes.length) break;
      final payload = bytes.sublist(offset, offset + length);
      offset += length;
      final nameEnd = payload.indexOf(0);
      final name = nameEnd <= 0
          ? ''
          : latin1.decode(payload.sublist(0, nameEnd));
      final dataStart = nameEnd < 0 ? 0 : nameEnd + 1;
      final commands = _decodeShape(payload.sublist(dataStart));
      glyphs[code] = ShxGlyph(code: code, name: name, commands: commands);
      if (code == 0 && commands.length >= 2) {
        above = commands[0].to.y.abs().clamp(1, 1e6);
        below = commands[1].to.y.abs();
      }
    }

    if (glyphs.isEmpty && low == 0 && high == 0) {
      return ShxFont(header: header, glyphs: const {});
    }
    return ShxFont(header: header, glyphs: glyphs, above: above, below: below);
  }

  /// The 16 SHX vector directions, matching the shape specification.
  static final List<Vec2> _directions = [
    for (var i = 0; i < 16; i++)
      Vec2(math.cos(i * math.pi / 8), math.sin(i * math.pi / 8)),
  ];

  static List<ShxDraw> _decodeShape(Uint8List data) {
    final out = <ShxDraw>[];
    var x = 0.0;
    var y = 0.0;
    var penDown = true;
    var scale = 1.0;
    var skipVertical = false;
    var i = 0;

    while (i < data.length) {
      final op = data[i++];
      if (op == 0) break;
      if (skipVertical && op != 0x0E) continue;
      switch (op) {
        case 1:
          penDown = true;
        case 2:
          penDown = false;
        case 3:
          if (i < data.length) {
            final d = data[i++];
            if (d != 0) scale /= d;
          }
        case 4:
          if (i < data.length) {
            final m = data[i++];
            if (m != 0) scale *= m;
          }
        case 5:
        case 6:
          // Push/pop are ignored for a single-pass stroke; the stack is a
          // compactness trick, not a geometric primitive we need to honour
          // to get readable text.
          break;
        case 8:
          if (i + 1 < data.length) {
            x += _signed(data[i++]) * scale;
            y += _signed(data[i++]) * scale;
            out.add(ShxDraw(to: Vec2(x, y), penDown: penDown));
          }
        case 9:
          while (i + 1 < data.length) {
            final dx = _signed(data[i++]);
            final dy = _signed(data[i++]);
            if (dx == 0 && dy == 0) break;
            x += dx * scale;
            y += dy * scale;
            out.add(ShxDraw(to: Vec2(x, y), penDown: penDown));
          }
        case 0x0A:
        case 0x0B:
        case 0x0C:
        case 0x0D:
          // Arcs are flattened to a chord. A missing curve on a rare glyph is
          // preferable to rejecting the whole font.
          if (i < data.length) i++;
          if (op == 0x0B && i + 3 < data.length) i += 4;
          if ((op == 0x0C || op == 0x0D) && i + 2 < data.length) {
            x += _signed(data[i++]) * scale;
            y += _signed(data[i++]) * scale;
            i++;
            out.add(ShxDraw(to: Vec2(x, y), penDown: penDown));
          }
        case 0x0E:
          skipVertical = !skipVertical;
        default:
          final length = (op >> 4) & 0x0F;
          final dir = op & 0x0F;
          if (length == 0) continue;
          final step = _directions[dir] * (length * scale);
          x += step.x;
          y += step.y;
          out.add(ShxDraw(to: Vec2(x, y), penDown: penDown));
      }
    }
    return out;
  }

  static int _signed(int value) => value < 128 ? value : value - 256;
}
