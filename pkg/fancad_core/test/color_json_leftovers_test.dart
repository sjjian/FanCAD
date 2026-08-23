import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('junk color JSON cannot invent a true color', () {
    expect(cadColorFromJson(null).kind, ColorKind.byLayer);
    expect(cadColorFromJson('nope').kind, ColorKind.byLayer);
    expect(cadColorFromJson('#zzzzzz').kind, ColorKind.byLayer);
    expect(cadColorFromJson(<int>[]).kind, ColorKind.byLayer);
  });
}
