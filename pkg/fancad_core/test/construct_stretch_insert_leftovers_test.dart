import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a window miss cannot invent an insert stretch', () {
    const insert = InsertEntity(
      id: 1,
      blockName: 'CELL',
      position: Vec2.zero(),
    );
    expect(
      Construct.stretch(
        insert,
        const Bounds2(20, 20, 21, 21),
        const Vec2(4, 0),
      ),
      isNull,
    );
  });
}
