import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an open or unsupported entity cannot invent an area or length', () {
    const point = PointEntity(id: 1, position: Vec2.zero());
    const text = TextEntity(id: 2, position: Vec2.zero(), content: 'A');
    const insert = InsertEntity(id: 3, blockName: 'CELL', position: Vec2.zero());

    expect(Construct.areaOf(point), 0);
    expect(Construct.areaOf(text), 0);
    expect(Construct.areaOf(insert), 0);
    expect(Construct.lengthOf(point), 0);
    expect(Construct.lengthOf(text), 0);
    expect(Construct.lengthOf(insert), 0);
  });
}
