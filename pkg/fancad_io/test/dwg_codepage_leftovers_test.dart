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
  test('a GBK-coded R2004 drawing keeps Chinese notes as UTF-8', () async {
    if (!File(_sample).existsSync()) {
      markTestSkipped('sample DWG is not on this machine');
      return;
    }
    final opened = await DrawingImporter().open(_sample);
    final texts = <String>[
      ...opened.document.layers.keys,
      for (final entity in opened.document.entities)
        if (entity is TextEntity)
          entity.content
        else if (entity is MTextEntity)
          entity.content,
    ].join('\n');
    expect(texts.contains('\uFFFD'), isFalse);
    expect(
      texts.contains('工艺') || texts.contains('开槽') || texts.contains('锡东'),
      isTrue,
    );
  });
}
