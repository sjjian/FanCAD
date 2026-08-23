import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty or collapsed geometry cannot invent an overkill erase', () {
    expect(Construct.overkill(const []).isEmpty, isTrue);
    expect(Construct.overkillIds(const []), isEmpty);

    const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(Construct.overkill([collapsed]).isEmpty, isTrue);

    const point = PointEntity(id: 2, position: Vec2.zero());
    expect(Construct.overkill([point]).isEmpty, isTrue);
  });
}
