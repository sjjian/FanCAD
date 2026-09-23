@Tags(['native'])
library;

import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG arc', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('an ARC that crosses zero keeps a 2π-equivalent sweep', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2(0, 0),
            radius: 4,
            startAngle: 5.5,
            endAngle: 0.8,
          ),
        ),
        name: 'arcwrap',
      );
      final arc = opened.entities.whereType<ArcEntity>().single;
      expect(arc.radius, closeTo(4, 1e-6));
      expect(arc.endAngle, closeTo(0.8, 1e-6));
      final start = arc.startAngle % (math.pi * 2);
      final expected = 5.5 % (math.pi * 2);
      expect(
        (start - expected).abs() < 1e-6 ||
            (start - expected - math.pi * 2).abs() < 1e-6 ||
            (start - expected + math.pi * 2).abs() < 1e-6,
        isTrue,
        reason: 'LibreDWG may wrap 5.5 to 5.5-2π; sweep must match',
      );
    });

    test('an ARC keeps centre, radius and sweep', () async {
      final source = CadDocument()
        ..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2(10, 20),
            radius: 5,
            startAngle: 0.25,
            endAngle: 2.5,
          ),
        );
      final opened = await rt.dwg(source, name: 'arc');
      expectMatchingSnapshots(source, opened, step: 'arc');
    }, timeout: Roundtrip.timeout);
  });
}
