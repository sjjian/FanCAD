import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an angular dimension explodes to two rays and a dim arc', () {
    final dim = Construct.angularDimension(
      const Vec2(0, 0),
      const Vec2(10, 0),
      const Vec2(0, 10),
      const Vec2(4, 4),
    )!;
    final pieces = Construct.explodeDimension(dim);

    expect(pieces.whereType<LineEntity>(), hasLength(2));
    expect(
      pieces.whereType<ArcEntity>().single.radius,
      closeTo(math.sqrt(32), 1e-9),
    );
    expect(pieces.whereType<TextEntity>().single.content, '90.00°');
  });

  test('a dim-arc pick on the vertex cannot invent an arc', () {
    const dim = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(0, 10)],
      textPosition: Vec2.zero(),
      measurement: 90,
      overrideText: ' ',
      dimensionType: 2,
    );
    final pieces = Construct.explodeDimension(dim);
    expect(pieces.whereType<ArcEntity>(), isEmpty);
    expect(pieces.whereType<LineEntity>(), hasLength(2));
    expect(pieces.whereType<TextEntity>(), isEmpty);
  });
}
