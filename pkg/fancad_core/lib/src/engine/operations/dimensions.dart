import 'dart:math' as math;
import 'dart:typed_data';

import '../../geometry/intersect.dart';
import '../../geometry/vector.dart';
import '../../model/entity/entity.dart';
import '../../model/entity/text_alignment.dart';
import '../../model/style.dart';

/// Dimension construction and regeneration.
///
/// Kept separate from the curve-editing operations so [Transaction] can
/// regenerate associated dimensions without depending on the whole operation
/// catalogue.
class DimensionOperations {
  const DimensionOperations._();

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
}
