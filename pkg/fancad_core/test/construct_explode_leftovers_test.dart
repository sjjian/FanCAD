import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty definition points cannot invent exploded pieces', () {
    const dim = DimensionEntity(
      id: 1,
      definitionPoints: [],
      textPosition: Vec2.zero(),
      measurement: 5,
      overrideText: ' ',
    );
    expect(Construct.explodeDimension(dim), isEmpty);
  });
}
