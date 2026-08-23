import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a TTF family cannot invent an SHX stroke font', () {
    expect(const TextStyleDef(name: 'A', fontFamily: 'Arial').isShxFont, isFalse);
    expect(const TextStyleDef(name: 'A', fontFamily: 'txt').isShxFont, isTrue);
    expect(const TextStyleDef(name: 'A', fontFamily: 'ROMANS').isShxFont, isTrue);
  });
}
