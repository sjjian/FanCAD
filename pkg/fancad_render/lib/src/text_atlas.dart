import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'batch.dart';
import 'text_cache.dart';

/// Rasterised text runs packed into a few pages and drawn with [ui.Canvas.drawAtlas].
///
/// A settled CAD sheet can show a thousand labels at once. Each one used to be
/// a `drawParagraph`, which records a shaped text run the compositor has to
/// walk again on every pan and zoom. Rasterising a run once and then drawing it
/// as a sprite turns that per-frame cost into a handful of atlas draws.
///
/// Runs are rendered white and tinted per sprite. Sizing follows
/// [ParagraphCache.heightBand], so a zoom only has to rebuild when it crosses a
/// band rather than at every wheel notch. The atlas owns the page images and
/// must be disposed with its painter.
class TextAtlas {
  TextAtlas({
    required ParagraphCache paragraphs,
    required this.fallbackFamily,
    this.pageWidth = 1024,
    this.maxPageHeight = 1024,
    this.maxPages = 6,
    this.padding = 2,
  }) : _paragraphs = paragraphs;

  final ParagraphCache _paragraphs;

  /// Face used when a run did not resolve one of its own.
  final String fallbackFamily;

  final int pageWidth;
  final int maxPageHeight;
  final int maxPages;

  /// Transparent space around each run, so antialiasing and a glyph overhang
  /// are not clipped by the page edge.
  final int padding;

  final Map<_AtlasKey, _AtlasEntry> _entries = {};
  final List<_AtlasPage> _pages = [];

  /// Runs that are wider or taller than a page. Repeating the layout every
  /// frame would defeat the point of the cache, so remember the refusal.
  final LinkedHashSet<_AtlasKey> _rejected = LinkedHashSet();

  int _frame = 0;
  int _createdThisFrame = 0;

  int get length => _entries.length;
  int get pageCount => _pages.length;

  /// Runs laid out for the first time during the current [beginFrame].
  int get createdThisFrame => _createdThisFrame;

  /// True while a page still has runs that have not reached its image.
  bool get hasPendingWork {
    for (final page in _pages) {
      if (page.needsBuild) return true;
    }
    return false;
  }

  void beginFrame() {
    _frame++;
    _createdThisFrame = 0;
  }

  /// Looks up [item], optionally laying it out and packing it into a page.
  ///
  /// A sprite can come back before its page has been rendered. The caller has
  /// to check [TextAtlasSprite.isReady] after [buildOnePage] and fall back to a
  /// paragraph for that frame.
  TextAtlasSprite? tryObtain(
    TextItem item, {
    required String fontFamily,
    bool allowCreate = true,
  }) {
    final band = ParagraphCache.heightBand(item.pixelHeight);
    if (!band.isFinite || band <= 0) return null;
    final scale = item.pixelHeight / band;
    if (!scale.isFinite || scale <= 0) return null;
    final wrap = item.wrapWidth <= 0
        ? double.infinity
        : ParagraphCache.quantiseHeight(item.wrapWidth / scale);
    final key = _AtlasKey(
      text: item.text,
      band: band,
      wrap: wrap,
      hAlign: item.hAlign,
      isMultiline: item.isMultiline,
      fontFamily: fontFamily,
      tracking: item.tracking,
      widthFactor: item.widthFactor,
    );
    final existing = _entries[key];
    if (existing != null) {
      existing.page.lastUsedFrame = _frame;
      return TextAtlasSprite._(existing);
    }
    if (!allowCreate || _rejected.contains(key)) return null;
    if (!item.widthFactor.isFinite || item.widthFactor <= 0) return null;
    if (_rejected.length > 512) _rejected.remove(_rejected.first);

    final paragraph = _paragraphs.obtain(
      TextItem(
        text: item.text,
        origin: ui.Offset.zero,
        pixelHeight: band,
        rotation: 0,
        color: const ui.Color(0xFFFFFFFF),
        hAlign: item.hAlign,
        vAlign: 0,
        wrapWidth: wrap,
        isMultiline: item.isMultiline,
        tracking: item.tracking,
        fontFamily: fontFamily,
      ),
      fontFamily: fontFamily,
    );
    if (paragraph.width <= 0 || paragraph.height <= 0) return null;

    final width = (paragraph.width * item.widthFactor + padding * 2)
        .ceilToDouble();
    final height = (paragraph.height + padding * 2).ceilToDouble();
    if (width > pageWidth || height > maxPageHeight) {
      _rejected.add(key);
      return null;
    }

    _AtlasPage? page;
    ui.Rect? rect;
    for (final candidate in _pages) {
      rect = candidate.allocate(width, height);
      if (rect != null) {
        page = candidate;
        break;
      }
    }
    if (page == null) {
      if (_pages.length >= maxPages) _evictOldestPage();
      page = _AtlasPage(
        width: pageWidth,
        maxHeight: maxPageHeight,
        initialHeight: math.min(256, maxPageHeight),
      );
      _pages.add(page);
      rect = page.allocate(width, height);
    }
    if (rect == null) return null;

    final entry = _AtlasEntry(
      key: key,
      page: page,
      rect: rect,
      paragraph: paragraph,
      band: band,
      padding: padding.toDouble(),
      maxIntrinsicWidth: paragraph.maxIntrinsicWidth,
      paragraphHeight: paragraph.height,
      baseline: paragraph.alphabeticBaseline,
      widthFactor: item.widthFactor,
      builtRevision: page.revision + 1,
    );
    page.entries.add(entry);
    _entries[key] = entry;
    page.lastUsedFrame = _frame;
    _createdThisFrame++;
    return TextAtlasSprite._(entry);
  }

