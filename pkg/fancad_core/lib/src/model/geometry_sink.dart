import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../text/shx_font.dart';
import 'style.dart';

part 'geometry_sink.freezed.dart';

/// A style with every inheritance sentinel already resolved.
///
/// This is the batching key for the renderer: primitives that share a
/// [ResolvedStyle] can be merged into a single draw call, which is what keeps
/// large drawings interactive.
@freezed
abstract class ResolvedStyle with _$ResolvedStyle {
  const ResolvedStyle._();

  const factory ResolvedStyle({
    required String layer,
    required CadColor color,
    required String lineType,
    required int lineWeight,
    @Default(1) double lineTypeScale,
    @Default(0) int transparency,
  }) = _ResolvedStyle;

  static const ResolvedStyle fallback = ResolvedStyle(
    layer: '0',
    color: CadColor.indexed(7),
    lineType: 'Continuous',
    lineWeight: LineWeight.zero,
  );
}

/// Turns an entity's declared attributes into a [ResolvedStyle].
///
/// The document implements this against its symbol tables; block references
/// pass their own resolved style down as [inherited] so that `ByBlock`
/// resolves the way AutoCAD defines it.
abstract class StyleResolver {
  ResolvedStyle resolve(EntityProps props, ResolvedStyle inherited);

  /// Whether the named layer should be drawn and picked at all.
  bool isLayerVisible(String layer);

  /// The named dimension style, or Standard when the name is missing.
  DimStyleDef dimStyle(String name) => DimStyleDef.standard;

  /// The named text style, or Standard when the name is missing.
  TextStyleDef textStyle(String name) => TextStyleDef.standard;

  static const StyleResolver passthrough = _PassthroughResolver();
}

class _PassthroughResolver implements StyleResolver {
  const _PassthroughResolver();

  @override
  ResolvedStyle resolve(EntityProps props, ResolvedStyle inherited) {
    final color = switch (props.color.kind) {
      ColorKind.byLayer => const CadColor.indexed(7),
      ColorKind.byBlock => inherited.color,
      _ => props.color,
    };
    return ResolvedStyle(
      layer: props.layer,
      color: color,
      lineType: props.lineType == 'ByLayer' || props.lineType == 'ByBlock'
          ? inherited.lineType
          : props.lineType,
      lineWeight: props.lineWeight < 0
          ? inherited.lineWeight
          : props.lineWeight,
      lineTypeScale: props.lineTypeScale,
      transparency: props.transparency < 0 ? 0 : props.transparency,
    );
  }

  @override
  bool isLayerVisible(String layer) => true;

  @override
  DimStyleDef dimStyle(String name) => DimStyleDef.standard;

  @override
  TextStyleDef textStyle(String name) => TextStyleDef.standard;
}

/// Horizontal text justification.
enum TextHAlign { left, center, right, aligned, middle, fit }

/// Vertical text justification.
enum TextVAlign { baseline, bottom, middle, top }

/// Where [TextGeometry.origin] sits on the laid-out run.
///
/// TEXT uses the DWG baseline (or a justification point on that baseline).
/// MTEXT's attachment point is a corner or centre of the box, so applying
/// the baseline table a second time lifts the paragraph by a full line.
enum TextAnchor { baseline, box }

/// A laid-out text run in model coordinates.
@immutable
class TextGeometry {
  const TextGeometry({
    required this.text,
    required this.origin,
    required this.height,
    required this.rotation,
    required this.styleName,
    this.fontFamily = '',
    this.bigFontFamily = '',
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.tracking = 1,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
    this.anchor = TextAnchor.baseline,
    this.backwards = false,
    this.upsideDown = false,
    this.underline = false,
    this.overline = false,
    this.strike = false,
    this.rectangleWidth = 0,
    this.isMultiline = false,
  });

  final String text;
  final Vec2 origin;
  final double height;
  final double rotation;
  final String styleName;

  /// STYLE font name or an MTEXT `\f` override, still as recorded in the
  /// drawing. The renderer maps it onto a system face.
  final String fontFamily;
  final String bigFontFamily;
  final double widthFactor;
  final double obliqueAngle;

  /// MTEXT `\T` tracking factor. 1 is the style default.
  final double tracking;
  final TextHAlign hAlign;
  final TextVAlign vAlign;
  final TextAnchor anchor;
  final bool backwards;
  final bool upsideDown;
  final bool underline;
  final bool overline;
  final bool strike;

