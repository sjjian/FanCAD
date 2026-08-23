import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown mtext justify cannot invent an attachment', () {
    expect(
      Construct.justifyMText(
        const MTextEntity(id: 1, position: Vec2.zero(), content: 'A'),
        'nope',
      ),
      isNull,
    );
    expect(
      Construct.justifyMText(
        const MTextEntity(id: 2, position: Vec2.zero(), content: 'A'),
        'fit',
      ),
      isNull,
    );
  });
}
