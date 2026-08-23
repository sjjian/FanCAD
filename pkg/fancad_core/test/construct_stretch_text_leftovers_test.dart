import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const text = TextEntity(
    id: 1,
    position: Vec2.zero(),
    content: 'NOTE',
    height: 2.5,
  );

  test('a window on the insertion point moves the text', () {
    final stretched = Construct.stretch(
      text,
      const Bounds2(-1, -1, 1, 1),
      const Vec2(4, 0),
    )! as TextEntity;

    expect(stretched.position, const Vec2(4, 0));
    expect(stretched.content, 'NOTE');
    expect(stretched.height, 2.5);
  });

  test('a window miss cannot move a text insertion', () {
    expect(
      Construct.stretch(
        text,
        const Bounds2(20, 20, 21, 21),
        const Vec2(4, 0),
      ),
      isNull,
    );
  });
}
