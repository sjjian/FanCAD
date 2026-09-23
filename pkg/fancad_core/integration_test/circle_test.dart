@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG circle', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a CIRCLE keeps its centre and radius', () async {
      final source = CadDocument()
        ..addEntity(const CircleEntity(id: 1, center: Vec2(8, 9), radius: 2.5));
      final opened = await rt.dwg(source, name: 'circ');
      expectMatchingSnapshots(source, opened, step: 'circle');
    }, timeout: Roundtrip.timeout);
  });
}
