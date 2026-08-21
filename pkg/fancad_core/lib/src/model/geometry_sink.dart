import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import 'style.dart';

/// A style with every inheritance sentinel already resolved.
///
/// This is the batching key for the renderer: primitives that share a
/// [ResolvedStyle] can be merged into a single draw call, which is what keeps
/// large drawings interactive.
@immutable
class ResolvedStyle {
  const ResolvedStyle({
    required this.layer,
    required this.color,
    required this.lineType,
    required this.lineWeight,
    this.lineTypeScale = 1,
    this.transparency = 0,
  });

  static const ResolvedStyle fallback = ResolvedStyle(
    layer: '0',
    color: CadColor.indexed(7),
    lineType: 'Continuous',
    lineWeight: LineWeight.zero,
  );

  final String layer;
  final CadColor color;
  final String lineType;
  final int lineWeight;
  final double lineTypeScale;
  final int transparency;

  ResolvedStyle copyWith({
    String? layer,
    CadColor? color,
    String? lineType,
    int? lineWeight,
    double? lineTypeScale,
    int? transparency,
  }) => ResolvedStyle(
    layer: layer ?? this.layer,
    color: color ?? this.color,
    lineType: lineType ?? this.lineType,
    lineWeight: lineWeight ?? this.lineWeight,
    lineTypeScale: lineTypeScale ?? this.lineTypeScale,
    transparency: transparency ?? this.transparency,
  );

  @override
  bool operator ==(Object other) =>
      other is ResolvedStyle &&
      other.layer == layer &&
      other.color == color &&
      other.lineType == lineType &&
      other.lineWeight == lineWeight &&
      other.lineTypeScale == lineTypeScale &&
      other.transparency == transparency;

  @override
  int get hashCode => Object.hash(
    layer,
    color,
    lineType,
    lineWeight,
    lineTypeScale,
    transparency,
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
}

/// Horizontal text justification.
enum TextHAlign { left, center, right, aligned, middle, fit }

/// Vertical text justification.
enum TextVAlign { baseline, bottom, middle, top }

/// A laid-out text run in model coordinates.
@immutable
class TextGeometry {
  const TextGeometry({
    required this.text,
    required this.origin,
    required this.height,
    required this.rotation,
    required this.styleName,
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
    this.rectangleWidth = 0,
    this.isMultiline = false,
  });

  final String text;
  final Vec2 origin;
  final double height;
  final double rotation;
  final String styleName;
  final double widthFactor;
  final double obliqueAngle;
  final TextHAlign hAlign;
  final TextVAlign vAlign;

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
        : longest * height * 0.62 * widthFactor;
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
  );

  EmitContext withTolerance(double value) => EmitContext(
    tolerance: value,
    transform: transform,
    blocks: blocks,
    styles: styles,
    inheritedStyle: inheritedStyle,
    depth: depth,
    clip: clip,
  );
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
