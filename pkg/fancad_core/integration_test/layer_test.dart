@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG layer', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test(
      'a named layer keeps an indexed colour instead of ByLayer',
      () async {
        final opened = await rt.dwg(
          drawing(
            layers: const [
              LayerDef(name: '折边线', color: CadColor.indexed(213)),
              LayerDef(name: '角码孔', color: CadColor.indexed(1)),
            ],
            entities: const [
              LineEntity(
                id: 1,
                props: EntityProps(layer: '折边线'),
                start: Vec2.zero(),
                end: Vec2(8, 0),
              ),
            ],
          ),
          name: 'layeraci',
        );

        expect(opened.layers['折边线']?.color, const CadColor.indexed(213));
        expect(opened.layers['角码孔']?.color, const CadColor.indexed(1));
        final sentinels = [
          for (final layer in opened.layers.values)
            if (layer.color.kind == ColorKind.byLayer ||
                layer.color.kind == ColorKind.byBlock)
              '${layer.name}=${layer.color}',
        ];
        expect(sentinels, isEmpty, reason: sentinels.join(', '));
      },
      timeout: Roundtrip.timeout,
    );

    test('a named layer keeps off, frozen and locked', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLayer(
            const LayerDef(
              name: 'OFF',
              visible: false,
              frozen: true,
              locked: true,
              plottable: false,
            ),
          )
          ..addEntity(
            const PointEntity(
              id: 1,
              props: EntityProps(layer: 'OFF'),
              position: Vec2(1, 1),
            ),
          ),
        name: 'layerflags',
      );
      final layer = opened.layer('OFF');
      expect(layer, isNotNull);
      expect(
        opened.entities.whereType<PointEntity>().single.props.layer,
        'OFF',
      );
      expect(layer!.plottable, isFalse);
      expect(layer.visible, isFalse);
      expect(layer.frozen, isTrue);
      expect(layer.locked, isTrue);
    });

    test('a layer indexed colour survives on the table row', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLayer(const LayerDef(name: 'WALLS', color: CadColor.indexed(5)))
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: 'WALLS'),
              start: Vec2.zero(),
              end: Vec2(8, 0),
            ),
          ),
        name: 'layeraci',
      );
      expect(opened.layer('WALLS')?.color, const CadColor.indexed(5));
      expect(
        opened.entities.whereType<LineEntity>().single.props.layer,
        'WALLS',
      );
    });

    test('a CJK layer name is not stored as MIF on reopen', () async {
      const layerName = '标注线';
      final opened = await rt.dwg(
        CadDocument()
          ..putLayer(
            const LayerDef(name: layerName, color: CadColor.indexed(1)),
          )
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: layerName),
              start: Vec2.zero(),
              end: Vec2(8, 0),
            ),
          ),
        name: 'cjklayer',
      );
      expect(opened.layers.containsKey(layerName), isTrue);
      expect(opened.layers.keys.any((name) => name.contains(r'\U+')), isFalse);
      expect(
        opened.entities.whereType<LineEntity>().single.props.layer,
        layerName,
      );
      expect(opened.layer(layerName)?.color, const CadColor.indexed(1));
    });

    test('a layer millimetre lineweight survives', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLayer(const LayerDef(name: 'THICK', lineWeight: 50))
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: 'THICK'),
              start: Vec2.zero(),
              end: Vec2(2, 0),
            ),
          ),
        name: 'lyrw',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.layer,
        'THICK',
      );
      expect(opened.layer('THICK')?.lineWeight, 50);
    });

    test('a layer line-type name is bound', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putLineType(LineTypeDef.center)
          ..putLayer(const LayerDef(name: 'AXIS', lineType: 'CENTER'))
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: 'AXIS'),
              start: Vec2.zero(),
              end: Vec2(8, 0),
            ),
          ),
        name: 'lylt',
      );
      expect(opened.layer('AXIS'), isNotNull);
      expect(opened.layer('AXIS')!.lineType, 'CENTER');
    });
  });
}
