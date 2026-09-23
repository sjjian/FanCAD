@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG solid', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a triangle SOLID keeps its three unique corners', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const SolidEntity(
            id: 1,
            corners: [Vec2(0, 0), Vec2(4, 0), Vec2(0, 3)],
          ),
        ),
        name: 'solid3',
      );
      final solid = opened.entities.whereType<SolidEntity>().single;
      final unique = {
        for (final p in solid.corners)
          '${(p.x * 1e6).round()}:${(p.y * 1e6).round()}',
      };
      expect(
        unique,
        containsAll(['0:0', '4000000:0', '0:3000000']),
        reason: 'DWG SOLID stores four corners; a triangle repeats the last',
      );
    });

    test('a four-corner SOLID keeps Z-order corners', () async {
      final source = CadDocument()
        ..addEntity(
          const SolidEntity(
            id: 1,
            corners: [Vec2(0, 0), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
          ),
        );
      final opened = await rt.dwg(source, name: 'solid4');
      expectMatchingSnapshots(source, opened, step: 'quad solid');
    }, timeout: Roundtrip.timeout);
  });
}
