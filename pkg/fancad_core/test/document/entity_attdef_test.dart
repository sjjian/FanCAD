import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('toAttrib copies the definition into a value', () {
    const def = AttdefEntity(
      id: 4,
      position: Vec2(1, 2),
      tag: 'REV',
      defaultValue: 'A',
      height: 3,
    );
    final attrib = def.toAttrib('B');
    expect(attrib.tag, 'REV');
    expect(attrib.value, 'B');
    expect(attrib.position, const Vec2(1, 2));
    expect(attrib.height, 3);
  });
}
