import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('EntityKind', () {
    test('parse falls back to unknown', () {
      expect(EntityKind.parse('line'), EntityKind.line);
      expect(EntityKind.parse('nope'), EntityKind.unknown);
    });
  });

  group('grips and transforms', () {
    test('a line midpoint grip moves the whole segment', () {
      const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
      expect(line.grips(), const [Vec2.zero(), Vec2(5, 0), Vec2(10, 0)]);
      final moved = line.withGrip(1, const Vec2(5, 4)) as LineEntity;
      expect(moved.start, const Vec2(0, 4));
      expect(moved.end, const Vec2(10, 4));
      expect(line.withGrip(9, const Vec2(1, 1)), line);
      expect(line.withId(2).id, 2);
      expect(line.withProps(const EntityProps(layer: 'A')).props.layer, 'A');
    });

    test('circle quadrant grips change radius and a point grip moves', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      expect(circle.grips(), const [
        Vec2.zero(),
        Vec2(5, 0),
        Vec2(0, 5),
        Vec2(-5, 0),
        Vec2(0, -5),
      ]);
      final stretched = circle.withGrip(1, const Vec2(8, 0)) as CircleEntity;
      expect(stretched.center, const Vec2.zero());
      expect(stretched.radius, 8);
      final north = circle.withGrip(2, const Vec2(0, 3)) as CircleEntity;
      expect(north.radius, 3);
      final uniform = circle.transformed(const Mat3.scaling(2, 2)) as CircleEntity;
      expect(uniform.radius, 10);
      expect(uniform.center, const Vec2.zero());
      final tall = circle.transformed(const Mat3.scaling(1, 2)) as EllipseEntity;
      expect(tall.ratio, lessThanOrEqualTo(1));
      expect(tall.majorLength, closeTo(10, 1e-9));

      const point = PointEntity(id: 2, position: Vec2(1, 2));
      expect(point.grips(), const [Vec2(1, 2)]);
      expect(
        (point.withGrip(0, const Vec2(4, 5)) as PointEntity).position,
        const Vec2(4, 5),
      );
    });

    test('circle, text and insert grips stay on their anchors', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      expect(
        (circle.withGrip(0, const Vec2(1, 1)) as CircleEntity).center,
        const Vec2(1, 1),
      );
      const text = TextEntity(id: 1, position: Vec2.zero(), content: 'A');
      expect(
        (text.withGrip(0, const Vec2(2, 3)) as TextEntity).position,
        const Vec2(2, 3),
      );
      const insert = InsertEntity(id: 1, blockName: 'B', position: Vec2.zero());
      expect(
        (insert.withGrip(0, const Vec2(4, 5)) as InsertEntity).position,
        const Vec2(4, 5),
      );
    });

    test('a polyline vertex grip edits one point', () {
      final pline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 4)],
      );
      final edited = pline.withGrip(1, const Vec2(8, 1));
      expect(edited.vertexAt(1), const Vec2(8, 1));
      expect(edited.vertexAt(0), const Vec2.zero());
    });

    test('a dimension override substitutes the measured value', () {
      const dim = DimensionEntity(
        id: 1,
        definitionPoints: [Vec2.zero(), Vec2(10, 0)],
        measurement: 10,
        overrideText: 'L=<>',
      );
      expect(dim.displayText, 'L=10.00');
      expect(dim.formatMeasurement(0), 'L=10');
      expect(dim.formatMeasurement(20), 'L=10.00000000');
      final dragged = dim.withGrip(2, const Vec2(5, 4));
      expect(dragged.textPosition, const Vec2(5, 4));
    });

    test('scaling an angular dimension does not scale the degrees', () {
      final dim = Construct.angularDimension(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(0, 10),
        const Vec2(4, 4),
      )!;
      expect(dim.measurement, closeTo(90, 1e-9));
      final scaled = dim.transformed(const Mat3.scaling(2, 2));
      expect(scaled.measurement, closeTo(90, 1e-9));
      final gripped = dim.withGrip(2, const Vec2(-10, 0));
      expect(gripped.measurement, closeTo(180, 1e-9));
    });
  });

  group('emit', () {
    test('empty text is silent and a point marks a node', () {
      final sink = PolylineSink();
      const TextEntity(id: 1, position: Vec2.zero(), content: '').emit(
        const EmitContext(tolerance: 0.1),
        sink,
      );
      expect(sink.texts, isEmpty);
      const PointEntity(id: 1, position: Vec2(1, 2)).emit(
        const EmitContext(tolerance: 0.1),
        sink,
      );
      expect(sink.points, isNotEmpty);
    });

    test('an insert emits its block members once per cell', () {
      final document = CadDocument();
      document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(2, 0)),
        blockName: 'CELL',
      );
      final insert = InsertEntity(
        id: 0,
        blockName: 'CELL',
        position: const Vec2(10, 0),
        columnCount: 2,
        columnSpacing: 5,
      );
      final sink = PolylineSink();
      insert.emit(document.emitContext(tolerance: 0.1), sink);
      expect(sink.polylines.length, 2);
    });

    test('unknown entities occupy their proxy box and emit nothing', () {
      final unknown = UnknownEntity(
        id: 1,
        originalType: 'PROXY',
        proxyBounds: const Bounds2(0, 0, 4, 2),
      );
      expect(unknown.computeBounds(), const Bounds2(0, 0, 4, 2));
      expect(unknown.grips(), isEmpty);
      final sink = PolylineSink();
      unknown.emit(const EmitContext(tolerance: 0.1), sink);
      expect(sink.polylines, isEmpty);
    });
  });

  group('SnapMarker', () {
    test('every kind has a label', () {
      for (final kind in SnapMarkerKind.values) {
        expect(SnapMarker(kind: kind, point: const Vec2.zero()).label, isNotEmpty);
      }
    });
  });
}
