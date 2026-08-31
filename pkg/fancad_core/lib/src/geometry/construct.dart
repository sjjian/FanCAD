import 'dart:math' as math;
import 'dart:typed_data';

import '../model/entity.dart';
import '../model/geometry_sink.dart';
import '../model/style.dart';
import 'boundary.dart';
import 'bounds.dart';
import 'flatten.dart';
import 'intersect.dart';
import 'vector.dart';

/// The analytic constructions behind the editing commands.
///
/// These are pure functions on entities rather than methods on a tool, because
/// every one of them has three callers: the interactive command, a plugin, and
/// an AI tool call. Keeping them here means those three can never drift apart,
/// and it means each one is directly unit testable.
class Construct {
  const Construct._();

  /// The arc through three points, or null when they are collinear.
  ///
  /// The centre is the circumcentre; the subtlety is the sweep direction, which
  /// has to be chosen so the arc actually passes through [via] rather than
  /// taking the long way round.
  static ArcEntity? arcThrough(
    Vec2 start,
    Vec2 via,
    Vec2 end, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final d =
        2 *
        (start.x * (via.y - end.y) +
            via.x * (end.y - start.y) +
            end.x * (start.y - via.y));
    if (d.abs() < 1e-12) return null;
    final centerX =
        (start.lengthSquared * (via.y - end.y) +
            via.lengthSquared * (end.y - start.y) +
            end.lengthSquared * (start.y - via.y)) /
        d;
    final centerY =
        (start.lengthSquared * (end.x - via.x) +
            via.lengthSquared * (start.x - end.x) +
            end.lengthSquared * (via.x - start.x)) /
        d;
    final center = Vec2(centerX, centerY);
    final radius = center.distanceTo(start);
    if (!radius.isFinite || radius <= 0) return null;

    final startAngle = (start - center).angle;
    final endAngle = (end - center).angle;
    final viaAngle = (via - center).angle;
    // If the counter-clockwise sweep from start to end does not contain the
    // middle point, the arc runs the other way, so the endpoints swap.
    final forward =
        angularSweep(startAngle, viaAngle) <=
        angularSweep(startAngle, endAngle);
    return ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: forward ? startAngle : endAngle,
      endAngle: forward ? endAngle : startAngle,
    );
  }

  /// The unique circle through three points, or null when they are collinear.
  ///
  /// CIRCLE 3P is this construction: the circumcentre is already the arc-through
  /// result, and dropping the sweep leaves the full circle.
  static CircleEntity? circleThrough(
    Vec2 first,
    Vec2 second,
    Vec2 third, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final arc = arcThrough(first, second, third);
    if (arc == null) return null;
    return CircleEntity(
      id: id,
      props: props,
      center: arc.center,
      radius: arc.radius,
    );
  }

  /// A horizontal or vertical dimension between [first] and [second].
  ///
  /// [dimLine] chooses the family: a pick farther above or below the midpoint
  /// measures |Δx|; a pick farther left or right measures |Δy|. That is
  /// DIMLINEAR, not the slanted distance — aligned dimensions are a
  /// different command.
  static DimensionEntity? linearDimension(
    Vec2 first,
    Vec2 second,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
    List<int> sourceIds = const [],
  }) {
    final points = [first, second, dimLine];
    final measurement = DimensionEntity.measuredLength(points, 0);
    if (measurement < 1e-9) return null;
    final mid = first.lerp(second, 0.5);
    final horizontal = (dimLine - mid).y.abs() >= (dimLine - mid).x.abs();
    final a = horizontal ? Vec2(first.x, dimLine.y) : Vec2(dimLine.x, first.y);
    final b = horizontal
        ? Vec2(second.x, dimLine.y)
        : Vec2(dimLine.x, second.y);
    return DimensionEntity(
      id: id,
      props: props,
      definitionPoints: points,
      textPosition: a.lerp(b, 0.5),
      measurement: measurement,
      styleName: styleName,
      sourceIds: sourceIds,
    );
  }

  /// A dimension parallel to the line from [first] to [second].
  ///
  /// DIMALIGNED measures the true distance, not |Δx| or |Δy|. [dimLine]
  /// only places the dimension line on one side of the segment.
  static DimensionEntity? alignedDimension(
    Vec2 first,
    Vec2 second,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
    List<int> sourceIds = const [],
  }) {
    final measurement = first.distanceTo(second);
    if (measurement < 1e-9) return null;
    final unit = (second - first) / measurement;
    final normal = unit.perpendicular;
    var offset = (dimLine - first).dot(normal);
    if (offset.abs() < 1e-6) offset = measurement * 0.15;
    final a = first + normal * offset;
    final b = second + normal * offset;
    return DimensionEntity(
      id: id,
      props: props,
      definitionPoints: [first, second, dimLine],
      textPosition: a.lerp(b, 0.5),
      measurement: measurement,
      styleName: styleName,
      dimensionType: 1,
      sourceIds: sourceIds,
    );
  }

  /// The next linear or aligned dimension in a DIMCONTINUE chain.
  ///
  /// The new first origin is the previous second origin, so a run of hole
  /// centres shares one dimension line. Linear chains keep the previous axis
  /// (width stays width) even when the old dim-line pick would sit beside
  /// the new midpoint and flip the measurement.
  static DimensionEntity? continueDimension(
    DimensionEntity previous,
    Vec2 nextOrigin, {
    int id = 0,
    EntityProps? props,
  }) {
    final points = previous.definitionPoints;
    if (points.length < 2) return null;
    final first = points[1];
    if (first.distanceTo(nextOrigin) < 1e-9) return null;
    final resolved = props ?? previous.props;
    final type = previous.dimensionType & 0x0F;
    if (type == 1) {
      final dimLine = points.length > 2 ? points[2] : previous.textPosition;
      return alignedDimension(
        first,
        nextOrigin,
        dimLine,
        id: id,
        props: resolved,
        styleName: previous.styleName,
        sourceIds: previous.sourceIds,
      );
    }
    if (type != 0 || points.length < 3) return null;
    final mid = points[0].lerp(points[1], 0.5);
    final horizontal = (points[2] - mid).y.abs() >= (points[2] - mid).x.abs();
    final dimLine = horizontal
        ? Vec2((first.x + nextOrigin.x) / 2, points[2].y)
        : Vec2(points[2].x, (first.y + nextOrigin.y) / 2);
    return linearDimension(
      first,
      nextOrigin,
      dimLine,
      id: id,
      props: resolved,
      styleName: previous.styleName,
      sourceIds: previous.sourceIds,
    );
  }

  /// The next linear or aligned dimension in a DIMBASELINE stack.
  ///
  /// The first origin stays put and the dimension line steps outward by
  /// [spacing], so a run of overall lengths shares one extension line instead
  /// of one dimension line. Linear stacks keep the previous axis, same as
  /// [continueDimension].
  static DimensionEntity? baselineDimension(
    DimensionEntity previous,
    Vec2 nextOrigin, {
    int id = 0,
    EntityProps? props,
    double spacing = 8,
  }) {
    if (spacing <= 1e-9) return null;
    final points = previous.definitionPoints;
    if (points.length < 2) return null;
    final first = points[0];
    if (first.distanceTo(nextOrigin) < 1e-9) return null;
    final resolved = props ?? previous.props;
    final type = previous.dimensionType & 0x0F;
    if (type == 1) {
      if (points.length < 3) return null;
      final span = first.distanceTo(points[1]);
      if (span < 1e-9) return null;
      final normal = ((points[1] - first) / span).perpendicular;
      var offset = (points[2] - first).dot(normal);
      if (offset.abs() < 1e-6) offset = span * 0.15;
      final stepped = offset + (offset >= 0 ? spacing : -spacing);
      final nextSpan = first.distanceTo(nextOrigin);
      if (nextSpan < 1e-9) return null;
      final nextNormal = ((nextOrigin - first) / nextSpan).perpendicular;
      return alignedDimension(
        first,
        nextOrigin,
        first + nextNormal * stepped,
        id: id,
        props: resolved,
        styleName: previous.styleName,
        sourceIds: previous.sourceIds,
      );
    }
    if (type != 0 || points.length < 3) return null;
    final mid = points[0].lerp(points[1], 0.5);
    final horizontal = (points[2] - mid).y.abs() >= (points[2] - mid).x.abs();
    if (horizontal) {
      final dir = points[2].y >= mid.y ? 1.0 : -1.0;
      return linearDimension(
        first,
        nextOrigin,
        Vec2((first.x + nextOrigin.x) / 2, points[2].y + dir * spacing),
        id: id,
        props: resolved,
        styleName: previous.styleName,
        sourceIds: previous.sourceIds,
      );
    }
    final dir = points[2].x >= mid.x ? 1.0 : -1.0;
    return linearDimension(
      first,
      nextOrigin,
      Vec2(points[2].x + dir * spacing, (first.y + nextOrigin.y) / 2),
      id: id,
      props: resolved,
      styleName: previous.styleName,
      sourceIds: previous.sourceIds,
    );
  }

  /// A radius dimension for a circle or arc.
  ///
  /// [dimLine] is the arrow tip and the text seat; it does not have to lie
  /// on the circumference. The measured value is always the radius, and the
  /// text is prefixed with `R` so it cannot be mistaken for a diameter.
  static DimensionEntity? radiusDimension(
    CadEntity target,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
  }) {
    final source = _radialSource(target);
    if (source == null) return null;
    final (center, radius) = source;
    if (radius < 1e-9) return null;
    var chord = dimLine;
    if (chord.distanceTo(center) < 1e-9) {
      chord = center + Vec2(radius, 0);
    }
    return DimensionEntity(
      id: id,
      props: props,
      definitionPoints: [center, chord],
      textPosition: chord,
      measurement: radius,
      overrideText: 'R<>',
      styleName: styleName,
      dimensionType: 4,
      sourceIds: _associatedIds(target),
    );
  }

  /// A diameter dimension for a circle or arc.
  ///
  /// Same picks as [radiusDimension], but the measurement is twice the
  /// radius and the text uses Ø so it cannot be read as a radius.
  static DimensionEntity? diameterDimension(
    CadEntity target,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
  }) {
    final source = _radialSource(target);
    if (source == null) return null;
    final (center, radius) = source;
    if (radius < 1e-9) return null;
    var chord = dimLine;
    if (chord.distanceTo(center) < 1e-9) {
      chord = center + Vec2(radius, 0);
    }
    return DimensionEntity(
      id: id,
      props: props,
      definitionPoints: [center, chord],
      textPosition: chord,
      measurement: radius * 2,
      overrideText: 'Ø<>',
      styleName: styleName,
      dimensionType: 3,
      sourceIds: _associatedIds(target),
    );
  }

  /// A DIMCENTER mark on a circle or arc.
  ///
  /// Two short axes cross at the centre. When [extend] is true and the
  /// radius is larger than [size], four more segments run from the mark out
  /// past the circumference, the usual shop-drawing centre mark.
  static List<LineEntity>? centerMark(
    CadEntity target, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    double size = 2.5,
    bool extend = true,
  }) {
    final source = _radialSource(target);
    if (source == null || size <= 1e-9) return null;
    final (center, radius) = source;
    if (radius < 1e-9) return null;
    final mark = math.min(size, radius);
    final created = <LineEntity>[];
    for (final axis in const [Vec2(1, 0), Vec2(0, 1)]) {
      created.add(
        LineEntity(
          id: id,
          props: props,
          start: center - axis * mark,
          end: center + axis * mark,
        ),
      );
      if (!extend || radius <= mark + 1e-9) continue;
      final outer = radius + mark;
      created
        ..add(
          LineEntity(
            id: 0,
            props: props,
            start: center + axis * mark,
            end: center + axis * outer,
          ),
        )
        ..add(
          LineEntity(
            id: 0,
            props: props,
            start: center - axis * mark,
            end: center - axis * outer,
          ),
        );
    }
    return created;
  }

  /// A centreline between two parallel lines, or through two circle/arc centres.
  ///
  /// Parallel lines share a midline spanning both segments, then grow by
  /// [extension] at each end. Two radial objects get the line through their
  /// centres, grown past each circumference by the same amount.
  static LineEntity? centerLine(
    CadEntity first,
    CadEntity second, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    double extension = 2.5,
  }) {
    if (extension < 0) return null;
    if (first is LineEntity && second is LineEntity) {
      return _centerLineBetweenLines(
        first,
        second,
        id: id,
        props: props,
        extension: extension,
      );
    }
    final a = _radialSource(first);
    final b = _radialSource(second);
    if (a == null || b == null) return null;
    final delta = b.$1 - a.$1;
    final span = delta.length;
    if (span < 1e-9) return null;
    final unit = delta / span;
    return LineEntity(
      id: id,
      props: props,
      start: a.$1 - unit * (a.$2 + extension),
      end: b.$1 + unit * (b.$2 + extension),
    );
  }

  static LineEntity? _centerLineBetweenLines(
    LineEntity first,
    LineEntity second, {
    required int id,
    required EntityProps props,
    required double extension,
  }) {
    final dir = first.end - first.start;
    final length = dir.length;
    if (length < 1e-9) return null;
    final other = second.end - second.start;
    if (other.length < 1e-9) return null;
    if (dir.cross(other).abs() > 1e-8 * length * other.length) return null;
    final unit = dir / length;
    final normal = unit.perpendicular;
    final offset = (second.start - first.start).dot(normal);
    final origin = first.start + normal * (offset / 2);
    var minT = double.infinity;
    var maxT = -double.infinity;
    for (final point in [first.start, first.end, second.start, second.end]) {
      final t = (point - origin).dot(unit);
      if (t < minT) minT = t;
      if (t > maxT) maxT = t;
    }
    if (maxT - minT < 1e-9) return null;
    return LineEntity(
      id: id,
      props: props,
      start: origin + unit * (minT - extension),
      end: origin + unit * (maxT + extension),
    );
  }

  /// An angular dimension at [vertex] between [first] and [second].
  ///
  /// [dimLine] sits on the dimension arc and chooses the sector: the same
  /// three points can be 90° or 270°, and the pick is which one goes on the
  /// drawing. Degrees are stored so the text is what a drawing reader expects.
  static DimensionEntity? angularDimension(
    Vec2 vertex,
    Vec2 first,
    Vec2 second,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
    List<int> sourceIds = const [],
  }) {
    if (first.distanceTo(vertex) < 1e-9 || second.distanceTo(vertex) < 1e-9) {
      return null;
    }
    var a = first;
    var b = second;
    var start = (a - vertex).angle;
    var end = (b - vertex).angle;
    if (dimLine.distanceTo(vertex) >= 1e-9) {
      final via = (dimLine - vertex).angle;
      if (angularSweep(start, via) > angularSweep(start, end) + 1e-9) {
        a = second;
        b = first;
        start = (a - vertex).angle;
        end = (b - vertex).angle;
      }
    } else if (angularSweep(start, end) > math.pi) {
      a = second;
      b = first;
      start = (a - vertex).angle;
      end = (b - vertex).angle;
    }
    final sweep = angularSweep(start, end);
    final degrees = sweep * 180 / math.pi;
    if (degrees < 1e-6 || degrees > 360 - 1e-6) return null;
    final text = dimLine.distanceTo(vertex) < 1e-9
        ? vertex +
              Vec2.polar(
                start + sweep / 2,
                math.min(a.distanceTo(vertex), b.distanceTo(vertex)) * 0.5,
              )
        : dimLine;
    return DimensionEntity(
      id: id,
      props: props,
      definitionPoints: [vertex, a, b],
      textPosition: text,
      measurement: degrees,
      overrideText: '<>°',
      styleName: styleName,
      dimensionType: 2,
      sourceIds: sourceIds,
    );
  }

  /// An angular dimension between the supporting lines of [first] and [second].
  ///
  /// Two lines cut the plane into four sectors. [dimLine] chooses which one is
  /// labelled — the acute pair or the supplementary pair — so a 30° crossing
  /// can read 30° or 150° depending on where the arc is placed.
  static DimensionEntity? angularDimensionFromLines(
    LineEntity first,
    LineEntity second,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
  }) {
    final vertex = Intersect.lineLine(
      first.start,
      first.end,
      second.start,
      second.end,
    );
    if (vertex == null) return null;
    if (first.length < 1e-9 || second.length < 1e-9) return null;
    final a1 = (first.end - first.start).angle;
    final rays = <double>[
      normalizeAngle(a1),
      normalizeAngle(a1 + math.pi),
      normalizeAngle((second.end - second.start).angle),
      normalizeAngle((second.end - second.start).angle + math.pi),
    ]..sort();
    final via = normalizeAngle((dimLine - vertex).angle);
    for (var i = 0; i < rays.length; i++) {
      final start = rays[i];
      final end = rays[(i + 1) % rays.length];
      if (angularSweep(start, via) <= angularSweep(start, end) + 1e-9) {
        return angularDimension(
          vertex,
          vertex + Vec2.polar(start, 1),
          vertex + Vec2.polar(end, 1),
          dimLine,
          id: id,
          props: props,
          styleName: styleName,
          sourceIds: _associatedIds(first, second),
        );
      }
    }
    return null;
  }

  /// An angular dimension of [arc].
  ///
  /// The centre is the vertex and the endpoints are the rays. [dimLine]
  /// chooses the arc's own sweep or the complementary sector, so a quarter
  /// circle can read 90° or 270°.
  static DimensionEntity? angularDimensionFromArc(
    ArcEntity arc,
    Vec2 dimLine, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String styleName = 'Standard',
  }) {
    if (arc.radius <= 0 || arc.sweep < 1e-9 || arc.sweep > 2 * math.pi - 1e-9) {
      return null;
    }
    return angularDimension(
      arc.center,
      arc.startPoint,
      arc.endPoint,
      dimLine,
      id: id,
      props: props,
      styleName: styleName,
      sourceIds: _associatedIds(arc),
    );
  }

  /// A leader from [points], optionally with a TEXT annotation.
  ///
  /// The first vertex is the arrow tip. When [annotation] is not empty and the
  /// last span is not already horizontal, a short landing is appended so the
  /// note sits level with the hook, the same way AutoCAD's LEADER does.
  static List<CadEntity>? leader(
    List<Vec2> points, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String annotation = '',
    double textHeight = 2.5,
    bool hasArrowHead = true,
  }) {
    if (points.length < 2 || textHeight <= 0) return null;
    final verts = <Vec2>[points.first];
    for (final point in points.skip(1)) {
      if (point.distanceTo(verts.last) > 1e-12) verts.add(point);
    }
    if (verts.length < 2) return null;

    if (annotation.isNotEmpty) {
      final last = verts.last;
      final prev = verts[verts.length - 2];
      if ((last.y - prev.y).abs() > 1e-9) {
        final goingLeft = last.x + 1e-12 < prev.x;
        verts.add(last + Vec2(goingLeft ? -textHeight : textHeight, 0));
      }
    }

    final vertices = Float64List(verts.length * 2);
    for (var i = 0; i < verts.length; i++) {
      vertices[i * 2] = verts[i].x;
      vertices[i * 2 + 1] = verts[i].y;
    }

    final created = <CadEntity>[
      LeaderEntity(
        id: id,
        props: props,
        vertices: vertices,
        hasArrowHead: hasArrowHead,
      ),
    ];
    if (annotation.isNotEmpty) {
      final last = verts.last;
      final prev = verts[verts.length - 2];
      final goingLeft = last.x + 1e-12 < prev.x;
      created.add(
        TextEntity(
          id: 0,
          props: props,
          position:
              last +
              Vec2(goingLeft ? -textHeight * 0.15 : textHeight * 0.15, 0),
          content: annotation,
          height: textHeight,
          hAlign: goingLeft ? TextHAlign.right : TextHAlign.left,
          vAlign: TextVAlign.middle,
        ),
      );
    }
    return created;
  }

  /// A MULTILEADER from [points] with an optional note.
  ///
  /// Unlike [leader], the note lives on the same object as the arrows so a
  /// process callout stays one entity when selected, gripped, or saved.
  static MLeaderEntity? mleader(
    List<Vec2> points, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
    String annotation = '',
    double textHeight = 2.5,
    bool hasArrowHead = true,
  }) {
    if (points.length < 2 || textHeight <= 0) return null;
    final verts = <Vec2>[points.first];
    for (final point in points.skip(1)) {
      if (point.distanceTo(verts.last) > 1e-12) verts.add(point);
    }
    if (verts.length < 2) return null;

    if (annotation.isNotEmpty) {
      final last = verts.last;
      final prev = verts[verts.length - 2];
      if ((last.y - prev.y).abs() > 1e-9) {
        final goingLeft = last.x + 1e-12 < prev.x;
        verts.add(last + Vec2(goingLeft ? -textHeight : textHeight, 0));
      }
    }

    final vertices = Float64List(verts.length * 2);
    for (var i = 0; i < verts.length; i++) {
      vertices[i * 2] = verts[i].x;
      vertices[i * 2 + 1] = verts[i].y;
    }
    return MLeaderEntity(
      id: id,
      props: props,
      vertices: vertices,
      hasArrowHead: hasArrowHead,
      content: annotation,
      textPosition: verts.last,
      textHeight: textHeight,
    );
  }

  /// The lines, arrows and text a dimension draws, as editable entities.
  ///
  /// EXPLODE has to produce the same picture the fallback renderer does, so
  /// a dimension that never had an anonymous block still comes apart into
  /// geometry a user can move independently.
  static List<CadEntity> explodeDimension(
    DimensionEntity entity, {
    DimStyleDef? style,
  }) {
    final dim = style ?? DimStyleDef.standard;
    final props = entity.props;
    final pieces = <CadEntity>[];
    final points = entity.definitionPoints;
    if (points.length >= 2) {
      switch (entity.dimensionType & 0x0F) {
        case 2:
          pieces.addAll(_explodeAngularDim(entity, props, dim));
        case 3:
          pieces.addAll(_explodeRadialDim(entity, props, dim, diameter: true));
        case 4:
          pieces.addAll(_explodeRadialDim(entity, props, dim, diameter: false));
        default:
          pieces.addAll(_explodeLinearDim(entity, props, dim));
      }
    }
    if (entity.overrideText != ' ') {
      pieces.add(
        TextEntity(
          id: 0,
          props: props,
          position: entity.textPosition,
          content: entity.displayTextFor(dim),
          height: dim.scaledTextHeight,
          styleName: dim.textStyle,
          hAlign: TextHAlign.center,
          vAlign: TextVAlign.middle,
        ),
      );
    }
    return pieces;
  }

  static List<CadEntity> _explodeLinearDim(
    DimensionEntity entity,
    EntityProps props,
    DimStyleDef dim,
  ) {
    final points = entity.definitionPoints;
    final p1 = points[0];
    final p2 = points[1];
    final dimLine = points.length > 2 ? points[2] : entity.textPosition;
    late final Vec2 a;
    late final Vec2 b;
    late final Vec2 unit;
    if ((entity.dimensionType & 0x0F) == 0 && points.length >= 3) {
      final mid = p1.lerp(p2, 0.5);
      final horizontal = (dimLine - mid).y.abs() >= (dimLine - mid).x.abs();
      a = horizontal ? Vec2(p1.x, dimLine.y) : Vec2(dimLine.x, p1.y);
      b = horizontal ? Vec2(p2.x, dimLine.y) : Vec2(dimLine.x, p2.y);
      if (a.distanceTo(b) < 1e-9) return const [];
      unit = (b - a).normalized();
    } else {
      final direction = p2 - p1;
      if (direction.length < 1e-9) return const [];
      unit = direction.normalized();
      final normal = unit.perpendicular;
      var offset = (dimLine - p1).dot(normal);
      if (offset.abs() < 1e-6) offset = direction.length * 0.15;
      a = p1 + normal * offset;
      b = p2 + normal * offset;
    }
    return [
      ..._extensionLine(p1, a, props, dim),
      ..._extensionLine(p2, b, props, dim),
      LineEntity(id: 0, props: props, start: a, end: b),
      ..._dimArrows(a, unit, props, dim.scaledArrowSize),
      ..._dimArrows(b, -unit, props, dim.scaledArrowSize),
    ];
  }

  static List<CadEntity> _explodeRadialDim(
    DimensionEntity entity,
    EntityProps props,
    DimStyleDef dim, {
    required bool diameter,
  }) {
    final center = entity.definitionPoints[0];
    final chord = entity.definitionPoints[1];
    final delta = chord - center;
    if (delta.length < 1e-9) return const [];
    final unit = delta.normalized();
    return [
      LineEntity(id: 0, props: props, start: center, end: chord),
      if (diameter)
        LineEntity(id: 0, props: props, start: center, end: center - delta),
      ..._dimArrows(chord, -unit, props, dim.scaledArrowSize),
    ];
  }

  static List<CadEntity> _explodeAngularDim(
    DimensionEntity entity,
    EntityProps props,
    DimStyleDef dim,
  ) {
    final points = entity.definitionPoints;
    if (points.length < 3) return _explodeLinearDim(entity, props, dim);
    final vertex = points[0];
    final a = points[1];
    final b = points[2];
    final radius = vertex.distanceTo(entity.textPosition);
    final start = (a - vertex).angle;
    final end = (b - vertex).angle;
    return [
      LineEntity(id: 0, props: props, start: vertex, end: a),
      LineEntity(id: 0, props: props, start: vertex, end: b),
      if (radius > 1e-9)
        ArcEntity(
          id: 0,
          props: props,
          center: vertex,
          radius: radius,
          startAngle: start,
          endAngle: start + angularSweep(start, end),
        ),
    ];
  }

  static List<CadEntity> _extensionLine(
    Vec2 origin,
    Vec2 dimEnd,
    EntityProps props,
    DimStyleDef dim,
  ) {
    final span = dimEnd - origin;
    final length = span.length;
    if (length < 1e-9) return const [];
    final unit = span / length;
    final exo = dim.scaledExtensionOffset;
    final start = exo >= length ? dimEnd : origin + unit * exo;
    final end = dimEnd + unit * dim.scaledExtensionExtend;
    if (start.distanceTo(end) < 1e-9) return const [];
    return [LineEntity(id: 0, props: props, start: start, end: end)];
  }

  static List<CadEntity> _dimArrows(
    Vec2 tip,
    Vec2 direction,
    EntityProps props,
    double size,
  ) {
    if (direction.length < 1e-9 || size <= 1e-9) return const [];
    final unit = direction.normalized();
    return [
      SolidEntity(
        id: 0,
        props: props,
        corners: [
          tip,
          tip - unit * size + unit.perpendicular * (size * 0.35),
          tip - unit * size - unit.perpendicular * (size * 0.35),
        ],
      ),
    ];
  }

  static (Vec2, double)? _radialSource(CadEntity entity) {
    switch (entity) {
      case CircleEntity(:final center, :final radius):
        return (center, radius);
      case ArcEntity(:final center, :final radius):
        return (center, radius);
      default:
        return null;
    }
  }

  static List<int> _associatedIds(CadEntity first, [CadEntity? second]) {
    final ids = <int>[
      if (first.id > 0) first.id,
      if (second != null && second.id > 0) second.id,
    ];
    return ids;
  }

  /// Rebuilds [dimension] from the live geometry of [sources].
  ///
  /// Origins always come from the sources. When [sourcesMoved] is true the
  /// dimension-line offset is reapplied to the new origins so MOVE on the
  /// measured object drags the annotation with it. When it is false the
  /// current dimension-line pick is kept, so MOVE on the dimension itself
  /// only changes the offset.
  static DimensionEntity? regenDimension(
    DimensionEntity dimension,
    List<CadEntity> sources, {
    bool sourcesMoved = true,
  }) {
    if (sources.isEmpty) return dimension;
    final type = dimension.dimensionType & 0x0F;
    final rebuilt = switch (type) {
      3 || 4 => _regenRadial(dimension, sources, sourcesMoved: sourcesMoved),
      2 => _regenAngular(dimension, sources, sourcesMoved: sourcesMoved),
      1 => _regenAligned(dimension, sources, sourcesMoved: sourcesMoved),
      _ => _regenLinear(dimension, sources, sourcesMoved: sourcesMoved),
    };
    if (rebuilt == null) return dimension;
    return rebuilt.copyWith(
      id: dimension.id,
      props: dimension.props,
      overrideText: dimension.overrideText,
      styleName: dimension.styleName,
      sourceIds: dimension.sourceIds,
      blockName: '',
    );
  }

  static DimensionEntity? _regenLinear(
    DimensionEntity dimension,
    List<CadEntity> sources, {
    required bool sourcesMoved,
  }) {
    final origins = _linearOrigins(sources);
    if (origins == null) return null;
    final (first, second) = origins;
    final points = dimension.definitionPoints;
    Vec2 dimLine;
    if (sourcesMoved && points.length >= 3) {
      final oldMid = points[0].lerp(points[1], 0.5);
      final horizontal =
          (points[2] - oldMid).y.abs() >= (points[2] - oldMid).x.abs();
      final newMid = first.lerp(second, 0.5);
      dimLine = horizontal
          ? Vec2(newMid.x, newMid.y + (points[2].y - oldMid.y))
          : Vec2(newMid.x + (points[2].x - oldMid.x), newMid.y);
    } else {
      dimLine = points.length >= 3 ? points[2] : dimension.textPosition;
    }
    return linearDimension(
      first,
      second,
      dimLine,
      sourceIds: dimension.sourceIds,
    );
  }

  static DimensionEntity? _regenAligned(
    DimensionEntity dimension,
    List<CadEntity> sources, {
    required bool sourcesMoved,
  }) {
    final origins = _linearOrigins(sources);
    if (origins == null) return null;
    final (first, second) = origins;
    final points = dimension.definitionPoints;
    Vec2 dimLine;
    if (sourcesMoved && points.length >= 3) {
      final oldSpan = points[0].distanceTo(points[1]);
      if (oldSpan < 1e-9) return null;
      final oldNormal = ((points[1] - points[0]) / oldSpan).perpendicular;
      final offset = (points[2] - points[0]).dot(oldNormal);
      final newSpan = first.distanceTo(second);
      if (newSpan < 1e-9) return null;
      final newNormal = ((second - first) / newSpan).perpendicular;
      dimLine = first + newNormal * offset;
    } else {
      dimLine = points.length >= 3 ? points[2] : dimension.textPosition;
    }
    return alignedDimension(
      first,
      second,
      dimLine,
      sourceIds: dimension.sourceIds,
    );
  }

  static DimensionEntity? _regenRadial(
    DimensionEntity dimension,
    List<CadEntity> sources, {
    required bool sourcesMoved,
  }) {
    if (sources.isEmpty) return null;
    final radial = _radialSource(sources.first);
    if (radial == null) return null;
    final (center, radius) = radial;
    final points = dimension.definitionPoints;
    final oldCenter = points.isNotEmpty ? points[0] : center;
    final oldChord = points.length >= 2 ? points[1] : dimension.textPosition;
    final Vec2 chord;
    if (sourcesMoved) {
      final angle = (oldChord - oldCenter).angle;
      final reach = oldChord.distanceTo(oldCenter);
      chord = center + Vec2.polar(angle, reach > 1e-9 ? reach : radius);
    } else {
      chord = oldChord;
    }
    return (dimension.dimensionType & 0x0F) == 3
        ? diameterDimension(sources.first, chord)
        : radiusDimension(sources.first, chord);
  }

  static DimensionEntity? _regenAngular(
    DimensionEntity dimension,
    List<CadEntity> sources, {
    required bool sourcesMoved,
  }) {
    final dimLine = sourcesMoved && dimension.definitionPoints.length >= 3
        ? _angularDimLine(dimension, sources)
        : dimension.textPosition;
    if (sources.length >= 2 &&
        sources[0] is LineEntity &&
        sources[1] is LineEntity) {
      return angularDimensionFromLines(
        sources[0] as LineEntity,
        sources[1] as LineEntity,
        dimLine,
      );
    }
    if (sources.isNotEmpty && sources.first is ArcEntity) {
      return angularDimensionFromArc(sources.first as ArcEntity, dimLine);
    }
    return null;
  }

  static Vec2 _angularDimLine(
    DimensionEntity dimension,
    List<CadEntity> sources,
  ) {
    final oldVertex = dimension.definitionPoints[0];
    final oldSeat = dimension.textPosition;
    final reach = oldSeat.distanceTo(oldVertex);
    final angle = (oldSeat - oldVertex).angle;
    if (sources.length >= 2 &&
        sources[0] is LineEntity &&
        sources[1] is LineEntity) {
      final vertex = Intersect.lineLine(
        (sources[0] as LineEntity).start,
        (sources[0] as LineEntity).end,
        (sources[1] as LineEntity).start,
        (sources[1] as LineEntity).end,
      );
      if (vertex != null) {
        return vertex + Vec2.polar(angle, reach > 1e-9 ? reach : 1);
      }
    }
    if (sources.first is ArcEntity) {
      final arc = sources.first as ArcEntity;
      return arc.center + Vec2.polar(angle, reach > 1e-9 ? reach : arc.radius);
    }
    return oldSeat;
  }

  static (Vec2, Vec2)? _linearOrigins(List<CadEntity> sources) {
    if (sources.isEmpty) return null;
    final first = sources.first;
    if (first is LineEntity) return (first.start, first.end);
    return null;
  }

  /// A circle of [radius] tangent to [first] and [second].
  ///
  /// The construction is the offset-and-intersect one: shift each object by
  /// [radius] toward its pick, then the intersection of those offsets is the
  /// centre. [pick1] and [pick2] choose which side of a line (or whether a
  /// circle is an external or internal tangent), which is why two lines that
  /// cross yield four possible circles and a pick pair names one of them.
  static CircleEntity? circleTangentRadius(
    CadEntity first,
    CadEntity second,
    double radius,
    Vec2 pick1,
    Vec2 pick2, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    if (radius <= 0 || !radius.isFinite) return null;
    final offset1 = offset(first, radius, pick1);
    final offset2 = offset(second, radius, pick2);
    if (offset1 == null || offset2 == null) return null;
    final center = _offsetIntersection(
      offset1,
      offset2,
      pick1.lerp(pick2, 0.5),
    );
    if (center == null) return null;
    return CircleEntity(id: id, props: props, center: center, radius: radius);
  }

  static Vec2? _offsetIntersection(
    CadEntity first,
    CadEntity second,
    Vec2 hint,
  ) {
    final line1 = first is LineEntity ? first : null;
    final line2 = second is LineEntity ? second : null;
    final circle1 = _circleOf(first);
    final circle2 = _circleOf(second);
    if (line1 != null && line2 != null) {
      return Intersect.lineLine(line1.start, line1.end, line2.start, line2.end);
    }
    if (line1 != null && circle2 != null) {
      return _nearestHit(
        Intersect.lineCircle(line1.start, line1.end, circle2.$1, circle2.$2),
        hint,
      );
    }
    if (line2 != null && circle1 != null) {
      return _nearestHit(
        Intersect.lineCircle(line2.start, line2.end, circle1.$1, circle1.$2),
        hint,
      );
    }
    if (circle1 != null && circle2 != null) {
      return _nearestHit(
        Intersect.circleCircle(circle1.$1, circle1.$2, circle2.$1, circle2.$2),
        hint,
      );
    }
    return null;
  }

  static (Vec2, double)? _circleOf(CadEntity entity) => switch (entity) {
    CircleEntity(:final center, :final radius) => (center, radius),
    ArcEntity(:final center, :final radius) => (center, radius),
    _ => null,
  };

  static Vec2? _nearestHit(List<Vec2> hits, Vec2 hint) {
    if (hits.isEmpty) return null;
    var best = hits.first;
    var bestDistance = best.distanceSquaredTo(hint);
    for (var i = 1; i < hits.length; i++) {
      final distance = hits[i].distanceSquaredTo(hint);
      if (distance < bestDistance) {
        best = hits[i];
        bestDistance = distance;
      }
    }
    return best;
  }

  /// A clamped uniform B-spline through the given control points.
  ///
  /// Degree is 3 when there are at least four points, otherwise it drops so
  /// the knot vector stays valid. This is the control-point form of SPLINE,
  /// not an interpolating fit — the curve is pulled toward the clicks, and
  /// only guaranteed to pass through the first and last.
  static SplineEntity? splineFromControls(
    List<Vec2> points, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    if (points.length < 2) return null;
    final degree = math.min(3, points.length - 1);
    final controlPoints = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      controlPoints[i * 2] = points[i].x;
      controlPoints[i * 2 + 1] = points[i].y;
    }
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: controlPoints,
      knots: _clampedUniformKnots(points.length, degree),
      degree: degree,
      fitPoints: Float64List.fromList(controlPoints),
    );
  }

  /// A clamped B-spline that interpolates [points].
  ///
  /// Chord-length parameters and an averaging knot vector keep the
  /// interpolation matrix well-conditioned, so the curve actually passes
  /// through every click instead of only being pulled toward them.
  static SplineEntity? splineFromFit(
    List<Vec2> points, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final interpolated = Flatten.interpolateFit(points);
    if (interpolated == null) return null;
    final fitPoints = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      fitPoints[i * 2] = points[i].x;
      fitPoints[i * 2 + 1] = points[i].y;
    }
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: interpolated.controlPoints,
      knots: interpolated.knots,
      degree: interpolated.degree,
      fitPoints: fitPoints,
    );
  }

  /// Open clamped uniform knots: `count + degree + 1` values, 0 at the start
  /// and 1 at the end, equally spaced in between.
  static List<double> _clampedUniformKnots(int count, int degree) {
    final knots = List<double>.filled(count + degree + 1, 0);
    for (var i = 0; i <= degree; i++) {
      knots[i] = 0;
      knots[knots.length - 1 - i] = 1;
    }
    final interior = count - degree - 1;
    for (var i = 1; i <= interior; i++) {
      knots[degree + i] = i / (interior + 1);
    }
    return knots;
  }

  /// An axis-aligned-or-rotated ellipse from a centre, one axis end, and the
  /// other semi-axis length.
  ///
  /// If the second radius is longer than the first axis, the two swap so the
  /// stored [EllipseEntity.ratio] stays at most 1, which is how DWG records it.
  static EllipseEntity? ellipse({
    required Vec2 center,
    required Vec2 axisEnd,
    required double otherRadius,
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    var major = axisEnd - center;
    final majorLength = major.length;
    if (majorLength < 1e-12 || otherRadius <= 0 || !otherRadius.isFinite) {
      return null;
    }
    var ratio = otherRadius / majorLength;
    if (ratio > 1) {
      major = major.normalized().perpendicular * otherRadius;
      ratio = majorLength / otherRadius;
    }
    return EllipseEntity(
      id: id,
      props: props,
      center: center,
      majorAxis: major,
      ratio: ratio,
    );
  }

  /// A circular donut as a closed two-vertex polyline with width.
  ///
  /// AutoCAD stores DONUT this way: the centreline radius is the average of
  /// the two radii and [PolylineEntity.constantWidth] is their difference, so
  /// a zero inner radius becomes a filled disk.
  static PolylineEntity? donut({
    required Vec2 center,
    required double innerRadius,
    required double outerRadius,
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final inner = innerRadius.abs();
    final outer = outerRadius.abs();
    final r0 = math.min(inner, outer);
    final r1 = math.max(inner, outer);
    if (r1 <= 1e-12) return null;
    final mid = (r0 + r1) / 2;
    return PolylineEntity(
      id: id,
      props: props,
      vertices: Float64List.fromList([
        center.x - mid,
        center.y,
        1,
        center.x + mid,
        center.y,
        1,
      ]),
      closed: true,
      constantWidth: r1 - r0,
    );
  }

  /// A closed rectangular polyline through two opposite corners.
  static PolylineEntity? rectangle(
    Vec2 first,
    Vec2 second, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final minX = math.min(first.x, second.x);
    final minY = math.min(first.y, second.y);
    final maxX = math.max(first.x, second.x);
    final maxY = math.max(first.y, second.y);
    if (maxX - minX <= 0 || maxY - minY <= 0) return null;
    return PolylineEntity.fromPoints(
      id: id,
      props: props,
      points: [
        Vec2(minX, minY),
        Vec2(maxX, minY),
        Vec2(maxX, maxY),
        Vec2(minX, maxY),
      ],
      closed: true,
    );
  }

  /// A regular polygon, as the POLYGON command produces it.
  static PolylineEntity polygon({
    required Vec2 center,
    required double radius,
    required int sides,
    double startAngle = math.pi / 2,
    bool circumscribed = false,
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final count = sides.clamp(3, 1024);
    // Inscribed means the vertices touch the circle; circumscribed means the
    // edge midpoints do, so the vertex radius has to grow to compensate.
    final effective = circumscribed
        ? radius / math.cos(math.pi / count)
        : radius;
    return PolylineEntity.fromPoints(
      id: id,
      props: props,
      points: [
        for (var i = 0; i < count; i++)
          center + Vec2.polar(startAngle + i * 2 * math.pi / count, effective),
      ],
      closed: true,
    );
  }

  /// The hatch loops that enclose [pick], or empty when nothing does.
  ///
  /// This is BHATCH: four lines that meet at corners become a rectangle, a
  /// circle inside that rectangle becomes an island. Commands pass the
  /// visible curves; the arrangement walk is here so a script and the
  /// crosshair cannot disagree about which face was chosen.
  static List<HatchLoop> boundaryFromPick(
    Iterable<CadEntity> entities,
    Vec2 pick, {
    double tolerance = 1e-3,
  }) => Boundary.fromPick(entities, pick, tolerance: tolerance);

  /// Offsets [entity] by [distance] to whichever side [towards] falls on.
  ///
  /// Analytic per type rather than a general polygon offset: a circle offsets to
  /// a circle and an arc to an arc. A user who offsets a circle and gets a
  /// 64-segment polyline back will not use the command twice.
  static CadEntity? offset(CadEntity entity, double distance, Vec2 towards) {
    if (distance <= 0) return null;
    return entity.offsetBy(distance, towards);
  }

  /// Trims [line] by discarding the piece that contains [pick].
  ///
  /// [crossings] are the points where the cutting edges meet the line. Returns
  /// null when the pick is not in a removable interval.
  static LineEntity? trimLine(
    LineEntity line,
    List<Vec2> crossings,
    Vec2 pick,
  ) {
    if (crossings.isEmpty) return null;
    final direction = line.end - line.start;
    final lengthSquared = direction.lengthSquared;
    if (lengthSquared < 1e-18) return null;

    double parameterOf(Vec2 p) =>
        (p - line.start).dot(direction) / lengthSquared;

    // Parameterise the line, sort the cuts along it, and find which interval
    // the pick falls in. That interval is the piece to discard.
    final cuts = <double>[
      0,
      for (final crossing in crossings)
        if (parameterOf(crossing) > 1e-9 && parameterOf(crossing) < 1 - 1e-9)
          parameterOf(crossing),
      1,
    ]..sort();
    if (cuts.length <= 2) return null;

    final pickParameter = parameterOf(pick).clamp(0.0, 1.0);
    for (var i = 0; i + 1 < cuts.length; i++) {
      if (pickParameter < cuts[i] || pickParameter > cuts[i + 1]) continue;
      final keepBefore = cuts[i] > 0;
      final keepAfter = cuts[i + 1] < 1;
      if (!keepBefore && !keepAfter) return null;
      if (keepBefore && keepAfter) {
        // Trimming out of the middle would correctly produce two lines, but
        // silently doubling the entity count surprises users more than it
        // helps, so the longer remnant is kept.
        return cuts[i] >= 1 - cuts[i + 1]
            ? resizedLine(line, 0, cuts[i])
            : resizedLine(line, cuts[i + 1], 1);
      }
      return keepBefore
          ? resizedLine(line, 0, cuts[i])
          : resizedLine(line, cuts[i + 1], 1);
    }
    return null;
  }

  /// Shortens [polyline] back to where it meets [crossings].
  ///
  /// Same contract as [trimLine]: the interval containing [pick] is discarded.
  /// Trimming a middle span of an open polyline keeps the longer remnant
  /// rather than splitting it in two. A closed polyline needs two crossings;
  /// the picked span is dropped and the rest is left open. A bulge is cut on
  /// the arc, not the chord.
  static PolylineEntity? trimPolyline(
    PolylineEntity polyline,
    List<Vec2> crossings,
    Vec2 pick,
  ) {
    if (crossings.isEmpty || polyline.vertexCount < 2) {
      return null;
    }
    if (polyline.closed) {
      return _trimClosedPolyline(polyline, crossings, pick);
    }
    final length = _polylineLength(polyline);
    if (length < 1e-12) return null;
    final pickHit = _polylineHit(polyline, pick);
    if (pickHit == null) return null;
    final pickDistance = _polylineChainDistance(polyline, pickHit);

    final cuts = <double>[0];
    for (final crossing in crossings) {
      final hit = _polylineHit(polyline, crossing);
      if (hit == null) continue;
      final distance = _polylineChainDistance(polyline, hit);
      if (distance > 1e-9 && distance < length - 1e-9) {
        cuts.add(distance);
      }
    }
    cuts.add(length);
    cuts.sort();
    final unique = <double>[];
    for (final cut in cuts) {
      if (unique.isEmpty || (cut - unique.last).abs() > 1e-9) {
        unique.add(cut);
      }
    }
    if (unique.length <= 2) return null;

    for (var i = 0; i + 1 < unique.length; i++) {
      if (pickDistance < unique[i] || pickDistance > unique[i + 1]) continue;
      final keepBefore = unique[i] > 1e-9;
      final keepAfter = unique[i + 1] < length - 1e-9;
      if (!keepBefore && !keepAfter) return null;
      if (keepBefore && keepAfter) {
        return unique[i] >= length - unique[i + 1]
            ? _polylinePrefix(polyline, unique[i])
            : _polylineSuffix(polyline, unique[i + 1]);
      }
      return keepBefore
          ? _polylinePrefix(polyline, unique[i])
          : _polylineSuffix(polyline, unique[i + 1]);
    }
    return null;
  }

  /// Drops the circular span that contains [pick] and opens the loop.
  static PolylineEntity? _trimClosedPolyline(
    PolylineEntity polyline,
    List<Vec2> crossings,
    Vec2 pick,
  ) {
    final length = _polylineLength(polyline);
    if (length < 1e-12) return null;
    final pickHit = _polylineHit(polyline, pick);
    if (pickHit == null) return null;
    var pickDistance = _polylineChainDistance(polyline, pickHit);
    if (pickDistance >= length - 1e-9) pickDistance = 0;

    final cuts = <({double distance, Vec2 point})>[];
    for (final crossing in crossings) {
      final hit = _polylineHit(polyline, crossing);
      if (hit == null) continue;
      var distance = _polylineChainDistance(polyline, hit);
      if (distance >= length - 1e-9) distance = 0;
      if (cuts.any((cut) => (cut.distance - distance).abs() < 1e-9)) {
        continue;
      }
      cuts.add((distance: distance, point: hit.point));
    }
    if (cuts.length < 2) return null;
    cuts.sort((a, b) => a.distance.compareTo(b.distance));
    if (cuts.any((cut) => (pickDistance - cut.distance).abs() < 1e-9)) {
      return null;
    }

    final ({double distance, Vec2 point}) from;
    final ({double distance, Vec2 point}) to;
    if (pickDistance < cuts.first.distance ||
        pickDistance > cuts.last.distance) {
      from = cuts.last;
      to = cuts.first;
    } else {
      var found = false;
      late final ({double distance, Vec2 point}) chosenFrom;
      late final ({double distance, Vec2 point}) chosenTo;
      for (var i = 0; i + 1 < cuts.length; i++) {
        if (pickDistance > cuts[i].distance &&
            pickDistance < cuts[i + 1].distance) {
          chosenFrom = cuts[i];
          chosenTo = cuts[i + 1];
          found = true;
          break;
        }
      }
      if (!found) return null;
      from = chosenFrom;
      to = chosenTo;
    }

    final pieces = breakPolyline(polyline, from.point, to.point);
    if (pieces == null || pieces.isEmpty) return null;
    return pieces.first;
  }

  static double _polylineChainDistance(PolylineEntity polyline, _PolyHit hit) {
    var distance = 0.0;
    for (var i = 0; i < hit.segment; i++) {
      distance += _segmentLength(
        polyline.vertexAt(i),
        polyline.vertexAt(i + 1),
        polyline.bulgeAt(i),
      );
    }
    final start = polyline.vertexAt(hit.segment);
    final end = polyline.vertexAt((hit.segment + 1) % polyline.vertexCount);
    return distance +
        _segmentLength(start, end, polyline.bulgeAt(hit.segment)) * hit.t;
  }

  static PolylineEntity? _polylinePrefix(
    PolylineEntity polyline,
    double distance,
  ) {
    final trimmed = _trimChainToLengthVerts(_polyVertsOf(polyline), distance);
    if (trimmed == null || trimmed.length < 2) return null;
    return _openPolyVerts(polyline, trimmed, polyline.id);
  }

  static PolylineEntity? _polylineSuffix(
    PolylineEntity polyline,
    double distance,
  ) {
    final length = _polylineLength(polyline);
    final trimmed = _trimChainToLengthVerts(
      _reversedPolyVerts(_polyVertsOf(polyline)),
      length - distance,
    );
    if (trimmed == null || trimmed.length < 2) return null;
    return _openPolyVerts(polyline, _reversedPolyVerts(trimmed), polyline.id);
  }

  /// Shortens [arc] back to where it meets [crossings].
  ///
  /// Same contract as [trimLine]: the interval containing [pick] is discarded,
  /// and a middle cut keeps the longer remnant.
  static ArcEntity? trimArc(ArcEntity arc, List<Vec2> crossings, Vec2 pick) {
    if (crossings.isEmpty || arc.radius <= 0 || arc.sweep < 1e-12) {
      return null;
    }
    final cuts = <double>[0];
    for (final crossing in crossings) {
      if ((crossing.distanceTo(arc.center) - arc.radius).abs() > 1e-3) {
        continue;
      }
      final t = _arcParam(arc, crossing);
      if (t > 1e-9 && t < 1 - 1e-9) cuts.add(t);
    }
    cuts.add(1);
    cuts.sort();
    final unique = <double>[];
    for (final cut in cuts) {
      if (unique.isEmpty || (cut - unique.last).abs() > 1e-9) {
        unique.add(cut);
      }
    }
    if (unique.length <= 2) return null;

    final pickT = _arcParam(arc, pick);
    for (var i = 0; i + 1 < unique.length; i++) {
      if (pickT < unique[i] || pickT > unique[i + 1]) continue;
      final keepBefore = unique[i] > 1e-9;
      final keepAfter = unique[i + 1] < 1 - 1e-9;
      if (!keepBefore && !keepAfter) return null;
      if (keepBefore && keepAfter) {
        return unique[i] >= 1 - unique[i + 1]
            ? _arcSpan(arc, 0, unique[i], arc.id)
            : _arcSpan(arc, unique[i + 1], 1, arc.id);
      }
      return keepBefore
          ? _arcSpan(arc, 0, unique[i], arc.id)
          : _arcSpan(arc, unique[i + 1], 1, arc.id);
    }
    return null;
  }

  /// Shortens [ellipse] the same way [trimArc] shortens an arc: the
  /// parameter interval that contains [pick] is discarded.
  static EllipseEntity? trimEllipse(
    EllipseEntity ellipse,
    List<Vec2> crossings,
    Vec2 pick,
  ) {
    if (crossings.isEmpty || ellipse.majorLength < 1e-12) return null;
    final sweep = ellipse.sweep;
    if (sweep < 1e-12) return null;
    final cuts = <double>[0];
    for (final crossing in crossings) {
      if (!ellipse.containsParam(ellipse.paramOf(crossing))) continue;
      final t = _ellipseParam(ellipse, crossing);
      if (t > 1e-9 && t < 1 - 1e-9) cuts.add(t);
    }
    cuts.add(1);
    cuts.sort();
    final unique = <double>[];
    for (final cut in cuts) {
      if (unique.isEmpty || (cut - unique.last).abs() > 1e-9) {
        unique.add(cut);
      }
    }
    if (unique.length <= 2) return null;

    final pickT = _ellipseParam(ellipse, pick);
    for (var i = 0; i + 1 < unique.length; i++) {
      if (pickT < unique[i] || pickT > unique[i + 1]) continue;
      final keepBefore = unique[i] > 1e-9;
      final keepAfter = unique[i + 1] < 1 - 1e-9;
      if (!keepBefore && !keepAfter) return null;
      if (keepBefore && keepAfter) {
        return unique[i] >= 1 - unique[i + 1]
            ? _ellipseSpan(ellipse, 0, unique[i])
            : _ellipseSpan(ellipse, unique[i + 1], 1);
      }
      return keepBefore
          ? _ellipseSpan(ellipse, 0, unique[i])
          : _ellipseSpan(ellipse, unique[i + 1], 1);
    }
    return null;
  }

  static double _ellipseParam(EllipseEntity ellipse, Vec2 pick) {
    final along = angularSweep(ellipse.startParam, ellipse.paramOf(pick));
    return (along / ellipse.sweep).clamp(0.0, 1.0);
  }

  static EllipseEntity _ellipseSpan(
    EllipseEntity ellipse,
    double from,
    double to,
  ) {
    final start = ellipse.startParam + ellipse.sweep * from;
    final end = ellipse.startParam + ellipse.sweep * to;
    return EllipseEntity(
      id: ellipse.id,
      props: ellipse.props,
      center: ellipse.center,
      majorAxis: ellipse.majorAxis,
      ratio: ellipse.ratio,
      startParam: start,
      endParam: end,
    );
  }

  /// Grows an elliptical arc until it meets [edges]. A full ellipse has
  /// nowhere to grow.
  static EllipseEntity? extendEllipse(
    EllipseEntity ellipse,
    List<CadEntity> edges, [
    Vec2? pick,
  ]) {
    if (ellipse.isFullEllipse || ellipse.majorLength < 1e-12) return null;
    final room = math.pi * 2 - ellipse.sweep;
    if (room <= 1e-9) return null;

    double? bestAfter;
    double? bestBefore;

    void consider(Vec2 hit) {
      final param = ellipse.paramOf(hit);
      if (ellipse.containsParam(param)) return;
      final after = angularSweep(ellipse.endParam, param);
      final before = angularSweep(param, ellipse.startParam);
      if (after > 1e-9 && after < room - 1e-9) {
        if (bestAfter == null || after < bestAfter!) bestAfter = after;
      }
      if (before > 1e-9 && before < room - 1e-9) {
        if (bestBefore == null || before < bestBefore!) bestBefore = before;
      }
    }

    for (final edge in edges) {
      for (final hit in _crossingsOnEllipse(
        EllipseEntity(
          id: 0,
          center: ellipse.center,
          majorAxis: ellipse.majorAxis,
          ratio: ellipse.ratio,
        ),
        edge,
      )) {
        consider(hit);
      }
    }

    EllipseEntity? growEnd() {
      if (bestAfter == null) return null;
      return EllipseEntity(
        id: ellipse.id,
        props: ellipse.props,
        center: ellipse.center,
        majorAxis: ellipse.majorAxis,
        ratio: ellipse.ratio,
        startParam: ellipse.startParam,
        endParam: ellipse.endParam + bestAfter!,
      );
    }

    EllipseEntity? growStart() {
      if (bestBefore == null) return null;
      return EllipseEntity(
        id: ellipse.id,
        props: ellipse.props,
        center: ellipse.center,
        majorAxis: ellipse.majorAxis,
        ratio: ellipse.ratio,
        startParam: ellipse.startParam - bestBefore!,
        endParam: ellipse.endParam,
      );
    }

    if (pick != null) {
      return _ellipseParam(ellipse, pick) <= 0.5 ? growStart() : growEnd();
    }
    return growEnd() ?? growStart();
  }

  /// Flattens [spline] so TRIM / EXTEND / OFFSET share one centreline.
  static PolylineEntity? _splineAsPolyline(SplineEntity spline) {
    final xy = _flattenSpline(spline);
    final points = <Vec2>[
      for (var i = 0; i + 1 < xy.length; i += 2) Vec2(xy[i], xy[i + 1]),
    ];
    if (points.length < 2) return null;
    return PolylineEntity.fromPoints(
      id: spline.id,
      props: spline.props,
      points: points,
      closed: spline.closed,
    );
  }

  /// Shortens [spline] at [crossings]. A NURBS split is not a NURBS of the
  /// same knots, so the kept span is a polyline — the same bargain OFFSET
  /// already makes.
  static PolylineEntity? trimSpline(
    SplineEntity spline,
    List<Vec2> crossings,
    Vec2 pick,
  ) {
    final polyline = _splineAsPolyline(spline);
    if (polyline == null) return null;
    return trimPolyline(polyline, crossings, pick);
  }

  /// Grows an open [spline] until an end meets [edges]. Closed loops have
  /// nowhere to grow. The result is a polyline, same as [trimSpline].
  static PolylineEntity? extendSpline(
    SplineEntity spline,
    List<CadEntity> edges, [
    Vec2? pick,
  ]) {
    if (spline.closed) return null;
    final polyline = _splineAsPolyline(spline);
    if (polyline == null) return null;
    return extendPolyline(polyline, edges, pick);
  }

  /// Every crossing of [target] with [edge], for TRIM.
  static List<Vec2> crossingsAlong(CadEntity target, CadEntity edge) {
    return switch (target) {
      LineEntity() => crossingsWith(target, edge),
      PolylineEntity() => [
        for (
          var i = 0;
          i < (target.closed ? target.vertexCount : target.vertexCount - 1);
          i++
        )
          ..._crossingsOnPolylineSegment(target, i, edge),
      ],
      ArcEntity() => _crossingsOnArc(target, edge),
      EllipseEntity() => _crossingsOnEllipse(target, edge),
      SplineEntity() => _crossingsOnSpline(target, edge),
      _ => const [],
    };
  }

  static List<Vec2> _crossingsOnPolylineSegment(
    PolylineEntity polyline,
    int index,
    CadEntity edge,
  ) {
    final start = polyline.vertexAt(index);
    final end = polyline.vertexAt((index + 1) % polyline.vertexCount);
    final bulge = polyline.bulgeAt(index);
    if (bulge.abs() < 1e-12) {
      return crossingsWith(LineEntity(id: 0, start: start, end: end), edge);
    }
    final def = Flatten.bulgeArc(start, end, bulge);
    if (def == null) {
      return crossingsWith(LineEntity(id: 0, start: start, end: end), edge);
    }
    return _crossingsOnArc(
      ArcEntity(
        id: 0,
        center: def.center,
        radius: def.radius,
        startAngle: def.startAngle,
        endAngle: def.endAngle,
      ),
      edge,
    );
  }

  static List<Vec2> _crossingsOnArc(ArcEntity arc, CadEntity edge) {
    bool onArc(Vec2 hit) {
      if ((hit.distanceTo(arc.center) - arc.radius).abs() > 1e-6) {
        return false;
      }
      return angularSweep(arc.startAngle, (hit - arc.center).angle) <=
          arc.sweep + 1e-9;
    }

    switch (edge) {
      case LineEntity(:final start, :final end):
        return [
          for (final hit in Intersect.lineCircle(
            start,
            end,
            arc.center,
            arc.radius,
          ))
            if (Intersect.distanceToSegment(hit, start, end) < 1e-6 &&
                onArc(hit))
              hit,
        ];
      case CircleEntity(:final center, :final radius):
        return [
          for (final hit in Intersect.circleCircle(
            arc.center,
            arc.radius,
            center,
            radius,
          ))
            if (onArc(hit)) hit,
        ];
      case ArcEntity():
        return [
          for (final hit in Intersect.circleCircle(
            arc.center,
            arc.radius,
            edge.center,
            edge.radius,
          ))
            if (onArc(hit) &&
                angularSweep(edge.startAngle, (hit - edge.center).angle) <=
                    edge.sweep + 1e-9)
              hit,
        ];
      case PolylineEntity():
        return [
          for (final arm in _polylineArms(edge)) ..._crossingsOnArc(arc, arm),
        ];
      case EllipseEntity():
        return [
          for (final hit in Intersect.circleEllipse(
            arc.center,
            arc.radius,
            edge.center,
            edge.majorAxis,
            edge.ratio,
          ))
            if (onArc(hit) && edge.containsParam(edge.paramOf(hit))) hit,
        ];
      case SplineEntity():
        return [
          for (final hit in Intersect.circlePolyline(
            arc.center,
            arc.radius,
            _flattenSpline(edge),
            closed: edge.closed,
          ))
            if (onArc(hit)) hit,
        ];
      default:
        return const [];
    }
  }

  static List<Vec2> _crossingsOnEllipse(EllipseEntity ellipse, CadEntity edge) {
    bool onEllipse(Vec2 hit) => ellipse.containsParam(ellipse.paramOf(hit));

    switch (edge) {
      case LineEntity(:final start, :final end):
        return [
          for (final hit in Intersect.segmentEllipse(
            start,
            end,
            ellipse.center,
            ellipse.majorAxis,
            ellipse.ratio,
          ))
            if (onEllipse(hit)) hit,
        ];
      case CircleEntity(:final center, :final radius):
        return [
          for (final hit in Intersect.circleEllipse(
            center,
            radius,
            ellipse.center,
            ellipse.majorAxis,
            ellipse.ratio,
          ))
            if (onEllipse(hit)) hit,
        ];
      case ArcEntity():
        return [
          for (final hit in Intersect.circleEllipse(
            edge.center,
            edge.radius,
            ellipse.center,
            ellipse.majorAxis,
            ellipse.ratio,
          ))
            if (onEllipse(hit) &&
                angularSweep(edge.startAngle, (hit - edge.center).angle) <=
                    edge.sweep + 1e-9)
              hit,
        ];
      case EllipseEntity():
        return [
          for (final hit in Intersect.ellipseEllipse(
            ellipse.center,
            ellipse.majorAxis,
            ellipse.ratio,
            edge.center,
            edge.majorAxis,
            edge.ratio,
          ))
            if (onEllipse(hit) && edge.containsParam(edge.paramOf(hit))) hit,
        ];
      case PolylineEntity():
        return [
          for (final arm in _polylineArms(edge))
            ..._crossingsOnEllipse(ellipse, arm),
        ];
      case SplineEntity():
        return [
          for (final hit in _splineHitsOnEllipse(ellipse, edge))
            if (onEllipse(hit)) hit,
        ];
      default:
        return const [];
    }
  }

  static List<Vec2> _crossingsOnSpline(SplineEntity spline, CadEntity edge) {
    final xy = _flattenSpline(spline);
    switch (edge) {
      case LineEntity(:final start, :final end):
        return Intersect.lineSpline(
          start,
          end,
          spline.controlPoints,
          knots: spline.knots,
          degree: spline.degree,
          weights: spline.weights,
          closed: spline.closed,
        );
      case CircleEntity(:final center, :final radius):
        return Intersect.circlePolyline(
          center,
          radius,
          xy,
          closed: spline.closed,
        );
      case ArcEntity():
        return [
          for (final hit in Intersect.circlePolyline(
            edge.center,
            edge.radius,
            xy,
            closed: spline.closed,
          ))
            if (angularSweep(edge.startAngle, (hit - edge.center).angle) <=
                edge.sweep + 1e-9)
              hit,
        ];
      case EllipseEntity():
        return _splineHitsOnEllipse(edge, spline);
      case PolylineEntity():
        return [
          for (final arm in _polylineArms(edge))
            ..._crossingsOnSpline(spline, arm),
        ];
      case SplineEntity():
        return Intersect.polylinePolyline(
          xy,
          _flattenSpline(edge),
          aClosed: spline.closed,
          bClosed: edge.closed,
        );
      default:
        return const [];
    }
  }

  static List<Vec2> _splineHitsOnEllipse(
    EllipseEntity ellipse,
    SplineEntity spline,
  ) {
    final xy = _flattenSpline(spline);
    final count = xy.length ~/ 2;
    if (count < 2) return const [];
    final out = <Vec2>[];
    final segments = spline.closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final a = Vec2(xy[i * 2], xy[i * 2 + 1]);
      final b = Vec2(xy[((i + 1) % count) * 2], xy[((i + 1) % count) * 2 + 1]);
      for (final hit in Intersect.segmentEllipse(
        a,
        b,
        ellipse.center,
        ellipse.majorAxis,
        ellipse.ratio,
      )) {
        if (out.every((p) => p.distanceSquaredTo(hit) > 1e-12)) out.add(hit);
      }
    }
    return out;
  }

  static Float64List _flattenSpline(
    SplineEntity spline, {
    double tolerance = 1e-3,
  }) => Flatten.bspline(
    controlPoints: spline.controlPoints,
    knots: spline.knots,
    degree: spline.degree,
    weights: spline.weights,
    tolerance: tolerance,
    closed: spline.closed,
  );

  /// Lengthens [line] until it meets one of [edges].
  static LineEntity? extendLine(LineEntity line, List<CadEntity> edges) {
    final direction = line.end - line.start;
    final lengthSquared = direction.lengthSquared;
    if (lengthSquared < 1e-18) return null;

    double? bestBefore;
    double? bestAfter;

    void consider(Vec2 hit) {
      final t = (hit - line.start).dot(direction) / lengthSquared;
      if (t < -1e-9) {
        if (bestBefore == null || t > bestBefore!) bestBefore = t;
      } else if (t > 1 + 1e-9) {
        if (bestAfter == null || t < bestAfter!) bestAfter = t;
      }
    }

    for (final edge in edges) {
      switch (edge) {
        case LineEntity(:final start, :final end):
          // The line is treated as infinite (extension happens beyond its
          // endpoints) but the boundary is not: the hit must land on the edge.
          final hit = Intersect.lineLine(line.start, line.end, start, end);
          if (hit == null) continue;
          if (Intersect.distanceToSegment(hit, start, end) > 1e-6) continue;
          consider(hit);
        case CircleEntity(:final center, :final radius):
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          )) {
            consider(hit);
          }
        case ArcEntity(:final center, :final radius):
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          )) {
            final angle = (hit - center).angle;
            if (angularSweep(edge.startAngle, angle) <= edge.sweep) {
              consider(hit);
            }
          }
        case PolylineEntity():
          for (final arm in _polylineArms(edge)) {
            switch (arm) {
              case LineEntity(:final start, :final end):
                final hit = Intersect.lineLine(
                  line.start,
                  line.end,
                  start,
                  end,
                );
                if (hit == null) continue;
                if (Intersect.distanceToSegment(hit, start, end) > 1e-6) {
                  continue;
                }
                consider(hit);
              case ArcEntity(:final center, :final radius):
                for (final hit in Intersect.lineCircle(
                  line.start,
                  line.end,
                  center,
                  radius,
                )) {
                  final angle = (hit - center).angle;
                  if (angularSweep(arm.startAngle, angle) <= arm.sweep) {
                    consider(hit);
                  }
                }
              default:
                continue;
            }
          }
        case EllipseEntity():
          for (final hit in Intersect.lineEllipse(
            line.start,
            line.end,
            edge.center,
            edge.majorAxis,
            edge.ratio,
          )) {
            if (edge.containsParam(edge.paramOf(hit))) consider(hit);
          }
        case SplineEntity():
          for (final hit in Intersect.lineSpline(
            line.start,
            line.end,
            edge.controlPoints,
            knots: edge.knots,
            degree: edge.degree,
            weights: edge.weights,
            closed: edge.closed,
            infinite: true,
          )) {
            consider(hit);
          }
        default:
          continue;
      }
    }

    // Prefer extending forward, which is the end the user is usually reaching
    // towards; fall back to the start.
    if (bestAfter != null) return resizedLine(line, 0, bestAfter!);
    if (bestBefore != null) return resizedLine(line, bestBefore!, 1);
    return null;
  }

  /// Lengthens an open [polyline] until an end meets one of [edges].
  ///
  /// [pick] chooses which end moves; omitted, the last vertex is tried first
  /// and the first vertex is the fallback. Only the free end travels — the
  /// inward vertex of that last segment stays put. A bulge grows along its
  /// supporting circle without closing into a full loop.
  static PolylineEntity? extendPolyline(
    PolylineEntity polyline,
    List<CadEntity> edges, [
    Vec2? pick,
  ]) {
    if (polyline.closed || polyline.vertexCount < 2) return null;
    final count = polyline.vertexCount;
    final start = polyline.vertexAt(0);
    final end = polyline.vertexAt(count - 1);
    final fromStart =
        pick != null &&
        pick.distanceSquaredTo(start) <= pick.distanceSquaredTo(end);

    PolylineEntity? tryEnd({required bool moveStart}) {
      final inward = moveStart
          ? polyline.vertexAt(1)
          : polyline.vertexAt(count - 2);
      final free = moveStart ? start : end;
      final bulge = polyline.bulgeAt(moveStart ? 0 : count - 2);
      if (bulge.abs() < 1e-12) {
        final arm = LineEntity(id: 0, start: inward, end: free);
        final extended = extendLine(arm, edges);
        if (extended == null) return null;
        if (extended.start.distanceTo(inward) > 1e-6) return null;
        if (extended.end.distanceTo(free) < 1e-9) return null;
        return polyline.withGrip(moveStart ? 0 : count - 1, extended.end);
      }
      final segStart = moveStart ? free : inward;
      final segEnd = moveStart ? inward : free;
      final def = Flatten.bulgeArc(segStart, segEnd, bulge);
      if (def == null) return null;
      final grown = extendArc(
        ArcEntity(
          id: 0,
          center: def.center,
          radius: def.radius,
          startAngle: def.startAngle,
          endAngle: def.endAngle,
        ),
        edges,
        free,
      );
      if (grown == null) return null;
      final newFree =
          free.distanceSquaredTo(grown.startPoint) <=
              free.distanceSquaredTo(grown.endPoint)
          ? grown.startPoint
          : grown.endPoint;
      if (newFree.distanceTo(free) < 1e-9) return null;
      final newBulge = (bulge >= 0 ? 1.0 : -1.0) * math.tan(grown.sweep / 4);
      return _polylineWithMovedEnd(polyline, moveStart, newFree, newBulge);
    }

    if (pick != null) {
      return tryEnd(moveStart: fromStart);
    }
    return tryEnd(moveStart: false) ?? tryEnd(moveStart: true);
  }

  static PolylineEntity _polylineWithMovedEnd(
    PolylineEntity source,
    bool moveStart,
    Vec2 newFree,
    double newBulge,
  ) {
    final count = source.vertexCount;
    final vertices = Float64List(count * 3);
    for (var i = 0; i < count; i++) {
      final point = (moveStart && i == 0) || (!moveStart && i == count - 1)
          ? newFree
          : source.vertexAt(i);
      vertices[i * 3] = point.x;
      vertices[i * 3 + 1] = point.y;
      final bulgeIndex = moveStart ? 0 : count - 2;
      vertices[i * 3 + 2] = i == bulgeIndex
          ? newBulge
          : (i < count - 1 ? source.bulgeAt(i) : 0);
    }
    return PolylineEntity(
      id: source.id,
      props: source.props,
      vertices: vertices,
      constantWidth: source.constantWidth,
    );
  }

  /// Lengthens [arc] along the circle until an end meets one of [edges].
  ///
  /// The supporting circle is treated as infinite (the sweep may grow) but
  /// each boundary is not: the hit must land on that edge. [pick] chooses
  /// which end moves; omitted, the end angle is tried first and the start
  /// is the fallback. A sweep that would close the circle is refused.
  static ArcEntity? extendArc(
    ArcEntity arc,
    List<CadEntity> edges, [
    Vec2? pick,
  ]) {
    if (arc.radius <= 0 || arc.sweep < 1e-12) return null;
    if (arc.sweep >= math.pi * 2 - 1e-9) return null;

    double? bestAfter;
    double? bestBefore;
    final room = math.pi * 2 - arc.sweep;

    void consider(Vec2 hit) {
      if ((hit.distanceTo(arc.center) - arc.radius).abs() > 1e-6) return;
      final angle = (hit - arc.center).angle;
      if (angularSweep(arc.startAngle, angle) <= arc.sweep + 1e-9) return;
      final after = angularSweep(arc.endAngle, angle);
      final before = angularSweep(angle, arc.startAngle);
      if (after > 1e-9 && after < room - 1e-9) {
        if (bestAfter == null || after < bestAfter!) bestAfter = after;
      }
      if (before > 1e-9 && before < room - 1e-9) {
        if (bestBefore == null || before < bestBefore!) bestBefore = before;
      }
    }

    for (final edge in edges) {
      for (final hit in _circleHitsOnEdge(arc.center, arc.radius, edge)) {
        consider(hit);
      }
    }

    ArcEntity? growEnd() {
      if (bestAfter == null) return null;
      return ArcEntity(
        id: arc.id,
        props: arc.props,
        center: arc.center,
        radius: arc.radius,
        startAngle: arc.startAngle,
        endAngle: arc.endAngle + bestAfter!,
      );
    }

    ArcEntity? growStart() {
      if (bestBefore == null) return null;
      return ArcEntity(
        id: arc.id,
        props: arc.props,
        center: arc.center,
        radius: arc.radius,
        startAngle: arc.startAngle - bestBefore!,
        endAngle: arc.endAngle,
      );
    }

    if (pick != null) {
      return _arcParam(arc, pick) <= 0.5 ? growStart() : growEnd();
    }
    return growEnd() ?? growStart();
  }

  /// Hits of the circle [center]/[radius] with [edge], for EXTEND.
  static List<Vec2> _circleHitsOnEdge(
    Vec2 center,
    double radius,
    CadEntity edge,
  ) {
    switch (edge) {
      case LineEntity(:final start, :final end):
        return [
          for (final hit in Intersect.lineCircle(start, end, center, radius))
            if (Intersect.distanceToSegment(hit, start, end) < 1e-6) hit,
        ];
      case CircleEntity():
        return Intersect.circleCircle(center, radius, edge.center, edge.radius);
      case ArcEntity():
        return [
          for (final hit in Intersect.circleCircle(
            center,
            radius,
            edge.center,
            edge.radius,
          ))
            if (angularSweep(edge.startAngle, (hit - edge.center).angle) <=
                edge.sweep + 1e-9)
              hit,
        ];
      case PolylineEntity():
        return [
          for (final arm in _polylineArms(edge))
            ..._circleHitsOnEdge(center, radius, arm),
        ];
      case EllipseEntity():
        return [
          for (final hit in Intersect.circleEllipse(
            center,
            radius,
            edge.center,
            edge.majorAxis,
            edge.ratio,
          ))
            if (edge.containsParam(edge.paramOf(hit))) hit,
        ];
      case SplineEntity():
        return Intersect.circlePolyline(
          center,
          radius,
          _flattenSpline(edge),
          closed: edge.closed,
        );
      default:
        return const [];
    }
  }

  /// Each segment of [edge] as a line or the arc its bulge expands to.
  static Iterable<CadEntity> _polylineArms(PolylineEntity edge) sync* {
    final count = edge.vertexCount;
    if (count < 2) return;
    final segments = edge.closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final start = edge.vertexAt(i);
      final end = edge.vertexAt((i + 1) % count);
      final bulge = edge.bulgeAt(i);
      if (bulge.abs() < 1e-12) {
        yield LineEntity(id: 0, start: start, end: end);
        continue;
      }
      final def = Flatten.bulgeArc(start, end, bulge);
      if (def == null) {
        yield LineEntity(id: 0, start: start, end: end);
        continue;
      }
      yield ArcEntity(
        id: 0,
        center: def.center,
        radius: def.radius,
        startAngle: def.startAngle,
        endAngle: def.endAngle,
      );
    }
  }

  /// Rounds the corner between two lines, or trims them to a sharp join.
  ///
  /// [pick1] and [pick2] choose which side of the intersection to keep on each
  /// line, which is what makes an X yield one of four possible fillets rather
  /// than an arbitrary one. A [radius] of zero is FILLET with R=0: the lines
  /// meet at the corner and no arc is created.
  static FilletResult? filletLines(
    LineEntity first,
    LineEntity second,
    double radius,
    Vec2 pick1,
    Vec2 pick2, {
    EntityProps? arcProps,
  }) {
    if (radius < 0 || !radius.isFinite) return null;
    final corner = Intersect.lineLine(
      first.start,
      first.end,
      second.start,
      second.end,
    );
    if (corner == null) return null;

    final keep1 = _filletKeepDir(first, corner, pick1);
    final keep2 = _filletKeepDir(second, corner, pick2);
    if (keep1 == null || keep2 == null) return null;

    final bisector = keep1 + keep2;
    if (bisector.lengthSquared < 1e-16) return null;

    final alpha = math.acos(keep1.dot(keep2).clamp(-1.0, 1.0));
    if (alpha < 1e-9) return null;

    if (radius == 0) {
      return FilletResult(
        first: _filletArm(first, corner, keep1, corner),
        second: _filletArm(second, corner, keep2, corner),
      );
    }

    final half = alpha / 2;
    final offset = radius / math.tan(half);
    if (!offset.isFinite || offset < 0) return null;

    final tangent1 = corner + keep1 * offset;
    final tangent2 = corner + keep2 * offset;
    final center = corner + bisector.normalized() * (radius / math.sin(half));

    // The arc must face the corner: the shorter sweep whose interior points
    // toward the intersection, not the long way around the circle.
    final startAngle = (tangent1 - center).angle;
    final endAngle = (tangent2 - center).angle;
    final viaAngle = (corner - center).angle;
    final forward =
        angularSweep(startAngle, viaAngle) <=
        angularSweep(startAngle, endAngle);

    return FilletResult(
      first: _filletArm(first, corner, keep1, tangent1),
      second: _filletArm(second, corner, keep2, tangent2),
      arc: ArcEntity(
        id: 0,
        props: arcProps ?? first.props,
        center: center,
        radius: radius,
        startAngle: forward ? startAngle : endAngle,
        endAngle: forward ? endAngle : startAngle,
      ),
    );
  }

  /// Rounds the vertex of [polyline] nearest [pick] with a bulge arc.
  ///
  /// Open polylines skip their endpoints — those are not corners. Incoming
  /// and outgoing segments must already be straight; filleting an existing
  /// arc would need a different construction.
  static PolylineEntity? filletPolylineVertex(
    PolylineEntity polyline,
    Vec2 pick,
    double radius,
  ) {
    if (radius <= 0 || !radius.isFinite) return null;
    final count = polyline.vertexCount;
    if (count < 3) return null;

    var best = -1;
    var bestDistance = double.infinity;
    final firstIndex = polyline.closed ? 0 : 1;
    final lastIndex = polyline.closed ? count : count - 1;
    for (var i = firstIndex; i < lastIndex; i++) {
      final prev = (i - 1 + count) % count;
      if (polyline.bulgeAt(prev).abs() > 1e-9) continue;
      if (polyline.bulgeAt(i).abs() > 1e-9) continue;
      final distance = polyline.vertexAt(i).distanceSquaredTo(pick);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best < 0) return null;

    final prevIndex = (best - 1 + count) % count;
    final nextIndex = (best + 1) % count;
    final prev = polyline.vertexAt(prevIndex);
    final corner = polyline.vertexAt(best);
    final next = polyline.vertexAt(nextIndex);
    final incoming = LineEntity(id: 0, start: prev, end: corner);
    final outgoing = LineEntity(id: 0, start: corner, end: next);
    final filleted = filletLines(
      incoming,
      outgoing,
      radius,
      incoming.midpoint,
      outgoing.midpoint,
    );
    if (filleted?.arc == null) return null;

    final tangent1 = filleted!.first.start;
    final tangent2 = filleted.second.start;
    if (Intersect.distanceToSegment(tangent1, prev, corner) > 1e-6) {
      return null;
    }
    if (Intersect.distanceToSegment(tangent2, corner, next) > 1e-6) {
      return null;
    }
    if (tangent1.distanceTo(prev) < 1e-9 ||
        tangent1.distanceTo(corner) < 1e-9 ||
        tangent2.distanceTo(next) < 1e-9 ||
        tangent2.distanceTo(corner) < 1e-9) {
      return null;
    }

    final arc = filleted.arc!;
    final startFirst =
        tangent1.distanceSquaredTo(arc.startPoint) <=
        tangent1.distanceSquaredTo(arc.endPoint);
    final bulge = math.tan((startFirst ? arc.sweep : -arc.sweep) / 4);

    final out = Float64List((count + 1) * 3);
    var write = 0;
    for (var i = 0; i < count; i++) {
      if (i == best) {
        out[write++] = tangent1.x;
        out[write++] = tangent1.y;
        out[write++] = bulge;
        out[write++] = tangent2.x;
        out[write++] = tangent2.y;
        out[write++] = 0;
      } else {
        out[write++] = polyline.vertices[i * 3];
        out[write++] = polyline.vertices[i * 3 + 1];
        out[write++] = polyline.vertices[i * 3 + 2];
      }
    }
    return PolylineEntity(
      id: polyline.id,
      props: polyline.props,
      vertices: out,
      closed: polyline.closed,
      constantWidth: polyline.constantWidth,
    );
  }

  /// Rounds every straight corner of [polyline] with the same [radius].
  ///
  /// That is AutoCAD FILLET's Polyline option: each eligible vertex is
  /// replaced in turn. A corner that is already an arc, or whose adjoining
  /// segments are shorter than [radius], is skipped so the rest can still
  /// round. Returns null when nothing changed.
  static PolylineEntity? filletPolyline(
    PolylineEntity polyline,
    double radius,
  ) {
    if (radius <= 0 || !radius.isFinite) return null;
    final count = polyline.vertexCount;
    if (count < 3) return null;
    final firstIndex = polyline.closed ? 0 : 1;
    final lastIndex = polyline.closed ? count : count - 1;
    final corners = [
      for (var i = firstIndex; i < lastIndex; i++) polyline.vertexAt(i),
    ];
    var current = polyline;
    var changed = false;
    for (final corner in corners) {
      final next = filletPolylineVertex(current, corner, radius);
      if (next == null) continue;
      current = next;
      changed = true;
    }
    return changed ? current : null;
  }

  /// Cuts a straight chamfer between two lines.
  ///
  /// [dist1] and [dist2] are the distances from the intersection back along
  /// each kept arm. Both zero is CHAMFER with D=0: a sharp corner and no cut.
  static ChamferResult? chamferLines(
    LineEntity first,
    LineEntity second,
    double dist1,
    double dist2,
    Vec2 pick1,
    Vec2 pick2, {
    EntityProps? cutProps,
  }) {
    if (dist1 < 0 || dist2 < 0 || !dist1.isFinite || !dist2.isFinite) {
      return null;
    }
    final corner = Intersect.lineLine(
      first.start,
      first.end,
      second.start,
      second.end,
    );
    if (corner == null) return null;

    final keep1 = _filletKeepDir(first, corner, pick1);
    final keep2 = _filletKeepDir(second, corner, pick2);
    if (keep1 == null || keep2 == null) return null;

    final bisector = keep1 + keep2;
    if (bisector.lengthSquared < 1e-16) return null;
    final alpha = math.acos(keep1.dot(keep2).clamp(-1.0, 1.0));
    if (alpha < 1e-9) return null;

    if (dist1 == 0 && dist2 == 0) {
      return ChamferResult(
        first: _filletArm(first, corner, keep1, corner),
        second: _filletArm(second, corner, keep2, corner),
      );
    }

    final tangent1 = corner + keep1 * dist1;
    final tangent2 = corner + keep2 * dist2;
    return ChamferResult(
      first: _filletArm(first, corner, keep1, tangent1),
      second: _filletArm(second, corner, keep2, tangent2),
      cut: LineEntity(
        id: 0,
        props: cutProps ?? first.props,
        start: tangent1,
        end: tangent2,
      ),
    );
  }

  /// Bevels the vertex of [polyline] nearest [pick].
  ///
  /// [dist1] is measured back along the incoming segment, [dist2] along the
  /// outgoing one. Both must be positive and shorter than those segments.
  static PolylineEntity? chamferPolylineVertex(
    PolylineEntity polyline,
    Vec2 pick, {
    required double dist1,
    double? dist2,
  }) {
    final second = dist2 ?? dist1;
    if (dist1 <= 0 || second <= 0 || !dist1.isFinite || !second.isFinite) {
      return null;
    }
    final count = polyline.vertexCount;
    if (count < 3) return null;

    var best = -1;
    var bestDistance = double.infinity;
    final firstIndex = polyline.closed ? 0 : 1;
    final lastIndex = polyline.closed ? count : count - 1;
    for (var i = firstIndex; i < lastIndex; i++) {
      final prev = (i - 1 + count) % count;
      if (polyline.bulgeAt(prev).abs() > 1e-9) continue;
      if (polyline.bulgeAt(i).abs() > 1e-9) continue;
      final distance = polyline.vertexAt(i).distanceSquaredTo(pick);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best < 0) return null;

    final prevIndex = (best - 1 + count) % count;
    final nextIndex = (best + 1) % count;
    final prev = polyline.vertexAt(prevIndex);
    final corner = polyline.vertexAt(best);
    final next = polyline.vertexAt(nextIndex);
    final incoming = LineEntity(id: 0, start: prev, end: corner);
    final outgoing = LineEntity(id: 0, start: corner, end: next);
    final chamfered = chamferLines(
      incoming,
      outgoing,
      dist1,
      second,
      incoming.midpoint,
      outgoing.midpoint,
    );
    if (chamfered?.cut == null) return null;

    final tangent1 = chamfered!.first.start;
    final tangent2 = chamfered.second.start;
    if (Intersect.distanceToSegment(tangent1, prev, corner) > 1e-6) {
      return null;
    }
    if (Intersect.distanceToSegment(tangent2, corner, next) > 1e-6) {
      return null;
    }
    if (tangent1.distanceTo(prev) < 1e-9 ||
        tangent1.distanceTo(corner) < 1e-9 ||
        tangent2.distanceTo(next) < 1e-9 ||
        tangent2.distanceTo(corner) < 1e-9) {
      return null;
    }

    final out = Float64List((count + 1) * 3);
    var write = 0;
    for (var i = 0; i < count; i++) {
      if (i == best) {
        out[write++] = tangent1.x;
        out[write++] = tangent1.y;
        out[write++] = 0;
        out[write++] = tangent2.x;
        out[write++] = tangent2.y;
        out[write++] = 0;
      } else {
        out[write++] = polyline.vertices[i * 3];
        out[write++] = polyline.vertices[i * 3 + 1];
        out[write++] = polyline.vertices[i * 3 + 2];
      }
    }
    return PolylineEntity(
      id: polyline.id,
      props: polyline.props,
      vertices: out,
      closed: polyline.closed,
      constantWidth: polyline.constantWidth,
    );
  }

  /// Bevels every straight corner of [polyline] with the same distances.
  ///
  /// That is AutoCAD CHAMFER's Polyline option: each eligible vertex is
  /// replaced in turn. A corner that is already an arc, or whose adjoining
  /// segments are shorter than the distances, is skipped so the rest can
  /// still cut. Returns null when nothing changed.
  static PolylineEntity? chamferPolyline(
    PolylineEntity polyline, {
    required double dist1,
    double? dist2,
  }) {
    final second = dist2 ?? dist1;
    if (dist1 <= 0 || second <= 0 || !dist1.isFinite || !second.isFinite) {
      return null;
    }
    final count = polyline.vertexCount;
    if (count < 3) return null;
    final firstIndex = polyline.closed ? 0 : 1;
    final lastIndex = polyline.closed ? count : count - 1;
    final corners = [
      for (var i = firstIndex; i < lastIndex; i++) polyline.vertexAt(i),
    ];
    var current = polyline;
    var changed = false;
    for (final corner in corners) {
      final next = chamferPolylineVertex(
        current,
        corner,
        dist1: dist1,
        dist2: second,
      );
      if (next == null) continue;
      current = next;
      changed = true;
    }
    return changed ? current : null;
  }

  /// Breaks [line] at [first], or removes the span between [first] and [second].
  ///
  /// One point splits the line in two. Two points drop the middle and leave
  /// the outer remnants (either of which may vanish if a point is an endpoint).
  /// Returns null when the break would not change the line; an empty list when
  /// the whole line is removed.
  static List<LineEntity>? breakLine(
    LineEntity line,
    Vec2 first, [
    Vec2? second,
  ]) {
    final along = line.end - line.start;
    final lengthSquared = along.lengthSquared;
    if (lengthSquared < 1e-20) return null;

    double param(Vec2 point) =>
        ((point - line.start).dot(along) / lengthSquared).clamp(0.0, 1.0);

    var t1 = param(first);
    var t2 = second == null ? t1 : param(second);
    if (t1 > t2) {
      final swap = t1;
      t1 = t2;
      t2 = swap;
    }

    final pieces = <LineEntity>[];
    if (t1 > 1e-9) {
      pieces.add(
        LineEntity(
          id: line.id,
          props: line.props,
          start: line.start,
          end: line.start + along * t1,
        ),
      );
    }
    if (t2 < 1 - 1e-9) {
      pieces.add(
        LineEntity(
          id: pieces.isEmpty ? line.id : 0,
          props: line.props,
          start: line.start + along * t2,
          end: line.end,
        ),
      );
    }
    if (pieces.length == 1 &&
        pieces.first.start.distanceTo(line.start) < 1e-12 &&
        pieces.first.end.distanceTo(line.end) < 1e-12) {
      return null;
    }
    return pieces;
  }

  /// Breaks [polyline] at [first], or drops the span from [first] to [second].
  ///
  /// A bulge is split into two smaller bulges at the pick. One point on an
  /// open polyline splits it in two; on a closed polyline it opens the loop
  /// there. Two points remove the part that runs from the first pick toward
  /// the second, which is how AutoCAD chooses which side of a closed shape
  /// disappears.
  ///
  /// Returns null when nothing would change; an empty list when the whole
  /// polyline is removed.
  static List<PolylineEntity>? breakPolyline(
    PolylineEntity polyline,
    Vec2 first, [
    Vec2? second,
  ]) {
    if (polyline.vertexCount < 2) return null;
    final hit1 = _polylineHit(polyline, first);
    if (hit1 == null) return null;
    if (second == null) return _breakPolylineAt(polyline, [hit1]);
    final hit2 = _polylineHit(polyline, second);
    if (hit2 == null) return null;
    return _breakPolylineAt(polyline, [hit1, hit2]);
  }

  static _PolyHit? _polylineHit(PolylineEntity polyline, Vec2 pick) {
    final count = polyline.vertexCount;
    final segments = polyline.closed ? count : count - 1;
    if (segments <= 0) return null;
    var bestDistance = double.infinity;
    var bestSegment = 0;
    var bestT = 0.0;
    var bestPoint = polyline.vertexAt(0);
    for (var i = 0; i < segments; i++) {
      final start = polyline.vertexAt(i);
      final end = polyline.vertexAt((i + 1) % count);
      final closest = _closestOnSegment(start, end, polyline.bulgeAt(i), pick);
      if (closest == null) continue;
      if (closest.dist2 < bestDistance) {
        bestDistance = closest.dist2;
        bestSegment = i;
        bestT = closest.t;
        bestPoint = closest.point;
      }
    }
    return _PolyHit(bestSegment, bestT, bestPoint);
  }

  static ({Vec2 point, double t, double dist2})? _closestOnSegment(
    Vec2 start,
    Vec2 end,
    double bulge,
    Vec2 pick,
  ) {
    if (bulge.abs() < 1e-12) {
      final delta = end - start;
      final lengthSquared = delta.lengthSquared;
      if (lengthSquared < 1e-20) return null;
      final t = ((pick - start).dot(delta) / lengthSquared).clamp(0.0, 1.0);
      final point = start + delta * t;
      return (point: point, t: t, dist2: pick.distanceSquaredTo(point));
    }
    final def = Flatten.bulgeArc(start, end, bulge);
    if (def == null) return _closestOnSegment(start, end, 0, pick);
    final startAngle = (start - def.center).angle;
    final signedSweep = 4 * math.atan(bulge);
    final t = _clampToSweep(startAngle, signedSweep, (pick - def.center).angle);
    final point =
        def.center + Vec2.polar(startAngle + signedSweep * t, def.radius);
    return (point: point, t: t, dist2: pick.distanceSquaredTo(point));
  }

  static double _clampToSweep(
    double startAngle,
    double signedSweep,
    double pickAngle,
  ) {
    if (signedSweep.abs() < 1e-12) return 0;
    if (signedSweep > 0) {
      final along = angularSweep(startAngle, pickAngle);
      if (along <= signedSweep + 1e-9) {
        return (along / signedSweep).clamp(0.0, 1.0);
      }
      return along - signedSweep < 2 * math.pi - along ? 1.0 : 0.0;
    }
    final along = angularSweep(pickAngle, startAngle);
    final mag = -signedSweep;
    if (along <= mag + 1e-9) {
      return (along / mag).clamp(0.0, 1.0);
    }
    return along - mag < 2 * math.pi - along ? 1.0 : 0.0;
  }

  static List<PolylineEntity>? _breakPolylineAt(
    PolylineEntity polyline,
    List<_PolyHit> hits,
  ) {
    final verts = _polylineVertsWithBreaks(polyline, hits);
    final indices = [
      for (final hit in hits) _nearestPolyVertIndex(verts, hit.point),
    ];
    if (hits.length == 1) {
      final index = indices.first;
      if (!polyline.closed) {
        if (index <= 0 || index >= verts.length - 1) return null;
        final left = verts.sublist(0, index + 1);
        final right = verts.sublist(index);
        return [
          _openPolyVerts(polyline, left, polyline.id),
          _openPolyVerts(polyline, right, 0),
        ];
      }
      final opened = [
        ...verts.sublist(index),
        ...verts.sublist(0, index),
        verts[index],
      ];
      if (opened.length < 3) return const [];
      return [_openPolyVerts(polyline, opened, polyline.id)];
    }

    final first = indices[0];
    final second = indices[1];
    if (first == second) {
      return _breakPolylineAt(polyline, [hits.first]);
    }
    if (!polyline.closed) {
      final lo = first < second ? first : second;
      final hi = first < second ? second : first;
      final pieces = <PolylineEntity>[];
      final left = verts.sublist(0, lo + 1);
      final right = verts.sublist(hi);
      if (left.length >= 2) {
        pieces.add(_openPolyVerts(polyline, left, polyline.id));
      }
      if (right.length >= 2) {
        pieces.add(
          _openPolyVerts(polyline, right, pieces.isEmpty ? polyline.id : 0),
        );
      }
      if (pieces.isEmpty) return const [];
      if (pieces.length == 1 &&
          pieces.first.vertexCount == polyline.vertexCount &&
          !polyline.closed) {
        return null;
      }
      return pieces;
    }

    final remaining = first < second
        ? [...verts.sublist(second), ...verts.sublist(0, first + 1)]
        : verts.sublist(second, first + 1);
    if (remaining.length < 2) return const [];
    return [_openPolyVerts(polyline, remaining, polyline.id)];
  }

  static List<_PolyVert> _polylineVertsWithBreaks(
    PolylineEntity polyline,
    List<_PolyHit> hits,
  ) {
    final count = polyline.vertexCount;
    final segments = polyline.closed ? count : count - 1;
    final out = <_PolyVert>[];
    for (var i = 0; i < count; i++) {
      final bulge = i < segments ? polyline.bulgeAt(i) : 0.0;
      out.add(_PolyVert(polyline.vertexAt(i), bulge));
      if (i >= segments) continue;
      final extras = [
        for (final hit in hits)
          if (hit.segment == i && hit.t > 1e-9 && hit.t < 1 - 1e-9) hit,
      ]..sort((a, b) => a.t.compareTo(b.t));
      if (extras.isEmpty) continue;
      final ts = [0.0, for (final hit in extras) hit.t, 1.0];
      out.last.bulge = _partialBulge(bulge, ts[0], ts[1]);
      for (var k = 0; k < extras.length; k++) {
        out.add(
          _PolyVert(
            extras[k].point,
            _partialBulge(bulge, ts[k + 1], ts[k + 2]),
          ),
        );
      }
    }
    return out;
  }

  static double _partialBulge(double bulge, double fromT, double toT) {
    if (bulge.abs() < 1e-12) return 0;
    return math.tan(math.atan(bulge) * (toT - fromT));
  }

  static int _nearestPolyVertIndex(List<_PolyVert> verts, Vec2 target) {
    var best = 0;
    var bestDistance = verts.first.point.distanceSquaredTo(target);
    for (var i = 1; i < verts.length; i++) {
      final distance = verts[i].point.distanceSquaredTo(target);
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  static List<_PolyVert> _polyVertsOf(PolylineEntity polyline) {
    final count = polyline.vertexCount;
    return [
      for (var i = 0; i < count; i++)
        _PolyVert(
          polyline.vertexAt(i),
          i < count - 1 ? polyline.bulgeAt(i) : 0,
        ),
    ];
  }

  static List<_PolyVert> _reversedPolyVerts(List<_PolyVert> verts) {
    final count = verts.length;
    return [
      for (var i = 0; i < count; i++)
        _PolyVert(
          verts[count - 1 - i].point,
          i < count - 1 ? -verts[count - 2 - i].bulge : 0,
        ),
    ];
  }

  static PolylineEntity _openPolyVerts(
    PolylineEntity source,
    List<_PolyVert> verts,
    int id,
  ) {
    final vertices = Float64List(verts.length * 3);
    for (var i = 0; i < verts.length; i++) {
      vertices[i * 3] = verts[i].point.x;
      vertices[i * 3 + 1] = verts[i].point.y;
      vertices[i * 3 + 2] = i < verts.length - 1 ? verts[i].bulge : 0;
    }
    return PolylineEntity(
      id: id,
      props: source.props,
      vertices: vertices,
      constantWidth: source.constantWidth,
    );
  }

  static PolylineEntity _openPolyline(
    PolylineEntity source,
    List<Vec2> points,
    int id,
  ) {
    final created = PolylineEntity.fromPoints(
      id: id,
      props: source.props,
      points: points,
    );
    if (source.constantWidth == 0) return created;
    return PolylineEntity(
      id: created.id,
      props: created.props,
      vertices: created.vertices,
      constantWidth: source.constantWidth,
    );
  }

  /// Breaks [arc] at [first], or drops the span between [first] and [second].
  ///
  /// One point splits the arc in two. Two points drop the interior along the
  /// sweep (the earlier parameter first) and leave the outer remnants.
  /// Returns null when nothing would change; an empty list when the whole
  /// arc is removed.
  static List<ArcEntity>? breakArc(ArcEntity arc, Vec2 first, [Vec2? second]) {
    if (arc.radius <= 0 || arc.sweep < 1e-12) return null;
    var t1 = _arcParam(arc, first);
    var t2 = second == null ? t1 : _arcParam(arc, second);
    if (t1 > t2) {
      final swap = t1;
      t1 = t2;
      t2 = swap;
    }
    final pieces = <ArcEntity>[];
    if (t1 > 1e-9) {
      pieces.add(_arcSpan(arc, 0, t1, arc.id));
    }
    if (t2 < 1 - 1e-9) {
      pieces.add(_arcSpan(arc, t2, 1, pieces.isEmpty ? arc.id : 0));
    }
    if (pieces.isEmpty) return const [];
    if (pieces.length == 1 &&
        (pieces.first.startAngle - arc.startAngle).abs() < 1e-9 &&
        angularSweep(pieces.first.startAngle, pieces.first.endAngle) >
            arc.sweep - 1e-9) {
      return null;
    }
    return pieces;
  }

  /// Breaks [circle] between two points, leaving the CCW remnant from the
  /// second pick back to the first. One point cannot open a circle.
  static List<ArcEntity>? breakCircle(
    CircleEntity circle,
    Vec2 first, [
    Vec2? second,
  ]) {
    if (second == null || circle.radius <= 0) return null;
    final start = (second - circle.center).angle;
    final end = (first - circle.center).angle;
    final sweep = angularSweep(start, end);
    if (sweep < 1e-9 || sweep > math.pi * 2 - 1e-9) return null;
    return [
      ArcEntity(
        id: circle.id,
        props: circle.props,
        center: circle.center,
        radius: circle.radius,
        startAngle: start,
        endAngle: end,
      ),
    ];
  }

  static double _arcParam(ArcEntity arc, Vec2 pick) {
    final angle = (pick - arc.center).angle;
    return (angularSweep(arc.startAngle, angle) / arc.sweep).clamp(0.0, 1.0);
  }

  static ArcEntity _arcSpan(ArcEntity arc, double from, double to, int id) {
    return ArcEntity(
      id: id,
      props: arc.props,
      center: arc.center,
      radius: arc.radius,
      startAngle: arc.startAngle + arc.sweep * from,
      endAngle: arc.startAngle + arc.sweep * to,
    );
  }

  /// Direction from the corner along the side of [line] that [pick] sits on.
  static Vec2? _filletKeepDir(LineEntity line, Vec2 corner, Vec2 pick) {
    final along = line.end - line.start;
    final denom = along.lengthSquared;
    if (denom < 1e-20) return null;
    final projected =
        line.start + along * ((pick - line.start).dot(along) / denom);
    var dir = projected - corner;
    if (dir.lengthSquared < 1e-20) {
      final startLen = line.start.distanceSquaredTo(corner);
      final endLen = line.end.distanceSquaredTo(corner);
      dir = startLen >= endLen ? line.start - corner : line.end - corner;
    }
    if (dir.lengthSquared < 1e-20) return null;
    return dir.normalized();
  }

  /// The remnant of [line] from [tangent] out along [keepDir].
  static LineEntity _filletArm(
    LineEntity line,
    Vec2 corner,
    Vec2 keepDir,
    Vec2 tangent,
  ) {
    final startDot = (line.start - corner).dot(keepDir);
    final endDot = (line.end - corner).dot(keepDir);
    final far = startDot >= endDot ? line.start : line.end;
    return LineEntity(
      id: line.id,
      props: line.props,
      start: tangent,
      end: far.distanceTo(tangent) < 1e-12 ? tangent + keepDir : far,
    );
  }

  /// Reverses the direction of a line or polyline.
  ///
  /// Vertex order flips, and each bulge is negated and moved onto the segment
  /// that now runs the other way, so the drawn curve stays the same.
  static CadEntity? reverse(CadEntity entity) => entity.reversed();

  /// Joins [entities] whose endpoints meet into one polyline.
  ///
  /// Lines, arcs and open polylines can mix; a piece is reversed when that
  /// is how it touches the chain. An arc is stored as a bulge. Closed or
  /// unsupported objects return null, as do selections that do not form a
  /// single connected path. A loop whose ends meet is stored closed without
  /// a duplicate last vertex.
  static PolylineEntity? joinEntities(
    List<CadEntity> entities, {
    double gap = 1e-6,
    int id = 0,
  }) {
    if (entities.length < 2) return null;
    final runs = <_JoinRun>[];
    for (final entity in entities) {
      final run = _JoinRun.from(entity);
      if (run == null) return null;
      runs.add(run);
    }
    var chain = runs.first;
    final remaining = runs.sublist(1);
    var progress = true;
    while (remaining.isNotEmpty && progress) {
      progress = false;
      for (var i = 0; i < remaining.length; i++) {
        final piece = remaining[i];
        if (piece.start.distanceTo(chain.end) <= gap) {
          chain = chain.appended(piece);
        } else if (piece.end.distanceTo(chain.end) <= gap) {
          chain = chain.appended(piece.reversed);
        } else if (piece.end.distanceTo(chain.start) <= gap) {
          chain = piece.appended(chain);
        } else if (piece.start.distanceTo(chain.start) <= gap) {
          chain = piece.reversed.appended(chain);
        } else {
          continue;
        }
        remaining.removeAt(i);
        progress = true;
        break;
      }
    }
    if (remaining.isNotEmpty) return null;

    var points = chain.points;
    var bulges = chain.bulges;
    final closed =
        points.length > 2 && points.first.distanceTo(points.last) <= gap;
    if (closed) {
      points = points.sublist(0, points.length - 1);
      bulges = bulges.sublist(0, points.length);
    }

    var width = 0.0;
    for (final entity in entities) {
      if (entity is PolylineEntity && entity.constantWidth != 0) {
        width = entity.constantWidth;
        break;
      }
    }
    final vertices = Float64List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      vertices[i * 3] = points[i].x;
      vertices[i * 3 + 1] = points[i].y;
      vertices[i * 3 + 2] = i < bulges.length ? bulges[i] : 0;
    }
    return PolylineEntity(
      id: id,
      props: entities.first.props,
      vertices: vertices,
      closed: closed,
      constantWidth: width,
    );
  }

  /// Interior points that split [line] into [segments] equal pieces.
  ///
  /// DIVIDE places markers between the ends, not on them: 4 segments means
  /// three points. Endpoints are already geometry; repeating them as nodes
  /// just clutters the drawing.
  static List<Vec2> divideLine(LineEntity line, int segments) {
    if (segments < 2) return const [];
    return [
      for (var i = 1; i < segments; i++)
        line.start.lerp(line.end, i / segments),
    ];
  }

  /// Interior points that split [polyline] into [segments] equal pieces.
  ///
  /// Open polylines match [divideLine]: the endpoints stay unmarked. A closed
  /// loop has no leftover end, so it places [segments] points equally around
  /// the perimeter, including the start vertex. A bulge is measured along
  /// its arc, not the chord.
  static List<Vec2> dividePolyline(PolylineEntity polyline, int segments) {
    if (segments < 2 || polyline.vertexCount < 2) {
      return const [];
    }
    final length = _polylineLength(polyline);
    if (length < 1e-12) return const [];
    if (polyline.closed) {
      return [
        for (var i = 0; i < segments; i++)
          _pointAlongPolyline(polyline, length * i / segments),
      ];
    }
    return [
      for (var i = 1; i < segments; i++)
        _pointAlongPolyline(polyline, length * i / segments),
    ];
  }

  /// Interior points that split [arc] into [segments] equal pieces.
  ///
  /// The ends stay unmarked, same as [divideLine]: they are already the
  /// arc's start and end.
  static List<Vec2> divideArc(ArcEntity arc, int segments) {
    if (segments < 2 || arc.radius <= 0 || arc.sweep < 1e-12) {
      return const [];
    }
    return [
      for (var i = 1; i < segments; i++)
        arc.center +
            Vec2.polar(arc.startAngle + arc.sweep * i / segments, arc.radius),
    ];
  }

  /// Points equally spaced around [circle], starting at angle zero.
  ///
  /// A circle has no leftover end, so [segments] markers are placed, matching
  /// a closed polyline.
  static List<Vec2> divideCircle(CircleEntity circle, int segments) {
    if (segments < 2 || circle.radius <= 0) return const [];
    return [
      for (var i = 0; i < segments; i++)
        circle.center + Vec2.polar(2 * math.pi * i / segments, circle.radius),
    ];
  }

  /// Walks [polyline] from its start by [distance] along each segment.
  ///
  /// A bulge is followed as its circular arc, not the chord.
  static Vec2 _pointAlongPolyline(PolylineEntity polyline, double distance) {
    if (distance <= 1e-12) return polyline.vertexAt(0);
    final count = polyline.vertexCount;
    final segments = polyline.closed ? count : count - 1;
    var remaining = distance;
    for (var i = 0; i < segments; i++) {
      final from = polyline.vertexAt(i);
      final to = polyline.vertexAt((i + 1) % count);
      final bulge = polyline.bulgeAt(i);
      final segment = _segmentLength(from, to, bulge);
      if (segment < 1e-12) continue;
      if (remaining <= segment + 1e-12) {
        return _pointAlongSegment(from, to, bulge, remaining);
      }
      remaining -= segment;
    }
    return polyline.vertexAt(polyline.closed ? 0 : count - 1);
  }

  static double _segmentLength(Vec2 from, Vec2 to, double bulge) {
    if (bulge.abs() < 1e-12) return from.distanceTo(to);
    final def = Flatten.bulgeArc(from, to, bulge);
    if (def == null) return from.distanceTo(to);
    return def.radius * (4 * math.atan(bulge)).abs();
  }

  static Vec2 _pointAlongSegment(
    Vec2 from,
    Vec2 to,
    double bulge,
    double distance,
  ) {
    final length = _segmentLength(from, to, bulge);
    if (length < 1e-12) return from;
    final t = (distance / length).clamp(0.0, 1.0);
    if (bulge.abs() < 1e-12) return from.lerp(to, t);
    final def = Flatten.bulgeArc(from, to, bulge);
    if (def == null) return from.lerp(to, t);
    final startAngle = (from - def.center).angle;
    return def.center +
        Vec2.polar(startAngle + 4 * math.atan(bulge) * t, def.radius);
  }

  /// Points spaced [spacing] apart along [line], starting from the end nearer [pick].
  ///
  /// MEASURE never marks the endpoints: the first node is one interval in, and
  /// a leftover shorter than [spacing] at the far end is left unmarked.
  static List<Vec2> measureLine(LineEntity line, double spacing, Vec2 pick) {
    if (spacing <= 0 || !spacing.isFinite) return const [];
    final fromStart =
        pick.distanceSquaredTo(line.start) <= pick.distanceSquaredTo(line.end);
    final origin = fromStart ? line.start : line.end;
    final dest = fromStart ? line.end : line.start;
    final length = origin.distanceTo(dest);
    if (length <= spacing) return const [];
    return [
      for (var i = 1; i * spacing < length - 1e-12; i++)
        origin.lerp(dest, i * spacing / length),
    ];
  }

  /// Points spaced [spacing] apart along [polyline], starting from the nearer end.
  ///
  /// Open polylines match [measureLine]: the first node is one interval in from
  /// the end nearer [pick], and a leftover shorter than [spacing] is unmarked.
  /// A closed loop always walks forward from the start vertex. A bulge is
  /// measured along its arc, not the chord.
  static List<Vec2> measurePolyline(
    PolylineEntity polyline,
    double spacing,
    Vec2 pick,
  ) {
    if (spacing <= 0 || !spacing.isFinite || polyline.vertexCount < 2) {
      return const [];
    }
    final length = _polylineLength(polyline);
    if (length <= spacing) return const [];
    final fromStart =
        polyline.closed ||
        pick.distanceSquaredTo(polyline.vertexAt(0)) <=
            pick.distanceSquaredTo(polyline.vertexAt(polyline.vertexCount - 1));
    return [
      for (var i = 1; i * spacing < length - 1e-12; i++)
        _pointAlongPolyline(
          polyline,
          fromStart ? i * spacing : length - i * spacing,
        ),
    ];
  }

  /// Points spaced [spacing] apart along [arc], from the nearer end.
  ///
  /// The ends stay unmarked. Walking backward from the end uses the same
  /// leftover rule as [measureLine].
  static List<Vec2> measureArc(ArcEntity arc, double spacing, Vec2 pick) {
    if (spacing <= 0 || !spacing.isFinite || arc.radius <= 0) {
      return const [];
    }
    final length = arc.radius * arc.sweep;
    if (length <= spacing) return const [];
    final fromStart =
        pick.distanceSquaredTo(arc.startPoint) <=
        pick.distanceSquaredTo(arc.endPoint);
    return [
      for (var i = 1; i * spacing < length - 1e-12; i++)
        arc.center +
            Vec2.polar(
              fromStart
                  ? arc.startAngle + i * spacing / arc.radius
                  : arc.endAngle - i * spacing / arc.radius,
              arc.radius,
            ),
    ];
  }

  /// Points spaced [spacing] apart around [circle], starting at [pick].
  ///
  /// The starting location itself is not marked. A leftover shorter than
  /// [spacing] at the far end of the loop is left alone, so a spacing that
  /// divides the circumference exactly does not land on the start.
  static List<Vec2> measureCircle(
    CircleEntity circle,
    double spacing,
    Vec2 pick,
  ) {
    if (spacing <= 0 || !spacing.isFinite || circle.radius <= 0) {
      return const [];
    }
    final length = 2 * math.pi * circle.radius;
    if (length <= spacing) return const [];
    final startAngle = pick.distanceSquaredTo(circle.center) < 1e-20
        ? 0.0
        : (pick - circle.center).angle;
    return [
      for (var i = 1; i * spacing < length - 1e-12; i++)
        circle.center +
            Vec2.polar(startAngle + i * spacing / circle.radius, circle.radius),
    ];
  }

  /// Lengthens or shortens [line] by moving the endpoint nearer [pick].
  ///
  /// [total] sets the finished length. [delta] is added to the current length
  /// when [total] is omitted. The far end stays put, which is how LENGTHEN
  /// feels when you click the end you want to drag.
  static LineEntity? lengthenLine(
    LineEntity line,
    Vec2 pick, {
    double? delta,
    double? total,
  }) {
    final current = line.length;
    if (current < 1e-12) return null;
    final target = total ?? (current + (delta ?? 0));
    if (target <= 1e-12 || !target.isFinite) return null;
    final scale = target / current;
    final moveStart =
        pick.distanceSquaredTo(line.start) <= pick.distanceSquaredTo(line.end);
    return moveStart
        ? resizedLine(line, 1 - scale, 1)
        : resizedLine(line, 0, scale);
  }

  /// Changes the length of an open [polyline] from the nearer end.
  ///
  /// The opposite end stays put. Extending grows the last (or first) segment
  /// along its own path — a straight arm keeps its direction, a bulge grows
  /// its sweep without closing the circle. Shortening walks back through
  /// vertices and drops those that fall past the new total. Closed polylines
  /// return null.
  static PolylineEntity? lengthenPolyline(
    PolylineEntity polyline,
    Vec2 pick, {
    double? delta,
    double? total,
  }) {
    if (polyline.closed || polyline.vertexCount < 2) return null;
    final current = _polylineLength(polyline);
    if (current < 1e-12) return null;
    final target = total ?? (current + (delta ?? 0));
    if (target <= 1e-12 || !target.isFinite) return null;

    final start = polyline.vertexAt(0);
    final end = polyline.vertexAt(polyline.vertexCount - 1);
    final fromStart =
        pick.distanceSquaredTo(start) <= pick.distanceSquaredTo(end);
    var chain = _polyVertsOf(polyline);
    if (fromStart) chain = _reversedPolyVerts(chain);
    final trimmed = _trimChainToLengthVerts(chain, target);
    if (trimmed == null) return null;
    return _openPolyVerts(
      polyline,
      fromStart ? _reversedPolyVerts(trimmed) : trimmed,
      polyline.id,
    );
  }

  /// Changes the included length of [arc] from the nearer end.
  ///
  /// The far end stays put. The result must stay a proper open arc: a
  /// non-positive length, or a sweep that would close the circle, is refused.
  static ArcEntity? lengthenArc(
    ArcEntity arc,
    Vec2 pick, {
    double? delta,
    double? total,
  }) {
    if (arc.radius <= 0 || arc.sweep < 1e-12) return null;
    final current = arc.radius * arc.sweep;
    final target = total ?? (current + (delta ?? 0));
    if (target <= 1e-12 || !target.isFinite) return null;
    final newSweep = target / arc.radius;
    if (newSweep >= math.pi * 2 - 1e-9) return null;
    final fromStart =
        pick.distanceSquaredTo(arc.startPoint) <=
        pick.distanceSquaredTo(arc.endPoint);
    return ArcEntity(
      id: arc.id,
      props: arc.props,
      center: arc.center,
      radius: arc.radius,
      startAngle: fromStart ? arc.endAngle - newSweep : arc.startAngle,
      endAngle: fromStart ? arc.endAngle : arc.startAngle + newSweep,
    );
  }

  /// [verts] run from the fixed end toward the moving end.
  static List<_PolyVert>? _trimChainToLengthVerts(
    List<_PolyVert> verts,
    double target,
  ) {
    if (verts.length < 2) return null;
    final out = <_PolyVert>[_PolyVert(verts.first.point, 0)];
    var accumulated = 0.0;
    for (var i = 0; i < verts.length - 1; i++) {
      final from = verts[i].point;
      final to = verts[i + 1].point;
      final bulge = verts[i].bulge;
      final segment = _segmentLength(from, to, bulge);
      if (segment < 1e-12) continue;
      if (accumulated + segment >= target - 1e-12) {
        final remain = (target - accumulated).clamp(0.0, segment);
        final end = _pointAlongSegment(from, to, bulge, remain);
        out.last.bulge = _partialBulge(bulge, 0, remain / segment);
        if (end.distanceSquaredTo(out.last.point) > 1e-20) {
          out.add(_PolyVert(end, 0));
        }
        return out.length >= 2 ? out : null;
      }
      accumulated += segment;
      out.last.bulge = bulge;
      out.add(_PolyVert(to, 0));
    }
    final extra = target - accumulated;
    if (extra <= 1e-12) return out.length >= 2 ? out : null;
    if (out.length < 2) return null;
    final from = out[out.length - 2];
    final to = out.last;
    if (from.bulge.abs() < 1e-12) {
      final direction = to.point - from.point;
      if (direction.lengthSquared < 1e-20) return null;
      out[out.length - 1] = _PolyVert(
        to.point + direction.normalized() * extra,
        0,
      );
      return out;
    }
    final def = Flatten.bulgeArc(from.point, to.point, from.bulge);
    if (def == null) return null;
    final signedSweep = 4 * math.atan(from.bulge);
    final newLen = def.radius * signedSweep.abs() + extra;
    final newSweepAbs = newLen / def.radius;
    if (newSweepAbs >= math.pi * 2 - 1e-9) return null;
    final newSweep = signedSweep >= 0 ? newSweepAbs : -newSweepAbs;
    final startAngle = (from.point - def.center).angle;
    from.bulge = math.tan(newSweep / 4);
    out[out.length - 1] = _PolyVert(
      def.center + Vec2.polar(startAngle + newSweep, def.radius),
      0,
    );
    return out;
  }

  /// [points] run from the fixed end toward the moving end.
  static List<Vec2>? _trimChainToLength(List<Vec2> points, double target) {
    final out = <Vec2>[points.first];
    var accumulated = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      final segment = from.distanceTo(to);
      if (segment < 1e-12) continue;
      if (accumulated + segment >= target - 1e-12) {
        final t = ((target - accumulated) / segment).clamp(0.0, 1.0);
        final end = from + (to - from) * t;
        if (end.distanceSquaredTo(out.last) > 1e-20) out.add(end);
        return out.length >= 2 ? out : null;
      }
      accumulated += segment;
      out.add(to);
    }
    var direction = out.last - out[out.length - 2];
    if (direction.lengthSquared < 1e-20) return null;
    out[out.length - 1] =
        out.last + direction.normalized() * (target - accumulated);
    return out;
  }

  /// Moves the vertices of [entity] that sit inside [window] by [delta].
  ///
  /// That is the AutoCAD STRETCH contract: a crossing window names the grips
  /// that travel, and everything else stays anchored. An object whose defining
  /// points are all inside the window translates as a rigid body. Circles,
  /// ellipses and inserts only move when their centre (or insertion point) is
  /// captured — stretching a radius grip is a different edit.
  ///
  /// Returns null when the window misses every stretchable point, so the
  /// command can skip the entity instead of writing a no-op patch.
  static CadEntity? stretch(CadEntity entity, Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return entity.stretchBy(window, delta);
  }

  /// A copy of [line] spanning the parameter range `[from, to]`.
  static LineEntity resizedLine(LineEntity line, double from, double to) {
    final direction = line.end - line.start;
    return LineEntity(
      id: line.id,
      props: line.props,
      start: line.start + direction * from,
      end: line.start + direction * to,
    );
  }

  /// Every point where [line] meets [edge], for the trim family.
  static List<Vec2> crossingsWith(
    LineEntity line,
    CadEntity edge, {
    double tolerance = 1e-3,
  }) {
    switch (edge) {
      case LineEntity(:final start, :final end):
        final hit = Intersect.segmentSegment(line.start, line.end, start, end);
        return hit == null ? const [] : [hit];
      case CircleEntity(:final center, :final radius):
        return [
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          ))
            if (Intersect.distanceToSegment(hit, line.start, line.end) < 1e-6)
              hit,
        ];
      case ArcEntity(:final center, :final radius):
        return [
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          ))
            if (Intersect.distanceToSegment(hit, line.start, line.end) < 1e-6 &&
                angularSweep(edge.startAngle, (hit - center).angle) <=
                    edge.sweep)
              hit,
        ];
      case PolylineEntity():
        return [
          for (final arm in _polylineArms(edge))
            ...crossingsWith(line, arm, tolerance: tolerance),
        ];
      case EllipseEntity():
        return [
          for (final hit in Intersect.segmentEllipse(
            line.start,
            line.end,
            edge.center,
            edge.majorAxis,
            edge.ratio,
          ))
            if (edge.containsParam(edge.paramOf(hit))) hit,
        ];
      case SplineEntity():
        return Intersect.lineSpline(
          line.start,
          line.end,
          edge.controlPoints,
          knots: edge.knots,
          degree: edge.degree,
          weights: edge.weights,
          closed: edge.closed,
          tolerance: tolerance,
        );
      default:
        return const [];
    }
  }

  /// The total length of an entity, for the measurement tools.
  static double lengthOf(CadEntity entity) => entity.pathLength;

  static double _polylineLength(PolylineEntity polyline) => polyline.pathLength;

  /// The signed area enclosed by a closed entity. Positive is counter-clockwise.
  static double areaOf(CadEntity entity) => entity.signedArea;

  /// Ids that are exact geometric copies of an earlier entity in [entities].
  ///
  /// The first occurrence of each shape is kept; later copies are what
  /// OVERKILL deletes. A line drawn backwards is still the same stroke, so
  /// endpoint order does not count as a difference.
  static List<int> overkillIds(Iterable<CadEntity> entities) {
    final seen = <String>{};
    final duplicates = <int>[];
    for (final entity in entities) {
      final key = _geometryKey(entity);
      if (!seen.add(key)) {
        duplicates.add(entity.id);
      }
    }
    return duplicates;
  }

  /// Exact copies plus collinear line segments that overlap or abut.
  ///
  /// A leftover from OFFSET or a line drawn twice with a different length is
  /// the usual case: the first stroke is stretched to the union and the rest
  /// are deleted. Segments that only share a supporting line, with a gap
  /// between them, stay put. Colour and layer have to match; mixing a red
  /// leftover into a blue line would lose information.
  static OverkillResult overkill(Iterable<CadEntity> entities) {
    final list = entities.toList();
    final exact = overkillIds(list);
    final gone = exact.toSet();
    final remaining = [
      for (final entity in list)
        if (!gone.contains(entity.id)) entity,
    ];
    final merged = _mergeOverlappingLines(remaining);
    return OverkillResult(
      erase: [...exact, ...merged.erase],
      replace: merged.replace,
    );
  }

  static OverkillResult _mergeOverlappingLines(List<CadEntity> entities) {
    final groups = <String, List<_OverlapSpan>>{};
    for (var i = 0; i < entities.length; i++) {
      final entity = entities[i];
      final ends = _lineLikeEnds(entity);
      if (ends == null) continue;
      final axis = _CollinearAxis.tryParse(ends.$1, ends.$2);
      if (axis == null) continue;
      final t0 = axis.along(ends.$1);
      final t1 = axis.along(ends.$2);
      final lo = math.min(t0, t1);
      final hi = math.max(t0, t1);
      if (hi - lo < 1e-9) continue;
      final key = '${axis.key}|${_styleKey(entity)}';
      (groups[key] ??= []).add(_OverlapSpan(entity, i, axis, lo, hi, t0 <= t1));
    }

    final erase = <int>[];
    final replace = <CadEntity>[];
    for (final group in groups.values) {
      group.sort((a, b) => a.lo.compareTo(b.lo));
      var cluster = <_OverlapSpan>[group.first];
      var clusterHi = group.first.hi;
      void flush() {
        if (cluster.length < 2) return;
        cluster.sort((a, b) => a.order.compareTo(b.order));
        final keeper = cluster.first;
        var lo = cluster.first.lo;
        var hi = cluster.first.hi;
        for (final span in cluster.skip(1)) {
          lo = math.min(lo, span.lo);
          hi = math.max(hi, span.hi);
          erase.add(span.entity.id);
        }
        final start = keeper.forward ? keeper.axis.at(lo) : keeper.axis.at(hi);
        final end = keeper.forward ? keeper.axis.at(hi) : keeper.axis.at(lo);
        final grown = _lineLikeWithEnds(keeper.entity, start, end);
        if (grown != null &&
            (start.distanceTo(keeper.entityStart) > 1e-9 ||
                end.distanceTo(keeper.entityEnd) > 1e-9)) {
          replace.add(grown);
        }
      }

      for (var i = 1; i < group.length; i++) {
        final next = group[i];
        if (next.lo <= clusterHi + 1e-6) {
          cluster.add(next);
          clusterHi = math.max(clusterHi, next.hi);
        } else {
          flush();
          cluster = [next];
          clusterHi = next.hi;
        }
      }
      flush();
    }
    return OverkillResult(erase: erase, replace: replace);
  }

  static (Vec2, Vec2)? _lineLikeEnds(CadEntity entity) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        return (start, end);
      case PolylineEntity():
        if (entity.closed || entity.hasBulges || entity.vertexCount != 2) {
          return null;
        }
        return (entity.vertexAt(0), entity.vertexAt(1));
      default:
        return null;
    }
  }

  static CadEntity? _lineLikeWithEnds(CadEntity entity, Vec2 start, Vec2 end) {
    switch (entity) {
      case LineEntity():
        return LineEntity(
          id: entity.id,
          props: entity.props,
          start: start,
          end: end,
        );
      case PolylineEntity():
        return PolylineEntity(
          id: entity.id,
          props: entity.props,
          vertices: Float64List.fromList([
            start.x,
            start.y,
            0,
            end.x,
            end.y,
            0,
          ]),
          closed: false,
          constantWidth: entity.constantWidth,
        );
      default:
        return null;
    }
  }

  static String _styleKey(CadEntity entity) {
    final props = entity.props;
    final width = entity is PolylineEntity ? entity.constantWidth : 0.0;
    return '${props.layer}|${props.color}|${props.lineType}|'
        '${props.lineWeight}|${_qty(width)}';
  }

  static String _geometryKey(CadEntity entity) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        return _undirectedSegmentKey(start, end);
      case CircleEntity(:final center, :final radius):
        return 'C|${_qty(center.x)},${_qty(center.y)}|${_qty(radius)}';
      case PointEntity(:final position):
        return 'P|${_qty(position.x)},${_qty(position.y)}';
      case ArcEntity(
        :final center,
        :final radius,
        :final startAngle,
        :final endAngle,
      ):
        return 'A|${_qty(center.x)},${_qty(center.y)}|${_qty(radius)}|'
            '${_qty(startAngle)}|${_qty(endAngle)}';
      case PolylineEntity():
        if (entity.vertexCount == 2 && !entity.hasBulges) {
          return _undirectedSegmentKey(entity.vertexAt(0), entity.vertexAt(1));
        }
        final verts = [
          for (var i = 0; i < entity.vertexCount; i++)
            '${_qty(entity.vertexAt(i).x)},${_qty(entity.vertexAt(i).y)},'
                '${_qty(entity.bulgeAt(i))}',
        ].join(';');
        return 'PL|${entity.closed}|$verts';
      default:
        return '${entity.kind.name}|${entity.geometryToJson()}';
    }
  }

  static String _undirectedSegmentKey(Vec2 a, Vec2 b) {
    final first = '${_qty(a.x)},${_qty(a.y)}';
    final second = '${_qty(b.x)},${_qty(b.y)}';
    return first.compareTo(second) <= 0
        ? 'L|$first|$second'
        : 'L|$second|$first';
  }

  static String _qty(double value) => value.toStringAsFixed(6);

  /// Changes text justification and shifts the insertion point so the glyphs
  /// stay put, using the same width estimate as [TextGeometry.estimatedBounds].
  ///
  /// Align and Fit need a second point and are rejected. Unknown keywords
  /// return null.
  static TextEntity? justifyText(TextEntity entity, String justify) {
    final next = parseTextJustify(
      justify,
      currentH: entity.hAlign,
      currentV: entity.vAlign,
    );
    if (next == null) return null;
    final width =
        entity.content.length * entity.height * 0.62 * entity.widthFactor;
    final totalHeight = entity.height * 1.2;
    final delta =
        (_textAlignOffset(entity.hAlign, entity.vAlign, width, totalHeight) -
                _textAlignOffset(next.h, next.v, width, totalHeight))
            .rotated(entity.rotation);
    return TextEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position + delta,
      content: entity.content,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      widthFactor: entity.widthFactor,
      obliqueAngle: entity.obliqueAngle,
      hAlign: next.h,
      vAlign: next.v,
    );
  }

  /// Same as [justifyText] for MTEXT, rewriting the 1–9 attachment point.
  static MTextEntity? justifyMText(MTextEntity entity, String justify) {
    final next = parseTextJustify(
      justify,
      currentH: entity.hAlign,
      currentV: entity.vAlign,
    );
    if (next == null) return null;
    final lines = entity.plainText.split('\n');
    var longest = 0;
    for (final line in lines) {
      if (line.length > longest) longest = line.length;
    }
    final width = entity.rectangleWidth > 0
        ? entity.rectangleWidth
        : longest * entity.height * 0.62;
    final totalHeight = entity.height * lines.length * 1.2;
    final delta =
        (_textAlignOffset(entity.hAlign, entity.vAlign, width, totalHeight) -
                _textAlignOffset(next.h, next.v, width, totalHeight))
            .rotated(entity.rotation);
    final h = switch (next.h) {
      TextHAlign.right => 2,
      TextHAlign.center || TextHAlign.middle || TextHAlign.fit => 1,
      _ => 0,
    };
    final v = switch (next.v) {
      TextVAlign.top => 0,
      TextVAlign.middle => 1,
      _ => 2,
    };
    return MTextEntity(
      id: entity.id,
      props: entity.props,
      position: entity.position + delta,
      content: entity.content,
      height: entity.height,
      rotation: entity.rotation,
      styleName: entity.styleName,
      rectangleWidth: entity.rectangleWidth,
      attachment: 1 + v * 3 + h,
    );
  }

  /// Left / Center / Right keep the current vertical; TL…BR set both axes.
  /// Align and Fit return null.
  static ({TextHAlign h, TextVAlign v})? parseTextJustify(
    String raw, {
    required TextHAlign currentH,
    required TextVAlign currentV,
  }) {
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (key.isEmpty) return null;
    return switch (key) {
      'l' || 'left' => (h: TextHAlign.left, v: currentV),
      'c' || 'center' || 'centre' => (h: TextHAlign.center, v: currentV),
      'r' || 'right' => (h: TextHAlign.right, v: currentV),
      'm' || 'middle' => (h: TextHAlign.center, v: TextVAlign.middle),
      'tl' || 'topleft' => (h: TextHAlign.left, v: TextVAlign.top),
      'tc' ||
      'topcenter' ||
      'topcentre' => (h: TextHAlign.center, v: TextVAlign.top),
      'tr' || 'topright' => (h: TextHAlign.right, v: TextVAlign.top),
      'ml' || 'middleleft' => (h: TextHAlign.left, v: TextVAlign.middle),
      'mc' ||
      'middlecenter' ||
      'middlecentre' => (h: TextHAlign.center, v: TextVAlign.middle),
      'mr' || 'middleright' => (h: TextHAlign.right, v: TextVAlign.middle),
      'bl' || 'bottomleft' => (h: TextHAlign.left, v: TextVAlign.bottom),
      'bc' ||
      'bottomcenter' ||
      'bottomcentre' => (h: TextHAlign.center, v: TextVAlign.bottom),
      'br' || 'bottomright' => (h: TextHAlign.right, v: TextVAlign.bottom),
      _ => null,
    };
  }

  static Vec2 _textAlignOffset(
    TextHAlign h,
    TextVAlign v,
    double width,
    double totalHeight,
  ) {
    final dx = switch (h) {
      TextHAlign.left || TextHAlign.aligned => 0.0,
      TextHAlign.center || TextHAlign.middle || TextHAlign.fit => -width / 2,
      TextHAlign.right => -width,
    };
    final dy = switch (v) {
      TextVAlign.baseline || TextVAlign.bottom => 0.0,
      TextVAlign.middle => -totalHeight / 2,
      TextVAlign.top => -totalHeight,
    };
    return Vec2(dx, dy);
  }
}

