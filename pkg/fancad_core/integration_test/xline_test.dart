@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG xline', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('an XLINE keeps origin and direction', () async {
      final source = CadDocument()
        ..addEntity(
          const XLineEntity(id: 1, origin: Vec2(4, 5), direction: Vec2(1, 0)),
        );
      final opened = await rt.dwg(source, name: 'xline');
      expectMatchingSnapshots(source, opened, step: 'xline');
    }, timeout: Roundtrip.timeout);

    test('a diagonal XLINE keeps a unit direction', () async {
      final source = CadDocument()
        ..addEntity(
          const XLineEntity(id: 1, origin: Vec2(4, 5), direction: Vec2(3, 4)),
        );
      final opened = await rt.dwg(source, name: 'xlined');
      final xline = opened.entities.whereType<XLineEntity>().single;
      expect(xline.origin, const Vec2(4, 5));
      expect(xline.direction.x / xline.direction.y, closeTo(0.75, 1e-6));
    });
  });
}
