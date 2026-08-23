import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a junk plot twist cannot invent a fifth orientation', () {
    expect(Layout.normalizePlotRotation(20), 0);
    expect(Layout.normalizePlotRotation(400), 0);
    expect(Layout.normalizePlotRotation(-45), 270);
  });
}
