import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
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
}
