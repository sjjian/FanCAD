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

  test('a leader without an arrow cannot invent a fill', () {
    final sink = PolylineSink();
    LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 4, 0]),
      hasArrowHead: false,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.fills, isEmpty);
  });

  test('a leader needs two vertices and can drop its arrow', () {
    final short = LeaderEntity(id: 1, vertices: Float64List.fromList([0, 0]));
    final sink = PolylineSink();
    short.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
    expect(short.withGrip(9, const Vec2(1, 1)), short);

    final leader = LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 10, 0, 10, 4]),
    );
    expect(leader.grips(), const [Vec2.zero(), Vec2(10, 0), Vec2(10, 4)]);
    final moved = leader.withGrip(1, const Vec2(8, 1));
    expect(moved.grips()[1], const Vec2(8, 1));

    final withArrow = PolylineSink();
    leader.emit(const EmitContext(tolerance: 0.1), withArrow);
    expect(withArrow.polylines, isNotEmpty);
    expect(withArrow.fills, hasLength(1));
  });
}
