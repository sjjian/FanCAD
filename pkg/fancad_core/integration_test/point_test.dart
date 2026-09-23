@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG point', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('point display headers survive a DWG round trip', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..setHeaderVariable(r'$PDMODE', '35')
          ..setHeaderVariable(r'$PDSIZE', '4')
          ..addEntity(const PointEntity(id: 1, position: Vec2(1, 1))),
        name: 'pdmode',
      );
      expect(opened.headerVariables[r'$PDMODE'], '35');
      expect(
        double.parse(opened.headerVariables[r'$PDSIZE'] ?? ''),
        closeTo(4, 1e-6),
      );
    });

    test('a POINT keeps its position', () async {
      final source = CadDocument()
        ..addEntity(const PointEntity(id: 1, position: Vec2(3, 4)));
      final opened = await rt.dwg(source, name: 'pt');
      expectMatchingSnapshots(source, opened, step: 'point');
    }, timeout: Roundtrip.timeout);
  });
}
