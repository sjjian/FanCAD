part of 'entity.dart';

/// A straight segment between two points.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class LineEntity extends CadEntity {
  const LineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.start,
    required this.end,
  });

  static LineEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => LineEntity(
    id: id,
    props: props,
    start: _point(json['start']),
    end: _point(json['end']),
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 start;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 end;

  double get length => start.distanceTo(end);
  double get angle => (end - start).angle;
  Vec2 get midpoint => start.lerp(end, 0.5);

  @override
  EntityKind get kind => EntityKind.line;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final a = context.apply(start);
    final b = context.apply(end);
    sink.polyline(
      Float64List.fromList([a.x, a.y, b.x, b.y]),
      context.styleFor(props),
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2.fromCorners(start, end);

  @override
  LineEntity withId(int id) =>
      LineEntity(id: id, props: props, start: start, end: end);

  @override
  LineEntity withProps(EntityProps props) =>
      LineEntity(id: id, props: props, start: start, end: end);

  @override
  LineEntity transformed(Mat3 matrix) => LineEntity(
    id: id,
    props: props,
    start: matrix.transform(start),
    end: matrix.transform(end),
  );

  @override
  List<Vec2> grips() => [start, midpoint, end];

  @override
  CadEntity withGrip(int index, Vec2 target) => switch (index) {
    0 => LineEntity(id: id, props: props, start: target, end: end),
    1 => transformed(
      Mat3.translation(target.x - midpoint.x, target.y - midpoint.y),
    ),
    2 => LineEntity(id: id, props: props, start: start, end: target),
    _ => this,
  };

  @override
  CadEntity? offsetBy(double distance, Vec2 towards) {
    final direction = (end - start).normalized();
    if (direction.length == 0) return null;
    final normal = direction.perpendicular;
    // Which side is the pick on? The sign of the projection decides.
    final sign = normal.dot(towards - start) >= 0 ? 1.0 : -1.0;
    final shift = normal * (distance * sign);
    return LineEntity(
      id: 0,
      props: props,
      start: start + shift,
      end: end + shift,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    final moveStart = _inStretchWindow(window, start);
    final moveEnd = _inStretchWindow(window, end);
    if (!moveStart && !moveEnd) return null;
    if (moveStart && moveEnd) {
      return transformed(Mat3.translation(delta.x, delta.y));
    }
    return LineEntity(
      id: id,
      props: props,
      start: moveStart ? start + delta : start,
      end: moveEnd ? end + delta : end,
    );
  }

  @override
  CadEntity? reversed() {
    if (start == end) return null;
    return LineEntity(id: id, props: props, start: end, end: start);
  }

  @override
  double get pathLength => length;

  @override
  Map<String, Object?> geometryToJson() => _$LineEntityToJson(this);
}