  /// Renders at most one dirty page. One page per frame keeps the first warm
  /// up from turning into a visible pause.
  bool buildOnePage() {
    for (final page in _pages) {
      if (!page.needsBuild) continue;
      page.build();
      return true;
    }
    return false;
  }

  void _evictOldestPage() {
    if (_pages.isEmpty) return;
    var oldest = _pages.first;
    for (final page in _pages) {
      if (page.lastUsedFrame < oldest.lastUsedFrame) oldest = page;
    }
    for (final entry in oldest.entries) {
      if (identical(_entries[entry.key], entry)) _entries.remove(entry.key);
    }
    oldest.dispose();
    _pages.remove(oldest);
  }

  void clear() {
    for (final page in _pages) {
      page.dispose();
    }
    _pages.clear();
    _entries.clear();
    _rejected.clear();
  }

  void dispose() {
    clear();
  }
}

class TextAtlasSprite {
  const TextAtlasSprite._(this._entry);

  final _AtlasEntry _entry;

  /// The page image, or null until the page has been rendered.
  ui.Image? get image => _entry.page.image;

  /// Where the padded run sits on [image].
  ui.Rect get rect => _entry.rect;

  /// Height the run was laid out at.
  double get band => _entry.band;

  /// Transparent padding on each side of the run.
  double get padding => _entry.padding;

  double get maxIntrinsicWidth => _entry.maxIntrinsicWidth;
  double get paragraphHeight => _entry.paragraphHeight;
  double get baseline => _entry.baseline;

  bool get isReady =>
      _entry.page.image != null && _entry.page.revision >= _entry.builtRevision;
}

class _AtlasPage {
  _AtlasPage({
    required this.width,
    required this.maxHeight,
    required int initialHeight,
  }) : height = initialHeight;

  final int width;
  final int maxHeight;
  int height;
  ui.Image? image;
  int revision = 0;
  int lastUsedFrame = 0;

  final List<_AtlasEntry> entries = [];
  double _cursorX = 0;
  double _cursorY = 0;
  double _rowHeight = 0;

  bool get needsBuild {
    if (entries.isEmpty) return false;
    for (final entry in entries) {
      if (entry.builtRevision > revision) return true;
    }
    return false;
  }

  ui.Rect? allocate(double w, double h) {
    if (w > width || h > maxHeight) return null;
    var x = _cursorX;
    var y = _cursorY;
    var row = _rowHeight;
    var grown = height;
    if (x + w > width) {
      x = 0;
      y += row;
      row = 0;
    }
    while (y + h > grown) {
      if (grown >= maxHeight) return null;
      grown = math.min(maxHeight, grown * 2);
    }
    _cursorX = x + w + 1;
    _cursorY = y;
    _rowHeight = math.max(row, h + 1);
    height = grown;
    return ui.Rect.fromLTWH(x, y, w, h);
  }

  void build() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final previous = image;
    if (previous != null) {
      canvas.drawImage(previous, ui.Offset.zero, ui.Paint());
    }
    for (final entry in entries) {
      if (entry.builtRevision <= revision) continue;
      canvas.save();
      canvas.translate(
        entry.rect.left + entry.padding,
        entry.rect.top + entry.padding,
      );
      if (entry.widthFactor != 1) canvas.scale(entry.widthFactor, 1);
      canvas.drawParagraph(entry.paragraph, ui.Offset.zero);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final next = picture.toImageSync(width, height);
    picture.dispose();
    previous?.dispose();
    image = next;
    revision++;
  }

  void dispose() {
    image?.dispose();
    image = null;
    entries.clear();
    _cursorX = 0;
    _cursorY = 0;
    _rowHeight = 0;
  }
}

class _AtlasEntry {
  _AtlasEntry({
    required this.key,
    required this.page,
    required this.rect,
    required this.paragraph,
    required this.band,
    required this.padding,
    required this.maxIntrinsicWidth,
    required this.paragraphHeight,
    required this.baseline,
    required this.widthFactor,
    required this.builtRevision,
  });

  final _AtlasKey key;
  final _AtlasPage page;
  final ui.Rect rect;
  final ui.Paragraph paragraph;
  final double band;
  final double padding;
  final double maxIntrinsicWidth;
  final double paragraphHeight;
  final double baseline;
  final double widthFactor;

  /// Page revision that will contain this run.
  final int builtRevision;
}

class _AtlasKey {
  const _AtlasKey({
    required this.text,
    required this.band,
    required this.wrap,
    required this.hAlign,
    required this.isMultiline,
    required this.fontFamily,
    required this.tracking,
    required this.widthFactor,
  });

  final String text;
  final double band;
  final double wrap;
  final int hAlign;
  final bool isMultiline;
  final String fontFamily;
  final double tracking;
  final double widthFactor;

  @override
  bool operator ==(Object other) =>
      other is _AtlasKey &&
      other.text == text &&
      other.band == band &&
      other.wrap == wrap &&
      other.hAlign == hAlign &&
      other.isMultiline == isMultiline &&
      other.fontFamily == fontFamily &&
      other.tracking == tracking;

  @override
  int get hashCode =>
      Object.hash(text, band, wrap, hAlign, isMultiline, fontFamily, tracking);
}
