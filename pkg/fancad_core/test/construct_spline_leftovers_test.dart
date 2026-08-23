import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('fewer than two points cannot invent a control spline', () {
    expect(Construct.splineFromControls(const []), isNull);
    expect(Construct.splineFromControls(const [Vec2.zero()]), isNull);
  });

  test('fewer than two points cannot invent a fit spline', () {
    expect(Construct.splineFromFit(const []), isNull);
    expect(Construct.splineFromFit(const [Vec2(1, 1)]), isNull);
  });
}
