import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range dimension grip cannot invent a definition point', () {
    const dim = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero(), Vec2(4, 0)],
      textPosition: Vec2(2, 2),
      measurement: 4,
    );
    expect(dim.withGrip(-1, const Vec2(1, 1)), same(dim));
    expect(dim.withGrip(99, const Vec2(1, 1)), same(dim));
  });

  test('fewer than two definition points cannot invent a measurement', () {
    expect(DimensionEntity.measuredLength(const [], 0), 0);
    expect(DimensionEntity.measuredLength(const [Vec2.zero()], 0), 0);
  });

  test('a *D block of strokes still shows the measurement', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      blockName: r'*D$1',
    );
    document.addEntity(
      const DimensionEntity(
        id: 2,
        blockName: r'*D$1',
        textPosition: Vec2(5, 2),
        measurement: 10,
        overrideText: '25',
      ),
    );

    final sink = PolylineSink();
    document.entities.last.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.texts.single.text, '25');
    expect(sink.texts.single.origin, const Vec2(5, 2));
  });

  test('a *D block that already drew MTEXT cannot invent a second label', () {
    final document = CadDocument();
    document.addEntity(
      const MTextEntity(id: 1, position: Vec2(5, 2), content: '40', height: 35),
      blockName: r'*D$1',
    );
    document.addEntity(
      const DimensionEntity(
        id: 2,
        blockName: r'*D$1',
        textPosition: Vec2(5, 2),
        measurement: 10,
        overrideText: '25',
      ),
    );

    final sink = PolylineSink();
    document.entities.last.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.texts, hasLength(1));
    expect(sink.texts.single.text, '40');
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
}
