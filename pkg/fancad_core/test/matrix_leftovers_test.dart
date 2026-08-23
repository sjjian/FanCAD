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

  test('transformDirection ignores translation', () {
    final matrix = const Mat3.translation(10, 20).multiplied(Mat3.rotation(0));
    expect(matrix.transformDirection(const Vec2(3, 4)), const Vec2(3, 4));
    expect(matrix.transform(const Vec2(3, 4)), const Vec2(13, 24));
  });
}
