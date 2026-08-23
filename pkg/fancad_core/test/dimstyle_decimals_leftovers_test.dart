import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range DIMDEC cannot invent extra precision', () {
    expect(const DimStyleDef(name: 'X', decimalPlaces: -3).clampedDecimals, 0);
    expect(const DimStyleDef(name: 'X', decimalPlaces: 99).clampedDecimals, 8);
    expect(const DimStyleDef(name: 'X', decimalPlaces: 2).clampedDecimals, 2);
  });
}
