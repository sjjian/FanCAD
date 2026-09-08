import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range leader grip cannot invent a vertex', () {
    final leader = LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 4, 0, 6, 2]),
    );
    expect(leader.withGrip(-1, const Vec2(1, 1)), same(leader));
    expect(leader.withGrip(99, const Vec2(1, 1)), same(leader));
  });
}
