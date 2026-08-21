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
  int _hits = 0;
  int _misses = 0;

  int get length => _entries.length;
  int get hits => _hits;
  int get misses => _misses;

  /// Height quantisation, in pixels. Laying out the same label at 12.0 and
  /// 12.02 pixels is wasted work, and the difference is invisible.
  static double quantiseHeight(double pixels) => (pixels * 4).roundToDouble() / 4;

  ui.Paragraph obtain(TextItem item, {required String fontFamily}) {
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
      fontFamily: fontFamily,
    );
    _entries[key] = paragraph;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return paragraph;
  }

  ui.Paragraph _layout(
    TextItem item, {
    required double height,
    required double wrap,
    required String fontFamily,
  }) {
    // DWG text height is the cap height, whereas a font size is the em size.
    // 0.72 is the cap-height ratio of most technical faces, so applying it
    // makes a 5 mm text entity actually measure 5 mm on paper.
    const capHeightRatio = 0.72;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: fontFamily,
        fontSize: height / capHeightRatio,
        textAlign: switch (item.hAlign) {
          1 => ui.TextAlign.center,
          2 => ui.TextAlign.right,
          _ => ui.TextAlign.left,
        },
        maxLines: item.isMultiline ? null : 1,
        textDirection: ui.TextDirection.ltr,
      ),
    )
      ..pushStyle(ui.TextStyle(color: item.color, fontFamily: fontFamily))
      ..addText(item.text);
    final paragraph = builder.build()
      ..layout(
        // An unwrapped run still needs a finite constraint; a width far wider
        // than any plausible line is the conventional stand-in for infinity.
        ui.ParagraphConstraints(width: wrap.isFinite ? wrap : 1e6),
      );
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
  );

  final String text;
  final double height;
  final double wrapWidth;
  final int hAlign;
  final bool isMultiline;
  final ui.Color color;

  @override
  bool operator ==(Object other) =>
      other is _Key &&
      other.text == text &&
      other.height == height &&
      other.wrapWidth == wrapWidth &&
      other.hAlign == hAlign &&
      other.isMultiline == isMultiline &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(text, height, wrapWidth, hAlign, isMultiline, color);
}
