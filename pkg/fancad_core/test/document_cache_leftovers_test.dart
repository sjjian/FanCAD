import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('invalidating caches cannot invent leftover hits', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    expect(document.queryVisible(const Bounds2(-1, -1, 5, 1)), isNotEmpty);
    document.invalidateCaches();
    expect(document.queryVisible(const Bounds2(20, 20, 21, 21)), isEmpty);
    expect(document.queryVisible(const Bounds2(-1, -1, 5, 1)), isNotEmpty);
  });
}
