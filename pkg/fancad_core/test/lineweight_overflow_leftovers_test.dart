import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a weight past 2.11 mm cannot invent a DXF value', () {
    expect(LineWeight.tryParse('2.12'), isNull);
    expect(LineWeight.tryParse('212'), isNull);
    expect(LineWeight.tryParse('3mm'), isNull);
  });
}
