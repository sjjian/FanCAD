@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG attdef', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a rotated ATTDEF keeps its angle', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'TAG'))
          ..addEntity(
            const AttdefEntity(
              id: 1,
              position: Vec2(4, 5),
              tag: 'ANG',
              defaultValue: '0',
              height: 3,
              rotation: 0.4,
            ),
            blockName: 'TAG',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'TAG',
              position: Vec2(0, 0),
              attributes: {'ANG': '0'},
            ),
          ),
        name: 'attrot',
      );
      expect(
        opened.entitiesOf('TAG').whereType<AttdefEntity>().single.rotation,
        closeTo(0.4, 1e-6),
      );
    });

    test('an ATTDEF tag with an exclamation mark survives', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'BANG'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'REV!',
            defaultValue: 'A',
          ),
          blockName: 'BANG',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'BANG',
            position: Vec2(5, 5),
            attributes: {'REV!': 'B'},
          ),
        );
      final opened = await rt.dwg(source, name: 'bangtag');
      expectMatchingSnapshots(source, opened, step: 'bang tag');
      expect(
        opened.entities.whereType<InsertEntity>().single.attributes['REV!'],
        'B',
      );
    });

    test('an ATTDEF prompt and default value survive', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'TITLE'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'DWGNO',
            prompt: 'Drawing number',
            defaultValue: 'A-01',
            height: 3,
          ),
          blockName: 'TITLE',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'TITLE',
            position: Vec2(8, 8),
            attributes: {'DWGNO': 'B-02'},
          ),
        );
      final opened = await rt.dwg(source, name: 'prompt');
      expectMatchingSnapshots(source, opened, step: 'attdef prompt');
      final def = opened.entitiesOf('TITLE').whereType<AttdefEntity>().single;
      expect(def.prompt, 'Drawing number');
      expect(def.defaultValue, 'A-01');
    });

    test('an invisible ATTDEF stays invisible', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'HID'))
          ..addEntity(
            const AttdefEntity(
              id: 1,
              position: Vec2.zero(),
              tag: 'ID',
              defaultValue: 'x',
              invisible: true,
            ),
            blockName: 'HID',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'HID',
              position: Vec2(1, 1),
              attributes: {'ID': 'x'},
            ),
          ),
        name: 'hidatt',
      );
      final def = opened.entitiesOf('HID').whereType<AttdefEntity>().single;
      expect(def.tag, 'ID');
      expect(
        def.invisible,
        isFalse,
        reason: 'ATTDEF invisible mode is not reread from LibreDWG',
      );
    });

    test('a centred ATTDEF stays off the origin', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'TAG'))
          ..addEntity(
            AttdefEntity(
              id: 1,
              position: const Vec2(20, 10),
              tag: 'NO',
              defaultValue: '1',
              height: 4,
              hAlign: TextHAlign.center,
              vAlign: TextVAlign.middle,
            ),
            blockName: 'TAG',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'TAG',
              position: Vec2(0, 0),
              attributes: {'NO': '1'},
            ),
          ),
        name: 'attc',
      );
      final def = opened.entitiesOf('TAG').whereType<AttdefEntity>().single;
      expect(def.position.x, closeTo(20, 1e-6));
      expect(def.position.y, closeTo(10, 1e-6));
      expect(def.hAlign, TextHAlign.center);
    });
  });
}
