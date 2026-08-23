import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('hidden geometry cannot invent model extents', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 1,
          props: EntityProps(visible: false),
          start: Vec2.zero(),
          end: Vec2(10, 0),
        ),
      );
    expect(document.extents.isEmpty, isTrue);
  });
}
