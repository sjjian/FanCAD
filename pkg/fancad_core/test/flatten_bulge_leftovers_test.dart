import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a non-finite bulge cannot invent an arc', () {
    const start = Vec2.zero();
    const end = Vec2(10, 0);
    expect(Flatten.bulgeArc(start, end, double.nan), isNull);
    expect(Flatten.bulgeArc(start, end, double.infinity), isNull);
    expect(Flatten.bulgeArc(start, end, double.negativeInfinity), isNull);
  });
}