  /// Wrapping width for MTEXT; 0 means unbounded.
  final double rectangleWidth;
  final bool isMultiline;

  /// Conservative model-space extents without a font engine. The importer runs
  /// on a background isolate where no text shaper is available, so bounds and
  /// the spatial index are seeded with this estimate and refined lazily by the
  /// renderer once the glyphs are actually measured.
  Bounds2 estimatedBounds() {
    final lines = isMultiline ? text.split('\n') : [text];
    var longest = 0;
    for (final line in lines) {
      if (line.length > longest) longest = line.length;
    }
    final width = rectangleWidth > 0
        ? rectangleWidth
        : longest * height * 0.62 * widthFactor * tracking;
    final totalHeight = height * lines.length * 1.2;

    final dx = switch (hAlign) {
      TextHAlign.left => 0.0,
      TextHAlign.center || TextHAlign.middle || TextHAlign.fit => -width / 2,
      TextHAlign.right => -width,
      TextHAlign.aligned => 0.0,
    };
    final dy = switch (vAlign) {
      TextVAlign.baseline || TextVAlign.bottom => 0.0,
      TextVAlign.middle => -totalHeight / 2,
      TextVAlign.top => -totalHeight,
    };

    final corners = [
      Vec2(dx, dy),
      Vec2(dx + width, dy),
      Vec2(dx + width, dy + totalHeight),
      Vec2(dx, dy + totalHeight),
    ];
    var box = const Bounds2.empty();
    for (final corner in corners) {
      final rotated = corner.rotated(rotation) + origin;
      box = box.expandToInclude(rotated.x, rotated.y);
    }
    return box;
  }
}

/// Looks up a parsed SHX face by the STYLE `fontFamily`.
///
/// `txt`, `txt.shx` and `TXT.SHX` are the same key. The table only holds
/// fonts the caller already parsed; core does not search the disk.
@immutable
class ShxFontTable {
  const ShxFontTable([this._byFamily = const {}]);

  final Map<String, ShxFont> _byFamily;

  static const ShxFontTable empty = ShxFontTable();

  bool get isEmpty => _byFamily.isEmpty;

  /// The named face, or null when the table has no matching non-empty font.
  ShxFont? lookup(String family) {
    if (family.isEmpty || _byFamily.isEmpty) return null;
    final key = normalizeFamily(family);
    final direct = _byFamily[key] ?? _byFamily[family];
    if (direct != null) return direct.isEmpty ? null : direct;
    for (final entry in _byFamily.entries) {
      if (normalizeFamily(entry.key) == key) {
        return entry.value.isEmpty ? null : entry.value;
      }
    }
    return null;
  }

  static String normalizeFamily(String family) {
    var name = family.trim().toLowerCase();
    if (name.endsWith('.shx')) {
      name = name.substring(0, name.length - 4);
    }
    return name;
  }
}

/// Folds a STYLE table entry into a text run so the renderer never has to
/// look the style up again.
TextGeometry composeEmittedText({
  required EmitContext context,
  required String text,
  required Vec2 origin,
  required double height,
  required double rotation,
  required String styleName,
  double widthFactor = 1,
  double obliqueAngle = 0,
  double tracking = 1,
  TextHAlign hAlign = TextHAlign.left,
  TextVAlign vAlign = TextVAlign.baseline,
  TextAnchor anchor = TextAnchor.baseline,
  String? fontOverride,
  bool underline = false,
  bool overline = false,
  bool strike = false,
}) {
  final style = context.styles.textStyle(styleName);
  final scale = context.transform.isIdentity ? 1.0 : context.transform.meanScale;
  final styleHeight = style.height > 0 ? style.height : height;
  return TextGeometry(
    text: text,
    origin: context.apply(origin),
    height: styleHeight * scale,
    rotation: rotation + context.transform.rotation,
    styleName: styleName,
    fontFamily: fontOverride ?? style.fontFamily,
    bigFontFamily: style.bigFontFamily,
    widthFactor: widthFactor * style.widthFactor,
    obliqueAngle: obliqueAngle + style.obliqueAngle,
    tracking: tracking,
    hAlign: hAlign,
    vAlign: vAlign,
    anchor: anchor,
    backwards: style.backwards,
    upsideDown: style.upsideDown,
    underline: underline,
    overline: overline,
    strike: strike,
  );
}

