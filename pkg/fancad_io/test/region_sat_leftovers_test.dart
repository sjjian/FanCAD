@Tags(['native'])
library;

import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// HunterDouglas process drawing with REGION sliders. CI does not ship it.
const String _sample =
    '/Users/sunjian/Downloads/亨特道格拉斯/案例/L/SOAS00009323---FL25预埋型材/工艺-00009323.dwg';

void main() {
  test('a REGION imports SAT loops, not a scribble of vertices', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final opened = await DrawingImporter().open(_sample);
    final entity = opened.document.entity(9958971);
    expect(entity, isA<UnknownEntity>());
    final region = entity! as UnknownEntity;
    expect(region.originalType, 'REGION');
    expect(region.strokeCounts.length, 2);
    expect(region.strokeCounts.every((count) => count >= 8), isTrue);
    expect(region.strokeCounts, isNot(equals([56])));
    final box = region.computeBounds();
    expect(box.width, closeTo(252, 1));
    expect(box.height, closeTo(193, 1));
  });
}
