part of 'entity.dart';

/// TEXT, MTEXT, ATTRIB, ATTDEF and MLEADER: the note properties DDEDIT, the
/// text overlay and the properties panel read and change.
///
/// A property a type does not have reads as null, and its `with` returns
/// null. Each type lists its fields once, in its `copyWith`, so a new field
/// cannot be dropped by one of these edits.
sealed class TextLike implements CadEntity {
  /// What DDEDIT edits: the content, an attribute's value, or an attribute
  /// definition's default.
  String get content;

  /// Where the note is anchored.
  Vec2 get position;

  double get height;

  /// Radians, counter-clockwise.
  double get rotation;

  String get styleName;

  /// TEXT-style horizontal stretch. MTEXT and MLEADER have none.
  double? get widthFactor;

  /// TEXT-style slant in radians. MTEXT and MLEADER have none.
  double? get obliqueAngle;

  /// MTEXT column width; 0 is unbounded. Only MTEXT has one.
  double? get columnWidth;

  TextLike withContent(String content);

  TextLike withHeight(double height);

  /// Turns the note about [position]. An MLEADER's leader lines stay put.
  TextLike withRotation(double radians);

  TextLike withStyleName(String styleName);

  TextLike? withWidthFactor(double widthFactor);

  TextLike? withObliqueAngle(double radians);

  TextLike? withColumnWidth(double width);
}

/// Text shorter than this many logical pixels is drawn as a placeholder
/// instead of being shaped.
///
/// Below a pixel no glyph can be read, and laying text out is the most
/// expensive part of emitting a label. A drawing with tens of thousands of
/// notes can spend seconds on them at overview zoom. Standard CAD keeps those
/// notes present as quick-text boxes; dropping them makes a zoomed-out sheet
/// look as if the annotations were erased.
const double minimumEmittedTextPixels = 1;

/// Draws a quick-text placeholder when [entity] is a label too small to shape.
///
/// Returns true when the entity is text and [sink] has received a box in its
/// place. [indexBounds] is the entity's spatial-index box in its own
/// coordinates; the box is transformed into output space here. It is kept at
/// least one logical pixel in each direction so a note on an overview never
/// disappears completely.
bool emitTextPlaceholder(
  CadEntity entity,
  EmitContext context,
  GeometrySink sink,
  Bounds2? indexBounds,
) {
  final pixels = textPixelHeight(entity, context);
  if (pixels == null || pixels >= minimumEmittedTextPixels) return false;
  if (indexBounds == null || indexBounds.isEmpty) return true;
  final world = context.transform.isIdentity
      ? indexBounds
      : indexBounds.transformed(context.transform);
  // A sub-pixel box would rasterise to nothing. Grow the axis-aligned extent
  // around its centre until it is at least one logical pixel across.
  final minimumSize = context.pixelsPerUnit > 0
      ? 1 / context.pixelsPerUnit
      : 0.0;
  var left = world.minX;
  var right = world.maxX;
  var bottom = world.minY;
  var top = world.maxY;
  if (minimumSize > 0) {
    if (right - left < minimumSize) {
      final centre = (left + right) / 2;
      left = centre - minimumSize / 2;
      right = centre + minimumSize / 2;
    }
    if (top - bottom < minimumSize) {
      final centre = (top + bottom) / 2;
      bottom = centre - minimumSize / 2;
      top = centre + minimumSize / 2;
    }
  }
  final style = context.styleFor(entity.props);
  sink.fill(
    Float64List.fromList([left, bottom, right, bottom, right, top, left, top]),
    style.copyWith(
      lineType: 'Continuous',
      lineWeight: 0,
      // QtEXT boxes read as a hint, not as opaque ink on top of the drawing.
      transparency: math.max(style.transparency, 50),
    ),
  );
  return true;
}

/// Height of [entity]'s text in logical pixels at the camera in [context], or
/// null when [entity] carries no text or [context] has no camera.
///
/// ATTRIB and ATTDEF are included because they emit their value as text.
/// MLEADER is deliberately not: skipping it would also drop its leader lines,
/// which stay visible however small the note is.
double? textPixelHeight(CadEntity entity, EmitContext context) {
  if (context.pixelsPerUnit <= 0) return null;
  final height = switch (entity) {
    TextEntity(:final height) => height,
    MTextEntity(:final height) => height,
    AttribEntity(:final height) => height,
    AttdefEntity(:final height) => height,
    _ => null,
  };
  if (height == null) return null;
  return height * context.transform.meanScale * context.pixelsPerUnit;
}
