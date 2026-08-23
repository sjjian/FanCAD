import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a huge arc with a tiny tolerance hits the segment ceiling', () {
    expect(
      Flatten.arcSegmentCount(1e6, math.pi * 2, 1e-6),
      Flatten.maxSegments,
    );
  });

  test('an underflowing sagitta ratio stays at the floor instead of NaN', () {
    expect(Flatten.arcSegmentCount(1e20, math.pi, 1e-20), Flatten.minSegments);
  });

  test(
    'a non-positive spline tolerance samples at the ceiling rather than infinitely',
    () {
      final samples = Flatten.bspline(
        controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]),
        knots: const [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0],
        degree: 3,
        tolerance: 0,
      );
      expect(samples.length, (Flatten.maxSegments + 1) * 2);
      expect(samples[0], closeTo(0, 1e-9));
      expect(samples[samples.length - 2], closeTo(4, 1e-6));
    },
  );
}
