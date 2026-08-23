import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a zero bulge or collapsed chord cannot invent an arc', () {
    expect(
      Flatten.bulgeArc(const Vec2.zero(), const Vec2(10, 0), 0),
      isNull,
    );
    expect(
      Flatten.bulgeArc(const Vec2.zero(), const Vec2.zero(), 1),
      isNull,
    );
  });
}
