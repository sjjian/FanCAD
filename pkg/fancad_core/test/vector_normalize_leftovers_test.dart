import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished vector cannot invent a unit direction', () {
    expect(const Vec2.zero().normalized(), const Vec2.zero());
    expect(const Vec2.zero().normalized().isFinite, isTrue);
  });
}
