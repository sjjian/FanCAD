import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('centre and spaced keywords still map to the same alignment', () {
    final parsed = Construct.parseTextJustify(
      'Top Left',
      currentH: TextHAlign.right,
      currentV: TextVAlign.baseline,
    );
    expect(parsed, isNotNull);
    expect(parsed!.h, TextHAlign.left);
    expect(parsed.v, TextVAlign.top);

    final centre = Construct.parseTextJustify(
      'centre',
      currentH: TextHAlign.left,
      currentV: TextVAlign.baseline,
    );
    expect(centre!.h, TextHAlign.center);
    expect(centre.v, TextVAlign.baseline);
  });

  test('empty or fit keywords cannot invent an alignment', () {
    expect(
      Construct.parseTextJustify(
        '   ',
        currentH: TextHAlign.left,
        currentV: TextVAlign.baseline,
      ),
      isNull,
    );
    expect(
      Construct.parseTextJustify(
        'fit',
        currentH: TextHAlign.left,
        currentV: TextVAlign.baseline,
      ),
      isNull,
    );
    expect(
      Construct.justifyText(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'A'),
        'fit',
      ),
      isNull,
    );
  });
}
