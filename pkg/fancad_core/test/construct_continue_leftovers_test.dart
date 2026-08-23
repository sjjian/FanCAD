import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a coincident origin or empty stack cannot invent a continue dim', () {
    final first = Construct.linearDimension(
      const Vec2.zero(),
      const Vec2(10, 0),
      const Vec2(5, 4),
    )!;
    expect(Construct.continueDimension(first, const Vec2(10, 0)), isNull);

    const empty = DimensionEntity(
      id: 1,
      definitionPoints: [],
      textPosition: Vec2.zero(),
      measurement: 0,
    );
    expect(Construct.continueDimension(empty, const Vec2(10, 0)), isNull);

    const radial = DimensionEntity(
      id: 2,
      definitionPoints: [Vec2.zero(), Vec2(8, 0)],
      textPosition: Vec2(8, 0),
      measurement: 8,
      dimensionType: 4,
    );
    expect(Construct.continueDimension(radial, const Vec2(12, 0)), isNull);
  });

  test('a zero spacing or coincident origin cannot invent a baseline dim', () {
    final first = Construct.linearDimension(
      const Vec2.zero(),
      const Vec2(10, 0),
      const Vec2(5, 4),
    )!;
    expect(
      Construct.baselineDimension(first, const Vec2(18, 0), spacing: 0),
      isNull,
    );
    expect(
      Construct.baselineDimension(first, const Vec2.zero(), spacing: 8),
      isNull,
    );

    const empty = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero()],
      textPosition: Vec2.zero(),
      measurement: 0,
    );
    expect(
      Construct.baselineDimension(empty, const Vec2(10, 0), spacing: 8),
      isNull,
    );
  });
}
