import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty or inverted knot vector cannot invent a sample', () {
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: Float64List(0),
        knots: const [],
        degree: 3,
        t: 0,
      ),
      isNull,
    );
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]),
        knots: const [0, 0, 0, 0, 0, 0, 0, 0],
        degree: 3,
        t: 0.5,
      ),
      isNull,
    );
  });
}
