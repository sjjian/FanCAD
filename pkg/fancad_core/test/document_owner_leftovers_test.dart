import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing id cannot invent an owner', () {
    final document = CadDocument();
    expect(document.ownerOf(99), isNull);
    document.registerImportedEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    expect(document.ownerOf(1), isNull);
  });
}
