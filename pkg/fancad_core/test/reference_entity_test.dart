import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const context = EmitContext(tolerance: 0.1);

  test('a leader needs two vertices and can drop its arrow', () {
    final short = LeaderEntity(id: 1, vertices: Float64List.fromList([0, 0]));
    final sink = PolylineSink();
    short.emit(context, sink);
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
    leader.emit(context, withArrow);
    expect(withArrow.polylines, isNotEmpty);
    expect(withArrow.fills, hasLength(1));

    final bare = LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 10, 0]),
      hasArrowHead: false,
    );
    final noArrow = PolylineSink();
    bare.emit(context, noArrow);
    expect(noArrow.fills, isEmpty);
    expect(noArrow.polylines, hasLength(1));
  });

  test('a solid grip edits one corner and a short face is silent', () {
    const face = SolidEntity(
      id: 1,
      corners: [Vec2.zero(), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
    );
    expect((face.withGrip(2, const Vec2(5, 4))).corners[2], const Vec2(5, 4));
    expect(face.withGrip(9, const Vec2.zero()), face);
    expect(
      face.transformed(const Mat3.translation(1, 2)).corners.first,
      const Vec2(1, 2),
    );

    final sink = PolylineSink();
    const SolidEntity(id: 1, corners: [Vec2.zero(), Vec2(1, 0)]).emit(
      context,
      sink,
    );
    expect(sink.fills, isEmpty);
    face.emit(context, sink);
    expect(sink.fills, hasLength(1));
  });

  test('ray and xline grips move the origin without inventing a box', () {
    const ray = RayEntity(id: 1, origin: Vec2.zero(), direction: Vec2(1, 0));
    expect(ray.computeBounds(), const Bounds2(0, 0, 0, 0));
    expect((ray.withGrip(0, const Vec2(2, 3)) as RayEntity).origin, const Vec2(2, 3));
    expect(
      (ray.withGrip(1, const Vec2(0, 4)) as RayEntity).direction,
      const Vec2(0, 4),
    );
    final rotated = ray.transformed(Mat3.rotation(1.5707963267948966));
    expect(rotated.direction.x, closeTo(0, 1e-9));
    expect(rotated.direction.y, closeTo(1, 1e-9));

    const zero = RayEntity(id: 1, origin: Vec2.zero(), direction: Vec2.zero());
    final silent = PolylineSink();
    zero.emit(context, silent);
    expect(silent.polylines, isEmpty);

    const xline = XLineEntity(id: 1, origin: Vec2(3, 4), direction: Vec2(0, 1));
    expect(xline.grips(), const [Vec2(3, 4)]);
    expect(
      (xline.withGrip(0, const Vec2(1, 1)) as XLineEntity).origin,
      const Vec2(1, 1),
    );
    final bothWays = PolylineSink();
    xline.emit(context, bothWays);
    expect(bothWays.polylines.single.length, 4);
  });

  test('an image only the origin grip moves the placement', () {
    const image = ImageEntity(
      id: 1,
      reference: 'sheet.png',
      origin: Vec2.zero(),
      uVector: Vec2(10, 0),
      vVector: Vec2(0, 6),
    );
    expect(image.grips(), const [
      Vec2.zero(),
      Vec2(10, 0),
      Vec2(10, 6),
      Vec2(0, 6),
    ]);
    expect(
      (image.withGrip(0, const Vec2(2, 1)) as ImageEntity).origin,
      const Vec2(2, 1),
    );
    expect(image.withGrip(2, const Vec2(9, 9)), image);

    final moved = image.transformed(const Mat3.translation(5, 0));
    expect(moved.origin, const Vec2(5, 0));
    expect(moved.uVector, const Vec2(10, 0));

    final sink = PolylineSink();
    image.emit(context, sink);
    expect(sink.images.single.reference, 'sheet.png');
    expect(sink.images.single.origin, const Vec2.zero());
  });
}
