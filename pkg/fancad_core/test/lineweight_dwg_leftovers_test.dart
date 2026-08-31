import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('DWG inherit sentinels are not 0.29 mm strokes', () {
    expect(LineWeight.normalize(29), LineWeight.byLayer);
    expect(LineWeight.normalize(30), LineWeight.byBlock);
    expect(LineWeight.normalize(31), LineWeight.byDefault);
    expect(LineWeight.normalize(25), 25);
    expect(LineWeight.normalize(LineWeight.byLayer), LineWeight.byLayer);
  });

  test('a ByLayer-as-29 entity on a Default layer is a hairline', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: '0', lineWeight: 31));
    final style = document.resolve(
      const EntityProps(lineWeight: 29),
      ResolvedStyle.fallback,
    );
    expect(style.lineWeight, LineWeight.zero);
  });
}