/// Emits [text] as SHX strokes when the style is a loaded shape font,
/// otherwise as [TextGeometry] for the TTF fallback.
void emitStyledText({
  required EmitContext context,
  required GeometrySink sink,
  required ResolvedStyle style,
  required String text,
  required Vec2 origin,
  required double height,
  required double rotation,
  required String styleName,
  double widthFactor = 1,
  double obliqueAngle = 0,
  double tracking = 1,
  TextHAlign hAlign = TextHAlign.left,
  TextVAlign vAlign = TextVAlign.baseline,
  TextAnchor anchor = TextAnchor.baseline,
  String? fontOverride,
  bool underline = false,
  bool overline = false,
  bool strike = false,
}) {
  if (text.isEmpty) return;
  final def = context.styles.textStyle(styleName);
  final family = (fontOverride != null && fontOverride.isNotEmpty)
      ? fontOverride
      : def.fontFamily;
  final wantsShx = (fontOverride != null && fontOverride.isNotEmpty)
      ? TextStyleDef(name: '', fontFamily: family).isShxFont
      : def.isShxFont;
  final font = wantsShx ? context.shxFonts.lookup(family) : null;
  if (font != null) {
    final styleHeight = def.height > 0 ? def.height : height;
    final factor = widthFactor * def.widthFactor;
    final width = font.measureWidth(
      text,
      height: styleHeight,
      widthFactor: factor,
    );
    final dx = switch (hAlign) {
      TextHAlign.left || TextHAlign.aligned || TextHAlign.fit => 0.0,
      TextHAlign.center || TextHAlign.middle => -width / 2,
      TextHAlign.right => -width,
    };
    final dy = switch (vAlign) {
      TextVAlign.baseline || TextVAlign.bottom => 0.0,
      TextVAlign.middle => -styleHeight / 2,
      TextVAlign.top => -styleHeight,
    };
    final start = (dx == 0 && dy == 0)
        ? origin
        : origin + Vec2(dx, dy).rotated(rotation);
    final strokes = font.layout(
      text,
      origin: start,
      height: styleHeight,
      rotation: rotation,
      widthFactor: factor,
    );
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final xy = Float64List(stroke.length * 2);
      for (var i = 0; i < stroke.length; i++) {
        xy[i * 2] = stroke[i].x;
        xy[i * 2 + 1] = stroke[i].y;
      }
      sink.polyline(context.applyBuffer(xy), style);
    }
    return;
  }
  sink.text(
    composeEmittedText(
      context: context,
      text: text,
      origin: origin,
      height: height,
      rotation: rotation,
      styleName: styleName,
      widthFactor: widthFactor,
      obliqueAngle: obliqueAngle,
      tracking: tracking,
      hAlign: hAlign,
      vAlign: vAlign,
      anchor: anchor,
      fontOverride: fontOverride,
      underline: underline,
      overline: overline,
      strike: strike,
    ),
    style,
  );
}

/// A raster image placement in model space.
@immutable
class ImageGeometry {
  const ImageGeometry({
    required this.reference,
    required this.origin,
    required this.uVector,
    required this.vVector,
    this.brightness = 50,
    this.contrast = 50,
    this.fade = 0,
  });

  /// The external file path or DWG image definition key.
  final String reference;
  final Vec2 origin;

  /// Edge vectors spanning the full placed size of the image.
  final Vec2 uVector;
  final Vec2 vVector;
  final int brightness;
  final int contrast;
  final int fade;

  List<Vec2> get corners => [
    origin,
    origin + uVector,
    origin + uVector + vVector,
    origin + vVector,
  ];
}

/// Receives the flattened geometry of entities in model coordinates.
///
/// Every consumer of entity geometry goes through this interface: the
/// renderer builds draw batches, the hit-tester builds pick candidates, the
/// bounds calculator accumulates a box, and exporters write files. Adding a new
/// entity type therefore only requires implementing `CadEntity.emit`.
abstract class GeometrySink {
  /// An open or closed run of straight segments, interleaved `[x, y, ...]`.
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false});

  /// A filled region. [holes] are inner rings to be subtracted.
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  });

  /// A single point marker (POINT entities, node snaps).
  void point(double x, double y, ResolvedStyle style);

  /// A text run. The sink is responsible for shaping and layout.
  void text(TextGeometry geometry, ResolvedStyle style);

  /// A raster image placement.
  void image(ImageGeometry geometry, ResolvedStyle style);
}

