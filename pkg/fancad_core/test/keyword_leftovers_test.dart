import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an ambiguous prefix cannot invent a keyword', () {
    expect(ArgsCommandInput.matchKeyword('c', ['center', 'close']), isNull);
    expect(ArgsCommandInput.matchKeyword('ce', ['center', 'close']), 'center');
    expect(ArgsCommandInput.matchKeyword('nope', ['center', 'end']), isNull);
  });
}
