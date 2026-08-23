import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a default sheet cannot invent a custom plot placement', () {
    const sheet = Layout(name: 'A3', blockName: '*Paper_Space');
    expect(sheet.hasCustomPlotPlacement, isFalse);
    expect(sheet.copyWith(plotOffsetX: 0.5).hasCustomPlotPlacement, isTrue);
    expect(sheet.viewportIndexAt(0, 0), isNull);
  });
}