/// Deletes and stretches produced by [Construct.overkill].
class OverkillResult {
  const OverkillResult({this.erase = const [], this.replace = const []});

  final List<int> erase;
  final List<CadEntity> replace;

  bool get isEmpty => erase.isEmpty && replace.isEmpty;
}

class _CollinearAxis {
  const _CollinearAxis(this.dir, this.offset);

  final Vec2 dir;
  final double offset;

  String get key =>
      '${Construct._qty(dir.x)},${Construct._qty(dir.y)}|'
      '${Construct._qty(offset)}';

  double along(Vec2 point) => dir.dot(point);

  Vec2 at(double t) => dir * t + dir.perpendicular * offset;

  static _CollinearAxis? tryParse(Vec2 start, Vec2 end) {
    final delta = end - start;
    final length = delta.length;
    if (length < 1e-9) return null;
    var dir = delta / length;
    if (dir.x < -1e-9 || (dir.x.abs() <= 1e-9 && dir.y < 0)) {
      dir = -dir;
    }
    return _CollinearAxis(dir, dir.perpendicular.dot(start));
  }
}

class _OverlapSpan {
  _OverlapSpan(
    this.entity,
    this.order,
    this.axis,
    this.lo,
    this.hi,
    this.forward,
  );

  final CadEntity entity;
  final int order;
  final _CollinearAxis axis;
  final double lo;
  final double hi;
  final bool forward;

