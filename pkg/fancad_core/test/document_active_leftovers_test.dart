import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing tab cannot invent an active layout', () {
    final document = CadDocument();
    expect(document.setActiveLayout('NOPE'), isFalse);
    expect(document.activeLayoutName, 'Model');
  });
}
