import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an open polyline cannot invent an enclosed area', () {
    final open = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
    );
    expect(Construct.areaOf(open), 0);
    expect(Construct.lengthOf(open), closeTo(20, 1e-9));
  });
}
