import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown linetype name cannot invent a stock pattern', () {
    expect(LineTypeDef.builtin(''), isNull);
    expect(LineTypeDef.builtin('nope'), isNull);
    expect(LineTypeDef.builtin('dashed ')?.name, isNull);
    expect(const LineTypeDef(name: 'X', patternLength: 0).isSolid, isTrue);
    expect(const LineTypeDef(name: 'X', patternLength: 0).dashArray, isEmpty);
  });
}
