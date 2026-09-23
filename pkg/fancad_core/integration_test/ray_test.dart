@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG ray', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a diagonal RAY keeps a unit direction', () async {
      final source = CadDocument()
        ..addEntity(
          const RayEntity(id: 1, origin: Vec2(2, 3), direction: Vec2(3, 4)),
        );
      final opened = await rt.dwg(source, name: 'rayd');
      final ray = opened.entities.whereType<RayEntity>().single;
      expect(ray.origin, const Vec2(2, 3));
      expect(ray.direction.x / ray.direction.y, closeTo(0.75, 1e-6));
    });

    test('a RAY keeps origin and direction', () async {
      final source = CadDocument()
        ..addEntity(
          const RayEntity(id: 1, origin: Vec2(2, 3), direction: Vec2(0, 1)),
        );
      final opened = await rt.dwg(source, name: 'ray');
      expectMatchingSnapshots(source, opened, step: 'ray');
    }, timeout: Roundtrip.timeout);
  });
}
