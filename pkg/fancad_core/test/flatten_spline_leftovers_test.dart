import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty or inverted knot vector cannot invent a spline', () {
    expect(
      Flatten.bspline(
        controlPoints: Float64List(0),
        knots: const [],
        degree: 3,
        tolerance: 0.1,
      ),
      isEmpty,
    );

    final controls = Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]);
    expect(
      Flatten.bspline(
        controlPoints: controls,
        knots: const [0, 0, 0, 0, 0, 0, 0, 0],
        degree: 3,
        tolerance: 0.1,
      ),
      controls,
    );
    expect(
      Flatten.bsplineBasis(
        knots: const [0, 0, 0, 0, 0, 0, 0, 0],
        count: 4,
        degree: 3,
        t: 0,
      ),
      [0.0, 0.0, 0.0, 0.0],
    );
    expect(
      Flatten.bsplineBasis(
        knots: const [0, 1],
        count: 4,
        degree: 3,
        t: 0,
      ),
      [0.0, 0.0, 0.0, 0.0],
    );
  });
}
