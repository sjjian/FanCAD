import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a diameter explodes to opposite spokes, not a single radius', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    final dim = Construct.diameterDimension(circle, const Vec2(8, 0))!;
    final pieces = Construct.explodeDimension(dim);

    final lines = pieces.whereType<LineEntity>().toList();
    expect(lines, hasLength(2));
    expect(lines[0].start, const Vec2.zero());
    expect(lines[0].end, const Vec2(8, 0));
    expect(lines[1].start, const Vec2.zero());
    expect(lines[1].end, const Vec2(-8, 0));
    expect(pieces.whereType<TextEntity>().single.content, 'Ø10.00');
  });

  test('a line or a collapsed chord cannot invent a diameter', () {
    expect(
      Construct.diameterDimension(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        const Vec2(5, 0),
      ),
      isNull,
    );

    const collapsed = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero(), Vec2.zero()],
      textPosition: Vec2.zero(),
      measurement: 10,
      overrideText: ' ',
      dimensionType: 3,
    );
    expect(Construct.explodeDimension(collapsed).whereType<LineEntity>(), isEmpty);
  });
}
