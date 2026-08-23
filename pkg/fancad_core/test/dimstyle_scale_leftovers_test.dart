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
}
