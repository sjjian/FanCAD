import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an aligned dimension explodes along the measured chord', () {
    final dim = Construct.alignedDimension(
      const Vec2.zero(),
      const Vec2(6, 8),
      const Vec2(-2, 2),
    )!;
    final pieces = Construct.explodeDimension(dim);
    final lines = pieces.whereType<LineEntity>().toList();

    expect(lines, isNotEmpty);
    expect(pieces.whereType<TextEntity>(), isNotEmpty);
    expect(
      lines.any((line) => line.length > 9),
      isTrue,
    );
  });
}
