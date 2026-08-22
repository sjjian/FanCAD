import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const graphics = DimensionGraphics();
  const context = EmitContext(tolerance: 0.1);

  test('a short definition list only emits the measurement text', () {
    final sink = PolylineSink();
    graphics.emit(
      const DimensionEntity(id: 1, measurement: 4, overrideText: 'note'),
      context,
      sink,
    );
    expect(sink.polylines, isEmpty);
    expect(sink.fills, isEmpty);
    expect(sink.texts.single.text, 'note');
  });

  test('a blank override hides the text on every family', () {
    final sink = PolylineSink();
    graphics.emit(
      const DimensionEntity(
        id: 1,
        definitionPoints: [Vec2.zero(), Vec2(8, 0)],
        overrideText: ' ',
      ),
      context,
      sink,
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isNotEmpty);
  });

  test('radius and diameter share a chord but only diameter crosses the centre', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 10);
    final radius = Construct.radiusDimension(circle, const Vec2(10, 0))!;
    final diameter = Construct.diameterDimension(circle, const Vec2(10, 0))!;

    final radiusSink = PolylineSink();
    graphics.emit(radius, context, radiusSink);
    expect(radiusSink.texts.single.text, 'R10.00');
    expect(radiusSink.fills, hasLength(1));
    expect(
      radiusSink.polylines.any(_isSegment(const Vec2.zero(), const Vec2(10, 0))),
      isTrue,
    );
    expect(
      radiusSink.polylines.any(_isSegment(const Vec2.zero(), const Vec2(-10, 0))),
      isFalse,
    );

    final diameterSink = PolylineSink();
    graphics.emit(diameter, context, diameterSink);
    expect(diameterSink.texts.single.text, 'Ø20.00');
    expect(
      diameterSink.polylines.any(_isSegment(const Vec2.zero(), const Vec2(10, 0))),
      isTrue,
    );
    expect(
      diameterSink.polylines.any(_isSegment(const Vec2.zero(), const Vec2(-10, 0))),
      isTrue,
    );
  });

  test('an angular dimension draws two legs and a sector arc, not arrows', () {
    final dim = Construct.angularDimension(
      const Vec2.zero(),
      const Vec2(10, 0),
      const Vec2(0, 10),
      const Vec2(4, 4),
    )!;
    final sink = PolylineSink();
    graphics.emit(dim, context, sink);

    expect(sink.texts.single.text, '90.00°');
    expect(sink.fills, isEmpty);
    expect(
      sink.polylines.any(_isSegment(const Vec2.zero(), const Vec2(10, 0))),
      isTrue,
    );
    expect(
      sink.polylines.any(_isSegment(const Vec2.zero(), const Vec2(0, 10))),
      isTrue,
    );
    expect(
      sink.polylines.any((xy) => xy.length > 6),
      isTrue,
      reason: 'the labelled sector is a discretised arc, not a single chord',
    );
  });

  test('two-point angular falls back to a linear dimension line', () {
    const dim = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero(), Vec2(10, 0)],
      textPosition: Vec2(5, 3),
      measurement: 10,
      dimensionType: 2,
    );
    final sink = PolylineSink();
    graphics.emit(dim, context, sink);
    expect(sink.fills, hasLength(2));
    expect(
      sink.polylines.any(_isSegment(const Vec2(0, 3), const Vec2(10, 3))),
      isTrue,
    );
  });
}

bool Function(Float64List xy) _isSegment(Vec2 a, Vec2 b) {
  return (xy) {
    if (xy.length != 4) return false;
    final p = Vec2(xy[0], xy[1]);
    final q = Vec2(xy[2], xy[3]);
    return (p.distanceTo(a) < 1e-9 && q.distanceTo(b) < 1e-9) ||
        (p.distanceTo(b) < 1e-9 && q.distanceTo(a) < 1e-9);
  };
}
