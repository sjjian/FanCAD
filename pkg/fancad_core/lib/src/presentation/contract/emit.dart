import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../geometry/bounds.dart';
import '../../geometry/matrix.dart';
import '../../geometry/vector.dart';
import '../../model/entity/text_alignment.dart';
import '../../model/style.dart';
import '../style/resolved_style.dart';
import '../text/shx_font_table.dart';

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
    var box = const Bounds2.empty();
    for (final corner in estimatedCorners()) {
      box = box.expandToInclude(corner.x, corner.y);
    }
    return box;
  }

  /// The four corners of [estimatedBounds], still in drawing coordinates, so a
  /// rotated note ghosts as a parallelogram rather than an axis-aligned box.
  List<Vec2> estimatedCorners() {
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

    return [
      Vec2(dx, dy).rotated(rotation) + origin,
      Vec2(dx + width, dy).rotated(rotation) + origin,
      Vec2(dx + width, dy + totalHeight).rotated(rotation) + origin,
      Vec2(dx, dy + totalHeight).rotated(rotation) + origin,
    ];
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
  final scale = context.transform.isIdentity
      ? 1.0
      : context.transform.meanScale;
  // The entity height is the text that is actually placed. A fixed STYLE
  // height is only the default for new text, and drawings that were scaled or
  // exploded carry the effective height on the entity while the style keeps
  // its original value. Letting the style win there shrinks title-block
  // values by the block scale.
  final styleHeight = height > 0 ? height : style.height;
  return TextGeometry(
    text: text,
    origin: context.apply(origin),
    height: styleHeight * scale,
    rotation: context.transform.transformAngle(rotation),
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

/// True when [text] cannot be a txt.shx shape (CJK, symbols, etc.).
bool _hasHighCodepoint(String text) {
  for (final unit in text.runes) {
    if (unit > 0xFF) return true;
  }
  return false;
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
  // txt.shx only has 8-bit shapes. A CJK note would be masked into a random
  // stroke or dropped; those strings stay on the TTF path.
  if (font != null && !_hasHighCodepoint(text)) {
    final styleHeight = height > 0 ? height : def.height;
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
    // MTEXT already put the box corner on [origin]; applying the TEXT
    // baseline table here would lift the paragraph by a full line.
    final dy = switch (anchor) {
      TextAnchor.box => switch (vAlign) {
        TextVAlign.middle => -styleHeight / 2,
        TextVAlign.bottom => -styleHeight,
        _ => 0.0,
      },
      TextAnchor.baseline => switch (vAlign) {
        TextVAlign.baseline || TextVAlign.bottom => 0.0,
        TextVAlign.middle => -styleHeight / 2,
        TextVAlign.top => -styleHeight,
      },
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

/// Receives analytic object-snap points in the entity's own coordinates.
///
/// Distinct from [GeometrySink]: a circle's centre is not a flattened
/// vertex. The snap engine implements this and applies OSMODE, aperture and
/// priority. Entities never see those.
abstract class ObjectSnapSink {
  void endpoint(Vec2 point);
  void midpoint(Vec2 point);
  void center(Vec2 point);
  void quadrant(Vec2 point);
  void node(Vec2 point);

  /// A straight segment, for a perpendicular foot along the chord.
  void segment(Vec2 start, Vec2 end);

  /// A circular curve, for perpendicular and tangent snaps.
  void circle(Vec2 center, double radius);
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
    this.minExtent = 0,
    this.extentHint,
    this.blockPath = const {},
    this.pixelsPerUnit = 0,
    this.query,
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

  /// World-space size below which a primitive is a pixel, not a shape.
  ///
  /// Compared after [transform] is applied, so nested inserts keep this
  /// value as they descend. Zero disables collapsing, which is what pick,
  /// print and hover outlines want: they re-emit the definition, not the
  /// overview's level of detail.
  final double minExtent;

  /// Optional box in the entity's own coordinates, usually from the spatial
  /// index. Types that collapse when small use it so a spline does not have
  /// to tessellate just to decide it is a pixel.
  final Bounds2? extentHint;

  /// Blocks currently being emitted on this path. A self-referential INSERT
  /// would otherwise expand forever (or until the depth cap with an
  /// exponential number of paths).
  final Set<String> blockPath;

  /// Logical screen pixels per drawing unit for the current camera.
  ///
  /// Zero when the caller has no viewport (plot, picking, bounds). Entity
  /// emitters use it to skip work that cannot be seen, such as laying out
  /// text that would collapse to a bar.
  final double pixelsPerUnit;

  /// The visible region in output coordinates, or null to emit everything.
  ///
  /// Scene builds set it so a block emits only the entities its index places
  /// inside the view. Without it a nested block walks its whole definition,
  /// and a drawing whose blocks fan out into millions of off-screen leaves
  /// takes seconds to open at overview zoom.
  final Bounds2? query;

  static const int maxDepth = 32;

  bool get canRecurse => depth < maxDepth;

  ResolvedStyle styleFor(EntityProps props) =>
      styles.resolve(props, inheritedStyle);

  /// True when [world] is smaller than [minExtent] on both axes.
  bool isSubPixelWorld(Bounds2 world) =>
      minExtent > 0 &&
      world.isNotEmpty &&
      world.width < minExtent &&
      world.height < minExtent;

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

  EmitContext descend(
    Mat3 childTransform,
    ResolvedStyle style, {
    String? blockName,
  }) => EmitContext(
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
    minExtent: minExtent,
    extentHint: null,
    blockPath: blockName == null ? blockPath : {...blockPath, blockName},
    pixelsPerUnit: pixelsPerUnit,
    query: query,
  );

  /// This context with another block lookup.
  ///
  /// A renderer can wrap the document in a display-list cache without changing
  /// any other part of the emit decision.
  EmitContext withBlocks(BlockLookup value) => EmitContext(
    tolerance: tolerance,
    transform: transform,
    blocks: value,
    styles: styles,
    inheritedStyle: inheritedStyle,
    depth: depth,
    clip: clip,
    measureWidth: measureWidth,
    attributeValues: attributeValues,
    shxFonts: shxFonts,
    pointDisplay: pointDisplay,
    minExtent: minExtent,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: pixelsPerUnit,
    query: query,
  );

  /// This context with another current transform.
  ///
  /// Used when flattening a block definition once in its own coordinates; the
  /// resulting display list is transformed again for each insert instance.
  EmitContext withTransform(Mat3 value) => EmitContext(
    tolerance: tolerance,
    transform: value,
    blocks: blocks,
    styles: styles,
    inheritedStyle: inheritedStyle,
    depth: depth,
    clip: clip,
    measureWidth: measureWidth,
    attributeValues: attributeValues,
    shxFonts: shxFonts,
    pointDisplay: pointDisplay,
    minExtent: minExtent,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: pixelsPerUnit,
    query: query,
  );

  EmitContext withMinExtent(double value) => EmitContext(
    tolerance: tolerance,
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
    minExtent: value,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: pixelsPerUnit,
    query: query,
  );

  EmitContext withPixelsPerUnit(double value) => EmitContext(
    tolerance: tolerance,
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
    minExtent: minExtent,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: value,
    query: query,
  );

  EmitContext withQuery(Bounds2? value) => EmitContext(
    tolerance: tolerance,
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
    minExtent: minExtent,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: pixelsPerUnit,
    query: value,
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
    minExtent: minExtent,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: pixelsPerUnit,
    query: query,
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
    minExtent: minExtent,
    extentHint: extentHint,
    blockPath: blockPath,
    pixelsPerUnit: pixelsPerUnit,
    query: query,
  );

  /// Box used for this entity's own level-of-detail, in its coordinates.
  ///
  /// Nested [descend] drops the hint: a child lives in a different space.
  EmitContext withExtentHint(Bounds2? value) {
    if (identical(value, extentHint)) return this;
    return EmitContext(
      tolerance: tolerance,
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
      minExtent: minExtent,
      extentHint: value,
      blockPath: blockPath,
      pixelsPerUnit: pixelsPerUnit,
      query: query,
    );
  }

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
      minExtent: minExtent,
      extentHint: extentHint,
      blockPath: blockPath,
      pixelsPerUnit: pixelsPerUnit,
      query: query,
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
