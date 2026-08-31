import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a point or unknown cannot invent an offset or a length', () {
    const point = PointEntity(id: 1, position: Vec2.zero());
    final unknown = UnknownEntity(id: 2, originalType: 'REGION');

    expect(point.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(unknown.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(point.reversed(), isNull);
    expect(unknown.reversed(), isNull);
    expect(point.pathLength, 0);
    expect(unknown.pathLength, 0);
    expect(point.signedArea, 0);
    expect(unknown.signedArea, 0);
  });
}
