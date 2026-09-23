@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG linetype', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a DASHED line type is bound on the entity', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLineType(LineTypeDef.dashed)
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(lineType: 'DASHED'),
              start: Vec2.zero(),
              end: Vec2(12, 0),
            ),
          ),
        name: 'dashed',
      );
      final line = opened.entities.whereType<LineEntity>().single;
      expect(line.end.x, closeTo(12, 1e-6));
      expect(line.props.lineType, 'DASHED');
    });

    test('a DASHED table row exists even when the entity is ByLayer', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLineType(LineTypeDef.dashed)
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(5, 0)),
          ),
        name: 'lttable',
      );
      expect(opened.lineTypes.containsKey('DASHED'), isTrue);
      expect(opened.lineTypes['DASHED']!.pattern, [
        closeTo(12, 1e-6),
        closeTo(-6, 1e-6),
      ]);
      expect(opened.lineTypes['DASHED']!.patternLength, closeTo(18, 1e-6));
    });

    test('CENTER and HIDDEN table names survive', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLineType(LineTypeDef.center)
          ..putLineType(LineTypeDef.hidden)
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
          ),
        name: 'ltsnames',
      );
      expect(opened.lineTypes.containsKey('CENTER'), isTrue);
      expect(opened.lineTypes.containsKey('HIDDEN'), isTrue);
    });

    test('PHANTOM and DOT table names survive', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLineType(LineTypeDef.phantom)
          ..putLineType(LineTypeDef.dot)
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(3, 0)),
          ),
        name: 'ltmore',
      );
      expect(opened.lineTypes.containsKey('PHANTOM'), isTrue);
      expect(opened.lineTypes.containsKey('DOT'), isTrue);
    });

    test('global linetype scale survives a DWG round trip', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..setHeaderVariable(r'$LTSCALE', '2.5')
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
          ),
        name: 'ltscale',
      );
      expect(
        double.parse(opened.headerVariables[r'$LTSCALE'] ?? ''),
        closeTo(2.5, 1e-6),
      );
    });
  });
}
