import 'dart:collection';
import 'dart:ui' as ui;

import 'batch.dart';

/// Caches laid-out paragraphs.
///
/// Text layout is the most expensive per-item work in a CAD frame: shaping a
/// string costs orders of magnitude more than drawing a line. Drawings repeat
/// the same strings constantly — part numbers, dimension values, the same note
/// on twenty sheets — so a keyed cache turns most of that cost into a lookup.
///
/// Colour is part of the key. It could instead be applied at paint time with a
/// colour filter, but that costs a `saveLayer` per text run, and a drawing only
/// uses a handful of distinct colours, so keying on it is the cheaper trade.
class ParagraphCache {
  ParagraphCache({this.capacity = 2048});

  /// Maximum retained paragraphs. Each is small; the cap exists to bound a
  /// drawing full of unique strings, such as a coordinate table.
  final int capacity;

  final LinkedHashMap<_Key, ui.Paragraph> _entries = LinkedHashMap();
  final Map<String, double> _capRatios = {};
  int _hits = 0;
  int _misses = 0;

  int get length => _entries.length;
  int get hits => _hits;
  int get misses => _misses;

  /// Height quantisation, in pixels. Laying out the same label at 12.0 and
  /// 12.02 pixels is wasted work, and the difference is invisible.
  static double quantiseHeight(double pixels) => (pixels * 4).roundToDouble() / 4;

  /// Cap-height of [family] as a fraction of em size. DWG height is cap
  /// height; a font size is the em, so this is how a 5 mm TEXT becomes 5 mm
  /// on paper instead of the 0.72 guess that only fitted one face.
  double capRatio(String family) =>
      _capRatios.putIfAbsent(family, () => _measureCapRatio(family));

  double _measureCapRatio(String family) {
    const em = 100.0;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontFamily: family, fontSize: em),
    )..addText('H');
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 1000));
    final boxes = paragraph.getBoxesForRange(0, 1);
    if (boxes.isEmpty) return 0.72;
    final ratio = (boxes.first.bottom - boxes.first.top) / em;
    if (!ratio.isFinite || ratio < 0.4 || ratio > 1.2) return 0.72;
    return ratio;
  }

  ui.Paragraph obtain(TextItem item, {required String fontFamily}) {
    final family = item.fontFamily.isEmpty ? fontFamily : item.fontFamily;
    final height = quantiseHeight(item.pixelHeight);
    final wrap = item.wrapWidth <= 0
        ? double.infinity
        : quantiseHeight(item.wrapWidth);
    final key = _Key(
      item.text,
      height,
      wrap,
      item.hAlign,
      item.isMultiline,
      item.color,
      family,
      item.tracking,
    );

    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing;
      _hits++;
      return existing;
    }
    _misses++;

    final paragraph = _layout(
      item,
      height: height,
      wrap: wrap,
      fontFamily: family,
    );
    _entries[key] = paragraph;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return paragraph;
  }

  /// Advance width of [text] at a model [height], for MTEXT wrapping.
  double measureWidth(
    String text, {
    required double height,
    required String fontFamily,
    double widthFactor = 1,
    double tracking = 1,
  }) {
    if (text.isEmpty || height <= 0) return 0;
    final item = TextItem(
      text: text,
      origin: ui.Offset.zero,
      pixelHeight: height,
      rotation: 0,
      color: const ui.Color(0xFFFFFFFF),
      hAlign: 0,
      vAlign: 0,
      widthFactor: widthFactor,
      tracking: tracking,
      fontFamily: fontFamily,
    );
    final paragraph = obtain(item, fontFamily: fontFamily);
    return paragraph.maxIntrinsicWidth * widthFactor;
  }

  ui.Paragraph _layout(
    TextItem item, {
    required double height,
    required double wrap,
    required String fontFamily,
  }) {
    final fontSize = height / capRatio(fontFamily);
    final letterSpacing = item.tracking == 1
        ? 0.0
        : (item.tracking - 1) * fontSize;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        textAlign: switch (item.hAlign) {
          1 => ui.TextAlign.center,
          2 => ui.TextAlign.right,
          _ => ui.TextAlign.left,
        },
        maxLines: item.isMultiline ? null : 1,
        textDirection: ui.TextDirection.ltr,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: item.color,
          fontFamily: fontFamily,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
        ),
      )
      ..addText(item.text);
    final paragraph = builder.build()
      ..layout(
        // An unwrapped run still needs a finite constraint; a width far wider
        // than any plausible line is the conventional stand-in for infinity.
        ui.ParagraphConstraints(width: wrap.isFinite ? wrap : 1e6),
      );
    // paragraph.width is the constraint, not the ink. Leaving it at 1e6 makes
    // a 90° dimension label a kilometre tall; PictureRecorder's viewport cull
    // then drops the draw and the red ticks stay while AL / AW vanish.
    if (!wrap.isFinite) {
      final tight = paragraph.maxIntrinsicWidth;
      if (tight.isFinite && tight > 0) {
        paragraph.layout(ui.ParagraphConstraints(width: tight + 0.5));
      }
    }
    return paragraph;
  }

  void clear() => _entries.clear();
}

class _Key {
  const _Key(
    this.text,
    this.height,
    this.wrapWidth,
    this.hAlign,
    this.isMultiline,
    this.color,
    this.fontFamily,
    this.tracking,
  );

  final String text;
  final double height;
  final double wrapWidth;
  final int hAlign;
  final bool isMultiline;
  final ui.Color color;
  final String fontFamily;
  final double tracking;

  @override
  bool operator ==(Object other) =>
      other is _Key &&
      other.text == text &&
      other.height == height &&
      other.wrapWidth == wrapWidth &&
      other.hAlign == hAlign &&
      other.isMultiline == isMultiline &&
      other.color == color &&
      other.fontFamily == fontFamily &&
      other.tracking == tracking;

  @override
  int get hashCode => Object.hash(
    text,
    height,
    wrapWidth,
    hAlign,
    isMultiline,
    color,
    fontFamily,
    tracking,
  );
}