/// Resolves block definitions during emission of block references.
abstract class BlockLookup {
  /// The entity ids owned by the named block, or null when it is missing.
  List<int>? entityIdsOf(String blockName);

  /// Emits the contents of the named block.
  void emitBlock(String blockName, EmitContext context, GeometrySink sink);

  /// The cached bounds of a block definition in its own coordinate system.
  Bounds2 boundsOf(String blockName);

  static const BlockLookup empty = _EmptyBlockLookup();
}

class _EmptyBlockLookup implements BlockLookup {
  const _EmptyBlockLookup();

  @override
  List<int>? entityIdsOf(String blockName) => null;

  @override
  void emitBlock(String blockName, EmitContext context, GeometrySink sink) {}

  @override
  Bounds2 boundsOf(String blockName) => const Bounds2.empty();
}

/// POINT glyph from `$PDMODE` / `$PDSIZE`.
///
/// The low three bits are the symbol: 0 is AutoCAD's one-pixel dot, 1 is
/// none, 2–4 are plus / cross / tick. Bits 32 and 64 add a circle or square.
/// A drawing that never wrote `$PDMODE` keeps FanCAD's visible marker so a
/// new POINT is not silently blank.
@immutable
class PointDisplay {
  const PointDisplay({this.mode = 0, this.size = 0, this.fromHeader = false});

  final int mode;
  final double size;

  /// True when the values came from `$PDMODE` / `$PDSIZE` on the drawing.
  final bool fromHeader;

  static const PointDisplay missing = PointDisplay();

  /// Shape in 0…4.
  int get symbol => mode & 7;

  /// Whether [PointEntity] should send a marker to the sink.
  bool get showsMarker {
    if (!fromHeader) return true;
    return symbol != 0 && symbol != 1;
  }

  static PointDisplay fromHeaders(Map<String, String> headers) {
    final rawMode = headers[r'$PDMODE'];
    if (rawMode == null || rawMode.isEmpty) return PointDisplay.missing;
    return PointDisplay(
      mode: int.tryParse(rawMode) ?? 0,
      size: double.tryParse(headers[r'$PDSIZE'] ?? '') ?? 0,
      fromHeader: true,
    );
  }
}

/// Everything an entity needs in order to flatten itself.
@immutable
class EmitContext {
  const EmitContext({
    required this.tolerance,
    this.transform = const Mat3.identity(),
    this.blocks = BlockLookup.empty,
    this.styles = StyleResolver.passthrough,
    this.inheritedStyle = ResolvedStyle.fallback,
    this.depth = 0,
    this.clip,
    this.measureWidth,
    this.attributeValues,
    this.shxFonts = const ShxFontTable(),
    this.pointDisplay = PointDisplay.missing,
  });

  /// Maximum allowed deviation when discretizing curves, in model units.
  final double tolerance;

  /// Accumulated block-reference transform. Entities emit final model
  /// coordinates, so nested inserts compose into this single matrix.
  final Mat3 transform;

  final BlockLookup blocks;
  final StyleResolver styles;

  /// The style that `ByBlock` resolves against.
  final ResolvedStyle inheritedStyle;

  /// Nesting depth, used to stop runaway self-referential blocks.
  final int depth;

  /// Optional model-space cull box. Block references outside it may skip
  /// recursing into their definition.
  final Bounds2? clip;

  /// Measured advance of a text run, used by MTEXT wrapping. Null falls
  /// back to 0.6 em per character when no SHX is loaded.
  final double Function(String text, double height)? measureWidth;

  /// Tag → value while emitting a block through an insert. Null means the
  /// block is being drawn as a definition, so ATTDEFs show their defaults.
  final Map<String, String>? attributeValues;

  /// Parsed SHX faces for STYLE names. Empty keeps the TTF text path.
  final ShxFontTable shxFonts;

  /// `$PDMODE` / `$PDSIZE` for POINT entities.
  final PointDisplay pointDisplay;

  static const int maxDepth = 32;

  bool get canRecurse => depth < maxDepth;

  ResolvedStyle styleFor(EntityProps props) =>
      styles.resolve(props, inheritedStyle);

  /// Transforms a model point through the accumulated block transform.
  Vec2 apply(Vec2 point) =>
      transform.isIdentity ? point : transform.transform(point);

