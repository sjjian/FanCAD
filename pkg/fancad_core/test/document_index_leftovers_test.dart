import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing owner cannot invent a draw-order index', () {
    final document = CadDocument();
    expect(document.entityIndexOf(99), isNull);
    document.registerImportedEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    expect(document.entityIndexOf(1), isNull);
  });
}
