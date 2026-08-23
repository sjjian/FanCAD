import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('fewer than two definition points cannot invent a measurement', () {
    expect(DimensionEntity.measuredLength(const [], 0), 0);
    expect(DimensionEntity.measuredLength(const [Vec2.zero()], 0), 0);
  });
}