  /// Transforms an interleaved buffer in place-equivalent fashion, returning a
  /// new buffer. Identity transforms are passed through untouched to avoid a
  /// copy in the common top-level case.
  Float64List applyBuffer(Float64List xy) {
    if (transform.isIdentity) return xy;
    final out = Float64List(xy.length);
    for (var i = 0; i < xy.length; i += 2) {
      transform.transformXYInto(xy[i], xy[i + 1], out, i);
    }
    return out;
  }

  /// Tolerance measured in the *local* space of a nested block, so that a tiny
  /// block scaled up 1000x still gets smooth curves.
  double localTolerance(Mat3 childTransform) {
    final scale = childTransform.meanScale;
    if (scale <= 0 || !scale.isFinite) return tolerance;
    return tolerance / scale;
  }

  EmitContext descend(Mat3 childTransform, ResolvedStyle style) => EmitContext(
    tolerance: localTolerance(childTransform),
    transform: transform.multiplied(childTransform),
    blocks: blocks,
    styles: styles,
    inheritedStyle: style,
    depth: depth + 1,
    clip: clip,
    measureWidth: measureWidth,
    attributeValues: attributeValues,
    shxFonts: shxFonts,
    pointDisplay: pointDisplay,
  );

  EmitContext withTolerance(double value) => EmitContext(
    tolerance: value,
    transform: transform,
    blocks: blocks,
    styles: styles,
    inheritedStyle: inheritedStyle,
    depth: depth,
    clip: clip,
    measureWidth: measureWidth,
    attributeValues: attributeValues,
    shxFonts: shxFonts,
    pointDisplay: pointDisplay,
  );

  EmitContext withAttributeValues(Map<String, String> values) => EmitContext(
    tolerance: tolerance,
    transform: transform,
    blocks: blocks,
    styles: styles,
    inheritedStyle: inheritedStyle,
    depth: depth,
    clip: clip,
    measureWidth: measureWidth,
    attributeValues: values,
    shxFonts: shxFonts,
    pointDisplay: pointDisplay,
  );

  /// Drops [clip] so a tessellation cache cannot bake a miss from a
  /// viewport that only overlapped the insert's index box.
  EmitContext withoutClip() {
    if (clip == null) return this;
    return EmitContext(
      tolerance: tolerance,
      transform: transform,
      blocks: blocks,
      styles: styles,
      inheritedStyle: inheritedStyle,
      depth: depth,
      measureWidth: measureWidth,
      attributeValues: attributeValues,
      shxFonts: shxFonts,
      pointDisplay: pointDisplay,
    );
  }
}

/// A [GeometrySink] that only accumulates a bounding box.
class BoundsSink implements GeometrySink {
  Bounds2 bounds = const Bounds2.empty();

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    bounds = bounds.union(Bounds2.fromXY(xy));
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    bounds = bounds.union(Bounds2.fromXY(xy));
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    bounds = bounds.expandToInclude(x, y);
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    bounds = bounds.union(geometry.estimatedBounds());
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    for (final corner in geometry.corners) {
      bounds = bounds.expandToInclude(corner.x, corner.y);
    }
  }
}

/// A [GeometrySink] that collects flattened primitives, used by hit testing,
/// snapping and exporters that only understand straight segments.
class PolylineSink implements GeometrySink {
  final List<Float64List> polylines = [];
  final List<bool> closedFlags = [];
  final List<Float64List> fills = [];
  final List<TextGeometry> texts = [];
  final List<Vec2> points = [];
  final List<ImageGeometry> images = [];

  bool get isEmpty =>
      polylines.isEmpty &&
      fills.isEmpty &&
      texts.isEmpty &&
      points.isEmpty &&
      images.isEmpty;

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 2) return;
    polylines.add(xy);
    closedFlags.add(closed);
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    fills.add(xy);
    polylines.add(xy);
    closedFlags.add(true);
    for (final hole in holes) {
      polylines.add(hole);
      closedFlags.add(true);
    }
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    points.add(Vec2(x, y));
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    texts.add(geometry);
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    images.add(geometry);
    final corners = geometry.corners;
    polylines.add(
      Float64List.fromList([
        for (final corner in corners) ...[corner.x, corner.y],
      ]),
    );
    closedFlags.add(true);
  }
}
