import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a blank or non-finite weight cannot invent a DXF value', () {
    expect(LineWeight.tryParse(''), isNull);
    expect(LineWeight.tryParse('   '), isNull);
    expect(LineWeight.tryParse('-1'), isNull);
    expect(LineWeight.tryParse('nan'), isNull);
    expect(LineWeight.tryParse('inf'), isNull);
    expect(LineWeight.tryParse('bydefault'), LineWeight.byDefault);
  });
}
