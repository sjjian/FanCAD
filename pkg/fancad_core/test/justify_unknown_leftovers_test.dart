import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown justify keyword cannot invent an alignment', () {
    expect(
      Construct.parseTextJustify(
        'nope',
        currentH: TextHAlign.left,
        currentV: TextVAlign.baseline,
      ),
      isNull,
    );
    expect(
      Construct.justifyMText(
        const MTextEntity(id: 1, position: Vec2.zero(), content: 'A'),
        'align',
      ),
      isNull,
    );
  });
}
