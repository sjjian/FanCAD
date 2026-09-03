import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const context = EmitContext(tolerance: 0.1);

  test('an ellipse and a weighted spline emit flattened strokes', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(10, 0),
      ratio: 0.5,
    );
    final ellipseSink = PolylineSink();
    ellipse.emit(context, ellipseSink);
    expect(ellipseSink.polylines, isNotEmpty);
    expect(ellipseSink.closedFlags.first, isTrue);
    expect(ellipse.withId(9).id, 9);
    expect(
      ellipse.transformed(const Mat3.translation(2, 0)).center,
      const Vec2(2, 0),
    );

    final spline = SplineEntity(
      id: 2,
      controlPoints: Float64List.fromList([0, 0, 4, 4, 8, 0, 12, 4]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [1, 1, 1, 1],
      degree: 3,
    );
    final splineSink = PolylineSink();
    spline.emit(context, splineSink);
    expect(splineSink.polylines, isNotEmpty);
    expect(
      spline.transformed(const Mat3.translation(1, 0)).controlPoints[0],
      1,
    );
  });

  test('a wide or bulged polyline emits a fill and keeps a flipped bulge', () {
    final wide = PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 0, 10, 0, 0, 10, 4, 0]),
      constantWidth: 2,
    );
    final fillSink = PolylineSink();
    wide.emit(context, fillSink);
    expect(fillSink.fills, isNotEmpty);
    expect(wide.computeBounds().height, greaterThan(4));

    final bulged = PolylineEntity(
      id: 2,
      vertices: Float64List.fromList([0, 0, 0.5, 10, 0, 0]),
    );
    expect(bulged.hasBulges, isTrue);
    expect(bulged.computeBounds().width, greaterThan(0));
    final mirrored = bulged.transformed(
      Mat3.mirror(const Vec2.zero(), const Vec2(1, 0)),
    );
    expect(mirrored.bulgeAt(0), -0.5);
  });

  test('an insert array emits each cell and a clip miss stays silent', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
        blockName: 'CELL',
      );
    const insert = InsertEntity(
      id: 2,
      blockName: 'CELL',
      position: Vec2(10, 0),
      columnCount: 2,
      columnSpacing: 20,
    );
    final sink = PolylineSink();
    insert.emit(EmitContext(tolerance: 0.1, blocks: document), sink);
    expect(sink.polylines, hasLength(2));
    expect(insert.computeBounds(blocks: document).width, greaterThan(4));

    final clipped = PolylineSink();
    insert.emit(
      EmitContext(
        tolerance: 0.1,
        blocks: document,
        clip: const Bounds2(-2, -2, -1, -1),
      ),
      clipped,
    );
    expect(clipped.polylines, isEmpty);
  });
}
