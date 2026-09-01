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
    expect(flipped.transform(const Vec2(-513651.937, 170415.059)).x,
        closeTo(513651.937, 1e-9));
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
    expect(
      world.transform(Vec2.zero()),
      parts.position,
    );
  });

  test('transformDirection ignores translation', () {
    final matrix = const Mat3.translation(10, 20).multiplied(Mat3.rotation(0));
    expect(matrix.transformDirection(const Vec2(3, 4)), const Vec2(3, 4));
    expect(matrix.transform(const Vec2(3, 4)), const Vec2(13, 24));
  });
}
