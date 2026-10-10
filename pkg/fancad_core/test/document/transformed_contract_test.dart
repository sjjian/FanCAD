import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

/// `entity.transformed(m)` must draw what drawing [entity] through `m` draws.
///
/// Importers bake OCS with `transformed(Mat3.ocs(n))` and MIRROR / ROTATE /
/// SCALE commit through it, so a type that gets a mirror wrong here is wrong
/// in every one of those places at once.
void main() {
  final matrices = <String, Mat3>{
    'translation': const Mat3.translation(7, -4),
    'rotation': Mat3.rotationAbout(0.7, const Vec2(3, -2)),
    'uniform scale': Mat3.scalingAbout(2.5, 2.5, const Vec2(1, 1)),
    'mirror': Mat3.mirror(const Vec2(1, 2), const Vec2(1, 0.6)),
    'mirror across x': const Mat3.scaling(1, -1),
    '-Z OCS': Mat3.ocs(const Vec3(0, 0, -1)),
    'tilted OCS': Mat3.ocs(const Vec3(0.3, -0.2, -0.9)),
    'rotate, mirror and scale': Mat3.rotationAbout(-1.1, const Vec2(-2, 5))
        .multiplied(Mat3.mirror(Vec2.zero(), const Vec2(0.2, 1)))
        .multiplied(Mat3.scalingAbout(1.7, 1.7, const Vec2(4, 4))),
  };

  final document = CadDocument();
  document.putBlock(const BlockRecord(name: 'CELL', entityIds: []));
  document
    ..addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 1)),
      blockName: 'CELL',
    )
    ..addEntity(
      const ArcEntity(
        id: 0,
        center: Vec2(2, 2),
        radius: 1.5,
        startAngle: 0.2,
        endAngle: 2.6,
      ),
      blockName: 'CELL',
    )
    ..addEntity(
      const TextEntity(
        id: 0,
        position: Vec2(1, -1),
        content: 'A',
        rotation: 0.4,
      ),
      blockName: 'CELL',
    );

  final entities = <String, CadEntity>{
    'line': const LineEntity(id: 1, start: Vec2(1, 2), end: Vec2(8, -3)),
    'arc': const ArcEntity(
      id: 1,
      center: Vec2(3, 4),
      radius: 5,
      startAngle: 0.3,
      endAngle: 2.1,
    ),
    'arc through zero': const ArcEntity(
      id: 1,
      center: Vec2(-2, 1),
      radius: 3,
      startAngle: 5.5,
      endAngle: 0.8,
    ),
    'circle': const CircleEntity(id: 1, center: Vec2(2, -1), radius: 4),
    'ellipse': const EllipseEntity(
      id: 1,
      center: Vec2(1, 1),
      majorAxis: Vec2(5, 2),
      ratio: 0.4,
    ),
    'elliptical arc': const EllipseEntity(
      id: 1,
      center: Vec2(1, 1),
      majorAxis: Vec2(5, 2),
      ratio: 0.4,
      startParam: 0.5,
      endParam: 4,
    ),
    'bulged polyline': PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 0.5, 6, 0, 0, 6, 4, -0.8, 0, 4, 0]),
      closed: true,
    ),
    // Straight segments: the inner miter of a wide arc depends on how finely
    // the arc was cut, which is not what this test is about.
    'wide polyline': PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 0, 5, 1, 0, 9, -2, 0]),
      constantWidth: 0.4,
    ),
    'leader': LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 4, 3, 9, 3]),
    ),
    'mleader': MLeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 4, 3, 9, 3]),
      content: 'tag',
      textPosition: const Vec2(9.5, 3),
      textRotation: 0.3,
    ),
    'spline': SplineEntity(
      id: 1,
      controlPoints: Float64List.fromList([0, 0, 2, 5, 5, -1, 8, 4, 10, 0]),
      knots: const [0, 0, 0, 0, 1, 2, 2, 2, 2],
    ),
    'solid hatch': HatchEntity(
      id: 1,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 8, 0, 8, 6, 0, 6])),
        HatchLoop(
          vertices: Float64List.fromList([2, 2, 4, 2, 4, 4, 2, 4]),
          isOuter: false,
        ),
      ],
    ),
    'pattern hatch': HatchEntity(
      id: 1,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 8, 0, 8, 6, 0, 6])),
      ],
      patternName: 'USER',
      solid: false,
      patternLines: const [
        HatchPatternLine(angle: 0.5, originX: 1, deltaX: 0.7, deltaY: 1.3),
        HatchPatternLine(
          angle: -0.9,
          deltaX: 0.4,
          deltaY: 1.1,
          dashes: [1.2, -0.5],
        ),
      ],
    ),
    'solid': const SolidEntity(
      id: 1,
      corners: [Vec2(0, 0), Vec2(5, 0), Vec2(0, 3), Vec2(5, 4)],
    ),
    'point': const PointEntity(id: 1, position: Vec2(3, -7)),
    'text': const TextEntity(
      id: 1,
      position: Vec2(2, 3),
      content: 'FanCAD',
      height: 2,
      rotation: 0.5,
    ),
    'attdef': const AttdefEntity(
      id: 1,
      position: Vec2(-1, 4),
      tag: 'NO',
      defaultValue: 'A-01',
      rotation: 1.2,
    ),
    'attrib': const AttribEntity(
      id: 1,
      position: Vec2(5, 5),
      tag: 'NO',
      value: 'A-02',
      rotation: -0.6,
    ),
    'mtext': const MTextEntity(
      id: 1,
      position: Vec2(4, -2),
      content: 'note',
      height: 3,
      rotation: 0.9,
    ),
    'insert': const InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2(10, 5),
      scale: Vec2(1.5, 1.5),
      rotation: 0.6,
    ),
    'mirrored insert': const InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2(-3, 2),
      scale: Vec2(-1, 1),
      rotation: 0.3,
    ),
    'non-uniform insert': const InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2(2, 2),
      scale: Vec2(2, 0.5),
      rotation: -0.4,
    ),
    'insert array': const InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2(1, 1),
      rotation: 0.25,
      columnCount: 3,
      rowCount: 2,
      columnSpacing: 7,
      rowSpacing: -6,
    ),
  };

  for (final MapEntry(key: entityName, value: entity) in entities.entries) {
    group(entityName, () {
      for (final MapEntry(key: matrixName, value: matrix) in matrices.entries) {
        if (_noCommonAnswer(entityName, matrixName)) continue;
        test(matrixName, () {
          final baked = _draw(entity.transformed(matrix), document);
          final drawn = _draw(entity, document, matrix);
          _expectSameDrawing(baked, drawn);
        });
      }
    });
  }

  group('text baseline follows the matrix', () {
    for (final MapEntry(key: matrixName, value: matrix) in matrices.entries) {
      test(matrixName, () {
        for (final entity in entities.values) {
          final before = _baseline(entity);
          if (before == null) continue;
          final after = _baseline(entity.transformed(matrix))!;
          final expected = matrix.transformDirection(
            Vec2.polar(before.angle, 1),
          );
          expect(
            (after.origin - matrix.transform(before.origin)).length,
            lessThan(1e-9),
            reason: '${entity.kind} origin',
          );
          expect(
            _angleGap(after.angle, expected.angle),
            lessThan(1e-9),
            reason: '${entity.kind} baseline',
          );
        }
      });
    }
  });

  test('a MOVE keeps the stored angles as they were', () {
    const text = TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'x',
      rotation: 5,
    );
    const insert = InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2.zero(),
      scale: Vec2(-1, 1),
      rotation: 5,
    );
    const move = Mat3.translation(3, 4);
    expect(text.transformed(move).rotation, 5);
    expect(insert.transformed(move).rotation, 5);
    expect(insert.transformed(move).scale, const Vec2(-1, 1));
  });

  test('a mirrored INSERT turns as little as it can', () {
    const insert = InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2(2, 0),
      rotation: 0.3,
    );
    final acrossY = insert.transformed(const Mat3.scaling(-1, 1));
    expect(acrossY.position, const Vec2(-2, 0));
    expect(acrossY.scale.x, closeTo(-1, 1e-12));
    expect(acrossY.scale.y, closeTo(1, 1e-12));
    expect(acrossY.rotation, closeTo(-0.3, 1e-12));

    final acrossX = insert.transformed(const Mat3.scaling(1, -1));
    expect(acrossX.scale.x, closeTo(1, 1e-12));
    expect(acrossX.scale.y, closeTo(-1, 1e-12));
    expect(acrossX.rotation, closeTo(-0.3, 1e-12));
  });
}

