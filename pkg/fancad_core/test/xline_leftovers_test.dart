import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished direction cannot invent an xline', () {
    const xline = XLineEntity(
      id: 1,
      origin: Vec2(3, 4),
      direction: Vec2.zero(),
    );
    final sink = PolylineSink();
    xline.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
    expect(xline.computeBounds(), const Bounds2(3, 4, 3, 4));
  });

  test('an xline keeps a degenerate extents box and a long index box', () {
    const xline = XLineEntity(
      id: 1,
      origin: Vec2(3, 4),
      direction: Vec2(0, 1),
    );
    expect(xline.computeBounds(), const Bounds2(3, 4, 3, 4));
    expect(xline.indexBounds().minY, lessThan(-1e6));
    expect(xline.indexBounds().maxY, greaterThan(1e6));
  });
}
