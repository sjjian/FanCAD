import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/vector.dart';
import '../model/entity.dart';
import '../model/geometry_sink.dart';
import '../model/style.dart';

/// Regenerates dimension graphics when the `*D` anonymous block is missing.
///
/// Imported drawings almost always have that block, and rendering it is the
/// exact, cheap path. This fallback exists so a dimension that has just been
/// edited — which invalidates the cached block — is still visible and still
/// looks like a dimension.
class DimensionGraphics {
  const DimensionGraphics();

  void emit(
    DimensionEntity entity,
    EmitContext context,
    GeometrySink sink,
  ) {
    final style = context.styleFor(entity.props);
    final dim = context.styles.dimStyle(entity.styleName);
    final points = entity.definitionPoints;
    if (points.length < 2) {
      _text(entity, context, sink, style, dim);
      return;
    }

    final family = entity.dimensionType & 0x0F;
    switch (family) {
      case 2:
        _angular(entity, context, sink, style, dim);
      case 3:
      case 4:
        _radial(entity, context, sink, style, dim, diameter: family == 3);
      default:
        _linear(entity, context, sink, style, dim);
    }
    _text(entity, context, sink, style, dim);
  }

  /// Measurement label only. A `*D` block sometimes keeps the strokes and
  /// loses the MTEXT; this puts the number back at [DimensionEntity.textPosition]
  /// without redrawing lines the block already drew.
  void emitText(
    DimensionEntity entity,
    EmitContext context,
    GeometrySink sink,
  ) {
    final style = context.styleFor(entity.props);
    final dim = context.styles.dimStyle(entity.styleName);
    _text(entity, context, sink, style, dim);
  }

  void _linear(
    DimensionEntity entity,
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    DimStyleDef dim,
  ) {
    final points = entity.definitionPoints;
    final p1 = points[0];
    final p2 = points[1];
    final dimLine = points.length > 2 ? points[2] : entity.textPosition;
    // Type 0 with a dim-line pick is DIMLINEAR: the dimension line is
    // horizontal or vertical, not parallel to the two origins.
    if ((entity.dimensionType & 0x0F) == 0 && points.length >= 3) {
      final mid = p1.lerp(p2, 0.5);
      final horizontal =
          (dimLine - mid).y.abs() >= (dimLine - mid).x.abs();
      final a = horizontal ? Vec2(p1.x, dimLine.y) : Vec2(dimLine.x, p1.y);
      final b = horizontal ? Vec2(p2.x, dimLine.y) : Vec2(dimLine.x, p2.y);
      if (a.distanceTo(b) < 1e-9) return;
      final unit = (b - a).normalized();
      _extension(context, sink, style, p1, a, dim);
      _extension(context, sink, style, p2, b, dim);
      _line(context, sink, style, a, b);
      _arrow(context, sink, style, a, unit, dim.scaledArrowSize);
      _arrow(context, sink, style, b, -unit, dim.scaledArrowSize);
      return;
    }
    final direction = p2 - p1;
    if (direction.length < 1e-9) return;
    final unit = direction.normalized();
    final normal = unit.perpendicular;
    var offset = (dimLine - p1).dot(normal);
    if (offset.abs() < 1e-6) offset = (p2 - p1).length * 0.15;
    final a = p1 + normal * offset;
    final b = p2 + normal * offset;
    _extension(context, sink, style, p1, a, dim);
    _extension(context, sink, style, p2, b, dim);
    _line(context, sink, style, a, b);
    _arrow(context, sink, style, a, unit, dim.scaledArrowSize);
    _arrow(context, sink, style, b, -unit, dim.scaledArrowSize);
  }

  void _radial(
    DimensionEntity entity,
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    DimStyleDef dim, {
    required bool diameter,
  }) {
    final center = entity.definitionPoints[0];
    final chord = entity.definitionPoints[1];
    _line(context, sink, style, center, chord);
    if (diameter) {
      _line(context, sink, style, center, center - (chord - center));
    }
    final unit = (chord - center).normalized();
    _arrow(context, sink, style, chord, -unit, dim.scaledArrowSize);
  }

  void _angular(
    DimensionEntity entity,
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    DimStyleDef dim,
  ) {
    final points = entity.definitionPoints;
    if (points.length < 3) {
      _linear(entity, context, sink, style, dim);
      return;
    }
    final vertex = points[0];
    final a = points[1];
    final b = points[2];
    _line(context, sink, style, vertex, a);
    _line(context, sink, style, vertex, b);
    final radius = vertex.distanceTo(entity.textPosition);
    if (radius > 0) {
      final start = (a - vertex).angle;
      final end = (b - vertex).angle;
      final steps = 12;
      final sweep = _sweep(start, end);
      final xy = Float64List((steps + 1) * 2);
      for (var i = 0; i <= steps; i++) {
        final angle = start + sweep * (i / steps);
        final p = context.apply(vertex + Vec2.polar(angle, radius));
        xy[i * 2] = p.x;
        xy[i * 2 + 1] = p.y;
      }
      sink.polyline(xy, style);
    }
  }

  void _text(
    DimensionEntity entity,
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    DimStyleDef dim,
  ) {
    if (entity.overrideText == ' ') return;
    sink.text(
      TextGeometry(
        text: entity.displayTextFor(dim),
        origin: context.apply(entity.textPosition),
        height: dim.scaledTextHeight,
        rotation: 0,
        styleName: dim.textStyle,
        hAlign: TextHAlign.center,
        vAlign: TextVAlign.middle,
      ),
      style,
    );
  }

  void _line(
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    Vec2 a,
    Vec2 b,
  ) {
    final p = context.apply(a);
    final q = context.apply(b);
    sink.polyline(Float64List.fromList([p.x, p.y, q.x, q.y]), style);
  }

  void _extension(
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    Vec2 origin,
    Vec2 dimEnd,
    DimStyleDef dim,
  ) {
    final span = dimEnd - origin;
    final length = span.length;
    if (length < 1e-9) return;
    final unit = span / length;
    final exo = dim.scaledExtensionOffset;
    final exe = dim.scaledExtensionExtend;
    final start = exo >= length ? dimEnd : origin + unit * exo;
    final end = dimEnd + unit * exe;
    if (start.distanceTo(end) < 1e-9) return;
    _line(context, sink, style, start, end);
  }

  void _arrow(
    EmitContext context,
    GeometrySink sink,
    ResolvedStyle style,
    Vec2 tip,
    Vec2 direction,
    double size,
  ) {
    if (direction.length < 1e-9 || size <= 1e-9) return;
    final unit = direction.normalized();
    final left = tip - unit * size + unit.perpendicular * (size * 0.35);
    final right = tip - unit * size - unit.perpendicular * (size * 0.35);
    final t = context.apply(tip);
    final l = context.apply(left);
    final r = context.apply(right);
    sink.fill(
      Float64List.fromList([t.x, t.y, l.x, l.y, r.x, r.y]),
      style,
    );
  }

  static double _sweep(double start, double end) {
    var sweep = end - start;
    while (sweep <= 0) {
      sweep += math.pi * 2;
    }
    return sweep;
  }
}
