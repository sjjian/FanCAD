import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range solid grip cannot invent a corner', () {
    const solid = SolidEntity(
      id: 1,
      corners: [Vec2.zero(), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
    );
    expect(solid.withGrip(-1, const Vec2(1, 1)), same(solid));
    expect(solid.withGrip(99, const Vec2(1, 1)), same(solid));
  });

  test('a solid grip edits one corner', () {
    const face = SolidEntity(
      id: 1,
      corners: [Vec2.zero(), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
    );
    expect((face.withGrip(2, const Vec2(5, 4))).corners[2], const Vec2(5, 4));
    expect(
      face.transformed(const Mat3.translation(1, 2)).corners.first,
      const Vec2(1, 2),
    );
    final sink = PolylineSink();
    face.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, hasLength(1));
  });
}
