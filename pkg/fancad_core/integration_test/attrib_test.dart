@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG attrib', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('several attributes including a lowercase tag survive', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'FORM'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'rev',
            defaultValue: 'A',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const AttdefEntity(
            id: 2,
            position: Vec2(0, 4),
            tag: 'Sheet no',
            defaultValue: '-',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'FORM',
            position: Vec2(30, 30),
            attributes: {'rev': 'B', 'Sheet no': '12'},
          ),
        );
      final opened = await rt.dwg(source, name: 'attribs');
      expectMatchingSnapshots(source, opened, step: 'multi attrib');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.attributes['rev'], 'B');
      expect(insert.attributes['Sheet no'], '12');
    });
  });
}
