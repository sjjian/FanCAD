import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a non-positive dimstyle scale cannot invent a vanish', () {
    const broken = DimStyleDef(name: 'X', scale: 0, textHeight: 2.5);
    expect(broken.overallScale, 1);
    expect(broken.scaledTextHeight, 2.5);
    expect(
      const DimStyleDef(name: 'X', scale: double.nan).overallScale,
      1,
    );
  });

  test('header DIMSCALE fills an identity style so fallback text is readable', () {
    final document = CadDocument()..setHeaderVariable(r'$DIMSCALE', '14');
    expect(document.dimStyle('Standard').scaledTextHeight, closeTo(35, 1e-9));
    expect(document.dimStyle('Standard').scale, closeTo(14, 1e-9));
  });

  test('an explicit dimstyle scale cannot be replaced by the header', () {
    final document = CadDocument()
      ..putDimStyle(const DimStyleDef(name: 'ARCH', textHeight: 5, scale: 2))
      ..setHeaderVariable(r'$DIMSCALE', '14');
    expect(document.dimStyle('ARCH').scaledTextHeight, closeTo(10, 1e-9));
  });
}
