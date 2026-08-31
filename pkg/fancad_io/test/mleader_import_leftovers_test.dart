@Tags(['native'])
library;

import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// A Chinese R2004 process drawing from the HunterDouglas sample set.
/// CI does not ship it; the test is skipped when the file is absent.
const String _sample = '/Users/sunjian/Downloads/亨特道格拉斯/案例2/'
    'SOAS00002617---QC50+25mm+U型槽/工艺 -SOAS00002617.dwg';

void main() {
  test('MULTILEADER objects import as editable mleaders, not empty proxies',
      () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final opened = await DrawingImporter().open(_sample);
    final leaders = opened.document.entities.whereType<MLeaderEntity>().toList();
    expect(leaders, isNotEmpty);
    expect(
      leaders.any(
        (entity) =>
            entity.vertices.length >= 4 &&
            (entity.content.isNotEmpty || entity.computeBounds().isNotEmpty),
      ),
      isTrue,
    );

    final unknown = opened.document.entities.whereType<UnknownEntity>().toList();
    expect(
      unknown.where((entity) => entity.originalType.contains('MULTILEADER')),
      isEmpty,
    );
  });
}
