import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('InsUnits', () {
    test('DXF codes and unique prefixes resolve', () {
      expect(InsUnits.fromCode(4), InsUnits.millimeters);
      expect(InsUnits.fromHeader('4'), InsUnits.millimeters);
      expect(InsUnits.fromHeader(null), InsUnits.unitless);
      expect(InsUnits.parse('mm'), InsUnits.millimeters);
      expect(InsUnits.parse('in'), InsUnits.inches);
      expect(InsUnits.parse('4'), InsUnits.millimeters);
      expect(InsUnits.parse('mill'), InsUnits.millimeters);
      expect(InsUnits.parse('nope'), isNull);
    });

    test('conversion goes through metres', () {
      expect(
        InsUnits.millimeters.convertTo(1000, InsUnits.meters),
        closeTo(1, 1e-12),
      );
      expect(
        InsUnits.inches.convertTo(12, InsUnits.feet),
        closeTo(1, 1e-12),
      );
      expect(InsUnits.unitless.convertTo(5, InsUnits.meters), 5);
    });
  });

  test('a document reads \$INSUNITS as a first-class unit', () {
    final document = CadDocument()..setHeaderVariable(r'$INSUNITS', '4');
    expect(document.insUnits, InsUnits.millimeters);
    document.setHeaderVariable(r'$INSUNITS', '1');
    expect(document.insUnits, InsUnits.inches);
  });
}
