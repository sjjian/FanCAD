import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an orphan import cannot invent a spatial hit after reindex', () {
    final document = CadDocument()
      ..registerImportedEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
      )
      ..reindex();
    expect(document.queryVisible(const Bounds2(-1, -1, 5, 1)), isEmpty);
    expect(document.entity(1), isNotNull);
  });
}
