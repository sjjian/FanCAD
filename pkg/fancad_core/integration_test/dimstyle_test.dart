@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG dimension style', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('dimension styles survive a DWG round trip', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putDimStyle(
            const DimStyleDef(name: 'ARCH', textHeight: 5, decimalPlaces: 0),
          )
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const DimensionEntity(
              id: 1,
              blockName: '*D1',
              styleName: 'ARCH',
              measurement: 10,
              definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 2)],
              textPosition: Vec2(5, 2),
            ),
          ),
        name: 'dimsty',
      );
      expect(opened.dimStyles.containsKey('ARCH'), isTrue);
      expect(opened.dimStyles['ARCH']!.textHeight, closeTo(5, 1e-6));
      expect(opened.dimStyles['ARCH']!.decimalPlaces, 0);
      expect(
        opened.entities.whereType<DimensionEntity>().single.styleName,
        'ARCH',
      );
    });
  });
}