({Vec2 origin, double angle})? _baseline(CadEntity entity) => switch (entity) {
  TextEntity(:final position, :final rotation) ||
  AttdefEntity(:final position, :final rotation) ||
  AttribEntity(:final position, :final rotation) ||
  MTextEntity(
    :final position,
    :final rotation,
  ) => (origin: position, angle: rotation),
  MLeaderEntity(:final textPosition, :final textRotation) => (
    origin: textPosition,
    angle: textRotation,
  ),
  _ => null,
};

/// Pairs where the transformed entity is right and drawing through the
/// matrix is not something the type can or should reproduce.
bool _noCommonAnswer(String entity, String matrix) {
  const scaling = {'uniform scale', 'rotate, mirror and scale'};
  const mirroring = {
    'mirror',
    'mirror across x',
    '-Z OCS',
    'tilted OCS',
    'rotate, mirror and scale',
  };
  return switch (entity) {
    // A non-uniform insert under a skew rotation, or any insert on a tilted
    // plane, shears; an INSERT cannot carry shear.
    'non-uniform insert' => !{
      'translation',
      'uniform scale',
      'mirror across x',
      '-Z OCS',
    }.contains(matrix),
    'insert' || 'mirrored insert' || 'insert array' => matrix == 'tilted OCS',
    // A bulge is a circular arc; a tilted plane projects it to an
    // elliptical one, which a bulge cannot hold.
    'bulged polyline' => matrix == 'tilted OCS',
    // A tilted plane spaces a line family differently from its dashes; a
    // pattern line has one scale for both.
    'pattern hatch' => matrix == 'tilted OCS',
    // Arrowheads keep their drawing size under SCALE, as with DIMSCALE.
    'leader' => scaling.contains(matrix),
    // The note is laid out again on the new baseline; FanCAD has no
    // mirrored glyphs, so its body does not flip with the leader.
    'mleader' => scaling.contains(matrix) || mirroring.contains(matrix),
    _ => false,
  };
}

