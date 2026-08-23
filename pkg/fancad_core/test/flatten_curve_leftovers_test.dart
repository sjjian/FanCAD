import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed curve stays at its centre instead of inventing a ring', () {
    final arc = Flatten.arc(
      center: const Vec2(3, 4),
      radius: 0,
      startAngle: 0,
      endAngle: 1,
      tolerance: 0.1,
    );
    expect(arc.length, greaterThanOrEqualTo(2));
    expect(arc[0], closeTo(3, 1e-12));
    expect(arc[1], closeTo(4, 1e-12));
    for (var i = 0; i < arc.length; i += 2) {
      expect(arc[i], closeTo(3, 1e-12));
      expect(arc[i + 1], closeTo(4, 1e-12));
    }

    final ring = Flatten.circle(
      center: const Vec2(3, 4),
      radius: 0,
      tolerance: 0.1,
    );
    expect(ring, Float64List.fromList([3, 4]));

    final oval = Flatten.ellipse(
      center: const Vec2(3, 4),
      major: const Vec2.zero(),
      ratio: 1,
      startParam: 0,
      endParam: 1,
      tolerance: 0.1,
    );
    for (var i = 0; i < oval.length; i += 2) {
      expect(oval[i], closeTo(3, 1e-12));
      expect(oval[i + 1], closeTo(4, 1e-12));
    }
  });
}
