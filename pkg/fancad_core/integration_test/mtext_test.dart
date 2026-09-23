@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG mtext', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('MTEXT keeps a paragraph break', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(8, 9),
            content: 'line1\\Pline2',
            height: 3,
            rectangleWidth: 40,
          ),
        ),
        name: 'mtextp',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.content, contains('line1'));
      expect(mtext.content, contains('line2'));
      expect(mtext.position.x, closeTo(8, 1e-6));
    });

    test('MTEXT keeps rotation, box width and attachment', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(10, 12),
            content: 'box',
            height: 4,
            rotation: 0.3,
            rectangleWidth: 50,
            attachment: 5,
          ),
        ),
        name: 'mtextatt',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.content, 'box');
      expect(mtext.rotation, closeTo(0.3, 1e-6));
      expect(mtext.rectangleWidth, closeTo(50, 1e-6));
      expect(mtext.attachment, 5);
    });

    test('MTEXT keeps inline formatting codes', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(2, 2),
            content: r'{\fArial|b1;Bold}\Pplain',
            height: 3,
            rectangleWidth: 40,
          ),
        ),
        name: 'mtextfmt',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.content, contains('Bold'));
      expect(mtext.content, contains(r'\P'));
      expect(mtext.content, contains('plain'));
    });

    test('MTEXT attachment 9 stays at bottom-right', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putTextStyle(const TextStyleDef(name: 'NOTES'))
          ..addEntity(
            const MTextEntity(
              id: 1,
              position: Vec2(80, 20),
              content: 'br',
              height: 4,
              rectangleWidth: 30,
              attachment: 9,
              styleName: 'NOTES',
            ),
          ),
        name: 'mtext9',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.attachment, 9);
      expect(mtext.styleName, 'NOTES');
      expect(mtext.position.x, closeTo(80, 1e-6));
    });

    test('hugging right-attached MTEXT is saved as top-left', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(658, 1162),
            content: '项目名称：瑞峰园小区',
            height: 111,
            attachment: 3,
          ),
        ),
        name: 'hugmtext',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.attachment, 1);
      expect(mtext.position.x, closeTo(658, 1e-6));
      expect(mtext.position.y, closeTo(1162, 1e-6));
      expect(mtext.content, contains('瑞峰园'));
    });
  });
}
