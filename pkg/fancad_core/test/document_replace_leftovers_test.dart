import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing id cannot invent a replacement', () {
    final document = CadDocument();
    expect(
      document.replaceEntity(
        const LineEntity(id: 99, start: Vec2.zero(), end: Vec2(4, 0)),
      ),
      isNull,
    );
    expect(document.entity(99), isNull);
    expect(document.entities, isEmpty);
  });
}
