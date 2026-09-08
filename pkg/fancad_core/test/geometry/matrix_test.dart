import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed second pair cannot invent an align rotation', () {
    final matrix = Mat3.align(
      const Vec2.zero(),
      const Vec2(4, 2),
      source2: const Vec2.zero(),
      dest2: const Vec2(10, 0),
    );
    expect(matrix.transform(const Vec2.zero()), const Vec2(4, 2));
    expect(matrix.transform(const Vec2(1, 0)), const Vec2(5, 2));

    final destCollapsed = Mat3.align(
      const Vec2.zero(),
      const Vec2(4, 2),
      source2: const Vec2(10, 0),
      dest2: const Vec2(4, 2),
    );
    expect(destCollapsed.transform(const Vec2.zero()), const Vec2(4, 2));
  });

  test('a singular or non-finite matrix cannot invent an inverse', () {
    expect(const Mat3.scaling(0, 1).inverted(), isNull);
    expect(const Mat3(double.nan, 0, 0, 1, 0, 0).inverted(), isNull);
    expect(const Mat3.identity().isIdentity, isTrue);
    expect(const Mat3.translation(1, 0).isIdentity, isFalse);
  });

  test('OCS (0,0,1) is the identity and (0,0,-1) flips X', () {
    expect(Mat3.ocs(const Vec3(0, 0, 1)).isIdentity, isTrue);
    expect(Mat3.ocs(const Vec3(0, 0, 0)).isIdentity, isTrue);
    final flipped = Mat3.ocs(const Vec3(0, 0, -1));
    expect(
      flipped.transform(const Vec2(513651.937, 170415.059)),
      const Vec2(-513651.937, 170415.059),
    );
    expect(
      flipped.transform(const Vec2(-513651.937, 170415.059)).x,
      closeTo(513651.937, 1e-9),
    );
  });

  test('OCS tilted extrusion uses the arbitrary axis', () {
    // N = (1,0,0): Ax = Wz × N = (0,1,0), Ay = N × Ax = (0,0,1) → (x,y) → (0,x).
    final ocs = Mat3.ocs(const Vec3(1, 0, 0));
    expect(ocs.transform(const Vec2(4, 3)).x, closeTo(0, 1e-9));
    expect(ocs.transform(const Vec2(4, 3)).y, closeTo(4, 1e-9));
  });

  test('ocsInsert with extrusion (0,0,-1) lands on the WCS sheet', () {
    final world = Mat3.ocsInsert(
      const Vec2(-513651.937, 170415.059),
      const Vec2(-4.17, 4.17),
      0,
      const Vec3(0, 0, -1),
    );
    final parts = world.insertParts;
    expect(parts.position.x, closeTo(513651.937, 1e-6));
    expect(parts.position.y, closeTo(170415.059, 1e-6));
    expect(parts.scale.x, closeTo(4.17, 1e-9));
    expect(parts.scale.y, closeTo(4.17, 1e-9));
    expect(parts.rotation, closeTo(0, 1e-9));
    expect(world.transform(Vec2.zero()), parts.position);
  });

  test('transformDirection ignores translation', () {
    final matrix = const Mat3.translation(10, 20).multiplied(Mat3.rotation(0));
    expect(matrix.transformDirection(const Vec2(3, 4)), const Vec2(3, 4));
    expect(matrix.transform(const Vec2(3, 4)), const Vec2(13, 24));
  });

  test('a vanished mirror direction cannot invent a flip', () {
    final matrix = Mat3.mirror(const Vec2.zero(), const Vec2.zero());
    final image = matrix.transform(const Vec2(3, 2));
    expect(image.x.isFinite, isTrue);
    expect(image.y.isFinite, isTrue);
    expect(image, const Vec2.zero());
  });

  test('composes translation after rotation in the expected order', () {
    final matrix = Mat3.translation(10, 0).multiplied(Mat3.rotation(math.pi / 2));
    final moved = matrix.transform(const Vec2(1, 0));
    expect(moved.x, closeTo(10, 1e-12));
    expect(moved.y, closeTo(1, 1e-12));
  });

  test('reports rotation, mean scale and handedness', () {
    final matrix = Mat3.rotation(math.pi / 3).multiplied(Mat3.scaling(2, 2));
    expect(matrix.rotation, closeTo(math.pi / 3, 1e-12));
    expect(matrix.meanScale, closeTo(2, 1e-12));
    expect(matrix.determinant, greaterThan(0));
    expect(Mat3.scaling(-1, 1).determinant, lessThan(0));
  });

  test('align with one pair is a translation', () {
    final matrix = Mat3.align(const Vec2(1, 2), const Vec2(4, 6));
    expect(matrix.transform(const Vec2(1, 2)), const Vec2(4, 6));
    expect(matrix.transform(const Vec2(2, 2)), const Vec2(5, 6));
  });

  test('align with two pairs rotates about the first destination', () {
    final matrix = Mat3.align(
      const Vec2(0, 0),
      const Vec2(0, 0),
      source2: const Vec2(10, 0),
      dest2: const Vec2(0, 10),
    );
    final moved = matrix.transform(const Vec2(10, 0));
    expect(moved.x, closeTo(0, 1e-12));
    expect(moved.y, closeTo(10, 1e-12));
  });

  test('align scale matches the two segment lengths', () {
    final matrix = Mat3.align(
      const Vec2(0, 0),
      const Vec2(0, 0),
      source2: const Vec2(10, 0),
      dest2: const Vec2(0, 5),
      scale: true,
    );
    final moved = matrix.transform(const Vec2(10, 0));
    expect(moved.x, closeTo(0, 1e-12));
    expect(moved.y, closeTo(5, 1e-12));
  });

  test('inverse round trips a point', () {
    final matrix = Mat3.translation(4, -7)
        .multiplied(Mat3.rotation(0.4))
        .multiplied(Mat3.scaling(3, 1.5));
    const point = Vec2(2.5, -1.25);
    final back = matrix.inverted()!.transform(matrix.transform(point));
    expect(back.x, closeTo(point.x, 1e-9));
    expect(back.y, closeTo(point.y, 1e-9));
  });

  test('rotation and scale about a centre leave that centre fixed', () {
    const pivot = Vec2(10, 4);
    final rotated = Mat3.rotationAbout(math.pi / 2, pivot);
    expect(rotated.transform(pivot).x, closeTo(10, 1e-12));
    expect(rotated.transform(pivot).y, closeTo(4, 1e-12));
    final scaled = Mat3.scalingAbout(2, 3, pivot);
    expect(scaled.transform(pivot), pivot);
    expect(scaled.transform(const Vec2(11, 4)), const Vec2(12, 4));
  });

  test('mirror flips a point across the given axis', () {
    final mirrored = Mat3.mirror(const Vec2.zero(), const Vec2(0, 1));
    final image = mirrored.transform(const Vec2(3, 2));
    expect(image.x, closeTo(-3, 1e-12));
    expect(image.y, closeTo(2, 1e-12));
  });

  test('identity, direction and inverse cover the remaining ops', () {
    const id = Mat3.identity();
    expect(id.isIdentity, isTrue);
    expect(id.transformDirection(const Vec2(2, 0)), const Vec2(2, 0));
    final out = <double>[0, 0];
    Mat3.translation(1, 2).transformXYInto(3, 4, out, 0);
    expect(out, [4.0, 6.0]);
    expect(const Mat3.scaling(1, 0).inverted(), isNull);
    expect(id, const Mat3.identity());
    expect({id}.contains(const Mat3.identity()), isTrue);
    expect(id.toString(), contains('Mat3'));
  });
}
