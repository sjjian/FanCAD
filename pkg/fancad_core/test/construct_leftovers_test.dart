import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a radius dimension explodes to a spoke, not extension lines', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    final dim = Construct.radiusDimension(circle, const Vec2(8, 0))!;
    final pieces = Construct.explodeDimension(dim);

    final lines = pieces.whereType<LineEntity>().toList();
    expect(lines, isNotEmpty);
    expect(lines.first.start, const Vec2.zero());
    expect(lines.first.end, const Vec2(8, 0));
    expect(pieces.whereType<TextEntity>().single.content, 'R5.00');
    expect(pieces.whereType<LineEntity>(), hasLength(1));
  });

  test('a collapsed radial chord cannot invent a dim line', () {
    const dim = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero(), Vec2.zero()],
      textPosition: Vec2.zero(),
      measurement: 5,
      overrideText: ' ',
      dimensionType: 4,
    );
    final pieces = Construct.explodeDimension(dim);
    expect(pieces.whereType<LineEntity>(), isEmpty);
    expect(pieces.whereType<TextEntity>(), isEmpty);
  });
}
