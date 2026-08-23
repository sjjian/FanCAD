import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('layer 0 or a missing name cannot invent a drop', () {
    final document = CadDocument();
    expect(document.removeLayer('0'), isNull);
    expect(document.removeLayer('NOPE'), isNull);
    expect(document.layer('0'), isNotNull);
  });
}