PolylineSink _draw(
  CadEntity entity,
  CadDocument blocks, [
  Mat3 transform = const Mat3.identity(),
]) {
  final sink = PolylineSink();
  entity.emit(
    EmitContext(tolerance: 1e-3, transform: transform, blocks: blocks),
    sink,
  );
  return sink;
}

void _expectSameDrawing(PolylineSink baked, PolylineSink drawn) {
  expect(baked.polylines.length, drawn.polylines.length, reason: 'polylines');
  expect(baked.points.length, drawn.points.length, reason: 'points');
  expect(baked.texts.length, drawn.texts.length, reason: 'texts');

  final deviation = _hausdorff(
    baked.polylines,
    baked.closedFlags,
    drawn.polylines,
    drawn.closedFlags,
  );
  expect(deviation, lessThan(0.02), reason: 'polyline deviation');

  for (var i = 0; i < baked.points.length; i++) {
    expect(
      (baked.points[i] - drawn.points[i]).length,
      lessThan(1e-9),
      reason: 'point $i',
    );
  }

  for (var i = 0; i < baked.texts.length; i++) {
    final a = baked.texts[i];
    final b = drawn.texts[i];
    expect((a.origin - b.origin).length, lessThan(1e-9), reason: 'origin');
    expect(a.height, closeTo(b.height, 1e-9), reason: 'height');
    expect(_angleGap(a.rotation, b.rotation), lessThan(1e-9), reason: 'angle');
  }
}

double _angleGap(double a, double b) {
  final d = (a - b) % (2 * math.pi);
  return math.min(d, 2 * math.pi - d);
}

/// Symmetric Hausdorff distance between two sets of polylines, measured
/// from each vertex of one set to the nearest segment of the other.
double _hausdorff(
  List<Float64List> a,
  List<bool> aClosed,
  List<Float64List> b,
  List<bool> bClosed,
) => math.max(_directed(a, b, bClosed), _directed(b, a, aClosed));

double _directed(
  List<Float64List> from,
  List<Float64List> to,
  List<bool> toClosed,
) {
  var worst = 0.0;
  for (final line in from) {
    for (var i = 0; i < line.length; i += 2) {
      final p = Vec2(line[i], line[i + 1]);
      var best = double.infinity;
      for (var k = 0; k < to.length; k++) {
        best = math.min(best, _toPolyline(p, to[k], toClosed[k]));
      }
      worst = math.max(worst, best);
    }
  }
  return worst;
}

double _toPolyline(Vec2 p, Float64List xy, bool closed) {
  final n = xy.length ~/ 2;
  if (n == 1) return (p - Vec2(xy[0], xy[1])).length;
  var best = double.infinity;
  final segments = closed ? n : n - 1;
  for (var i = 0; i < segments; i++) {
    final j = (i + 1) % n;
    best = math.min(
      best,
      _toSegment(
        p,
        Vec2(xy[i * 2], xy[i * 2 + 1]),
        Vec2(xy[j * 2], xy[j * 2 + 1]),
      ),
    );
  }
  return best;
}

double _toSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final len2 = ab.lengthSquared;
  if (len2 < 1e-24) return (p - a).length;
  final t = ((p - a).dot(ab) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).length;
}
