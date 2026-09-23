@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG text style', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a named text style is bound on TEXT', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putTextStyle(
            const TextStyleDef(name: 'TITLE', height: 5, widthFactor: 0.8),
          )
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(1, 2),
              content: 'A',
              height: 5,
              styleName: 'TITLE',
            ),
          ),
        name: 'textstyle',
      );
      expect(opened.textStyles.containsKey('TITLE'), isTrue);
      expect(opened.entities.whereType<TextEntity>().single.styleName, 'TITLE');
    });

    test('a named text style keeps font metrics', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putTextStyle(
            const TextStyleDef(
              name: 'NOTES',
              fontFamily: 'romans',
              height: 2.5,
              widthFactor: 0.8,
              obliqueAngle: 0.15,
            ),
          )
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(1, 1),
              content: 'n',
              styleName: 'NOTES',
            ),
          ),
        name: 'stymet',
      );
      expect(opened.textStyles.containsKey('NOTES'), isTrue);
      expect(opened.entities.whereType<TextEntity>().single.styleName, 'NOTES');
      expect(opened.textStyles['NOTES']!.fontFamily, 'romans');
      expect(opened.textStyles['NOTES']!.height, closeTo(2.5, 1e-6));
      expect(opened.textStyles['NOTES']!.widthFactor, closeTo(0.8, 1e-6));
      expect(opened.textStyles['NOTES']!.obliqueAngle, closeTo(0.15, 1e-6));
    });

    test('Standard keeps the file font instead of LibreDWG txt', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putTextStyle(
            const TextStyleDef(
              name: 'Standard',
              fontFamily: 'simsun.ttf',
              bigFontFamily: 'gbcbig.shx',
            ),
          )
          ..addEntity(
            const TextEntity(id: 1, position: Vec2(1, 1), content: 's'),
          ),
        name: 'stdfont',
      );
      expect(opened.textStyles['Standard']!.fontFamily, 'simsun.ttf');
      expect(opened.textStyles['Standard']!.bigFontFamily, 'gbcbig.shx');
    });

    test('an empty style font is not replaced with txt', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putTextStyle(
            const TextStyleDef(name: '样式 1', fontFamily: '', bigFontFamily: ''),
          )
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(1, 1),
              content: '绘图',
              styleName: '样式 1',
            ),
          ),
        name: 'emptyfont',
      );
      expect(opened.textStyles['样式 1']!.fontFamily, isEmpty);
      expect(opened.textStyles['样式 1']!.bigFontFamily, isEmpty);
      expect(opened.entities.whereType<TextEntity>().single.content, '绘图');
    });

    test('two named text styles stay bound on their strings', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putTextStyle(const TextStyleDef(name: 'TITLE'))
          ..putTextStyle(const TextStyleDef(name: 'NOTES'))
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(0, 0),
              content: 'T',
              styleName: 'TITLE',
            ),
          )
          ..addEntity(
            const MTextEntity(
              id: 2,
              position: Vec2(0, 8),
              content: 'N',
              styleName: 'NOTES',
            ),
          ),
        name: 'twosty',
      );
      expect(opened.entities.whereType<TextEntity>().single.styleName, 'TITLE');
      expect(
        opened.entities.whereType<MTextEntity>().single.styleName,
        'NOTES',
      );
    });
  });
}
