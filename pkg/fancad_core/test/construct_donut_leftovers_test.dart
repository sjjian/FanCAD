import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('vanished radii cannot invent a donut', () {
    expect(
      Construct.donut(
        center: const Vec2.zero(),
        innerRadius: 0,
        outerRadius: 0,
      ),
      isNull,
    );
    expect(
      Construct.donut(
        center: const Vec2.zero(),
        innerRadius: 1e-15,
        outerRadius: -1e-15,
      ),
      isNull,
    );
  });
}