  Vec2 get entityStart => Construct._lineLikeEnds(entity)!.$1;
  Vec2 get entityEnd => Construct._lineLikeEnds(entity)!.$2;
}

class _PolyVert {
  _PolyVert(this.point, this.bulge);

  final Vec2 point;
  double bulge;
}

class _PolyHit {
  const _PolyHit(this.segment, this.t, this.point);

  final int segment;
  final double t;
  final Vec2 point;
}

/// A directed open chain used by [Construct.joinEntities].
class _JoinRun {
  const _JoinRun(this.points, this.bulges);

  final List<Vec2> points;
  final List<double> bulges;

  Vec2 get start => points.first;
  Vec2 get end => points.last;

  static _JoinRun? from(CadEntity entity) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        if (start.distanceSquaredTo(end) < 1e-20) return null;
        return _JoinRun([start, end], const [0, 0]);
      case PolylineEntity() when !entity.closed && entity.vertexCount >= 2:
        final count = entity.vertexCount;
        return _JoinRun(
          [for (var i = 0; i < count; i++) entity.vertexAt(i)],
          [
            for (var i = 0; i < count; i++)
              i < count - 1 ? entity.bulgeAt(i) : 0,
          ],
        );
      case ArcEntity(:final startPoint, :final endPoint, :final sweep):
        if (sweep < 1e-12 || sweep >= math.pi * 2 - 1e-9) return null;
        return _JoinRun([startPoint, endPoint], [math.tan(sweep / 4), 0]);
      default:
        return null;
    }
  }

  _JoinRun get reversed {
    final count = points.length;
    return _JoinRun(points.reversed.toList(), [
      for (var i = 0; i < count - 1; i++) -bulges[count - 2 - i],
      0,
    ]);
  }

  _JoinRun appended(_JoinRun other) => _JoinRun(
    [...points, ...other.points.skip(1)],
    [...bulges.take(points.length - 1), ...other.bulges],
  );
}

class FilletResult {
  const FilletResult({required this.first, required this.second, this.arc});

  final LineEntity first;
  final LineEntity second;
  final ArcEntity? arc;
}

/// The two trimmed lines and optional cut produced by [Construct.chamferLines].
class ChamferResult {
  const ChamferResult({required this.first, required this.second, this.cut});

  final LineEntity first;
  final LineEntity second;
  final LineEntity? cut;
}
