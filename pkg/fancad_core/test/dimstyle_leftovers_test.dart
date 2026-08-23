import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing or Standard name cannot invent a dimstyle drop', () {
    final document = CadDocument();
    expect(document.dimStyle('nope').name, 'Standard');
    expect(document.removeDimStyle('Standard'), isNull);
    expect(document.removeDimStyle('nope'), isNull);
    expect(document.namedDimStyle('nope'), isNull);
  });
}
