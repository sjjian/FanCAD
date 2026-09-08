import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('parse falls back to unknown', () {
    expect(EntityKind.parse('line'), EntityKind.line);
    expect(EntityKind.parse('nope'), EntityKind.unknown);
  });

  eachCase(
    [
      (
        name: 'a vanished radius cannot invent an arc stroke',
        entity: const ArcEntity(
          id: 1,
          center: Vec2.zero(),
          radius: 0,
          startAngle: 0,
          endAngle: 1.5,
        ),
      ),
      (
        name: 'a vanished radius cannot invent a circle stroke',
        entity: const CircleEntity(id: 1, center: Vec2.zero(), radius: 0),
      ),
      (
        name: 'an empty polyline cannot invent a stroke',
        entity: PolylineEntity(id: 1, vertices: Float64List(0)),
      ),
      (
        name: 'a vanished direction cannot invent a ray',
        entity: const RayEntity(
          id: 1,
          origin: Vec2(3, 4),
          direction: Vec2.zero(),
        ),
      ),
      (
        name: 'an empty spline cannot invent a stroke',
        entity: SplineEntity(id: 1, controlPoints: Float64List(0)),
      ),
    ],
    (c) {
      expect(emit(c.entity).polylines, isEmpty);
    },
  );

  eachCase(
    [
      (
        name: 'an empty hatch cannot invent a fill',
        entity: const HatchEntity(id: 1, loops: []),
      ),
      (
        name: 'a lone vertex cannot invent a leader stroke',
        entity: LeaderEntity(id: 1, vertices: Float64List.fromList([0, 0])),
      ),
      (
        name: 'fewer than three corners cannot invent a solid fill',
        entity: const SolidEntity(id: 1, corners: [Vec2.zero(), Vec2(4, 0)]),
      ),
    ],
    (c) {
      final sink = emit(c.entity);
      expect(sink.fills, isEmpty);
      expect(sink.polylines, isEmpty);
    },
  );

  test('an out-of-range grip cannot invent a new control point', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(line.withGrip(-1, const Vec2(1, 1)), same(line));
    expect(line.withGrip(99, const Vec2(1, 1)), same(line));

    final unknown = UnknownEntity(id: 2, originalType: 'PROXY');
    expect(unknown.withGrip(0, const Vec2(4, 4)), same(unknown));
  });

  test('a point or unknown cannot invent an offset or a length', () {
    const point = PointEntity(id: 1, position: Vec2.zero());
    final unknown = UnknownEntity(id: 2, originalType: 'REGION');

    expect(point.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(unknown.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(point.reversed(), isNull);
    expect(unknown.reversed(), isNull);
    expect(point.pathLength, 0);
    expect(unknown.pathLength, 0);
    expect(point.signedArea, 0);
    expect(unknown.signedArea, 0);
  });

  test('missing or unknown JSON cannot invent drawable geometry', () {
    final unknown = CadEntity.fromJson(const {});
    expect(unknown, isA<UnknownEntity>());
    expect(unknown.computeBounds().isEmpty, isTrue);
    expect((unknown as UnknownEntity).originalType, 'UNKNOWN');

    expect(CadEntity.fromJson(const {'type': 'nope'}), isA<UnknownEntity>());

    final line = CadEntity.fromJson(const {'type': 'line'}) as LineEntity;
    expect(line.start, const Vec2.zero());
    expect(line.end, const Vec2.zero());
    expect(line.length, 0);

    final circle = CadEntity.fromJson(const {'type': 'circle'}) as CircleEntity;
    expect(circle.center, const Vec2.zero());
    expect(circle.radius, 0);

    final polyline =
        CadEntity.fromJson(const {'type': 'polyline'}) as PolylineEntity;
    expect(polyline.vertices, isEmpty);
  });
}

