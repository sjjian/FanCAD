import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a point or insert cannot invent a reverse', () {
    expect(
      Construct.reverse(const PointEntity(id: 1, position: Vec2.zero())),
      isNull,
    );
    expect(
      Construct.reverse(
        const InsertEntity(id: 2, blockName: 'CELL', position: Vec2.zero()),
      ),
      isNull,
    );
  });
}
