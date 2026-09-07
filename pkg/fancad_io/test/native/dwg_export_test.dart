@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../support/roundtrip.dart';

void main() {
  late Roundtrip rt;

  setUpAll(() {
    rt = Roundtrip()..requireDwg();
  });

  test(
    'linear definition points stay off the text so a host can regen ticks',
    () async {
      const x1 = Vec2(50, 50);
      const x2 = Vec2(60, 50);
      const def = Vec2(55, 54);
      const text = Vec2(55, 58);
      const dimLayer = EntityProps(layer: '标注线');

      final opened = await rt.dwg(
        drawing(
          layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
          blocks: const [BlockRecord(name: '*D1', isAnonymous: true)],
          entities: const [
            DimensionEntity(
              id: 2,
              props: dimLayer,
              blockName: '*D1',
              measurement: 10,
              definitionPoints: [x1, x2, def],
              textPosition: text,
            ),
          ],
          owned: const {
            '*D1': [LineEntity(id: 1, props: dimLayer, start: x1, end: x2)],
          },
        ),
        name: 'dimpts',
      );

      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.definitionPoints, hasLength(3));
      expect(dim.definitionPoints[0], closeVec(x1));
      expect(dim.definitionPoints[1], closeVec(x2));
      expect(dim.definitionPoints[2], closeVec(def));
      expect(
        dim.definitionPoints.every(
          (point) =>
              (point.x - text.x).abs() < 1e-6 &&
              (point.y - text.y).abs() < 1e-6,
        ),
        isFalse,
        reason: 'GstarCAD regenerates ticks from the origins, not the note',
      );

      final dimBlock = opened.blocks.keys.cast<String>().firstWhere(
        (name) => name.toUpperCase() == '*D1',
        orElse: () => '',
      );
      expect(dimBlock, isNotEmpty);
      expect(opened.blocks[dimBlock]!.isAnonymous, isTrue);
      expect(
        dim.dimensionType & 32,
        isNot(0),
        reason: 'DXF 32 marks the *D as this dimension\'s exclusive block',
      );
      expect(
        opened.entitiesOf(dimBlock).whereType<LineEntity>(),
        isNotEmpty,
      );
    },
    timeout: Roundtrip.timeout,
  );

  test('a CJK font-coded dimension note still paints the glyphs', () async {
    const raw = r'{\F宋体|c134;型材1}';
    const dimLayer = EntityProps(layer: '标注线');
    final opened = await rt.dwg(
      drawing(
        layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
        blocks: const [BlockRecord(name: '*D1', isAnonymous: true)],
        entities: const [
          DimensionEntity(
            id: 2,
            props: dimLayer,
            blockName: '*D1',
            measurement: 10,
            overrideText: raw,
            definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
            textPosition: Vec2(5, 3),
          ),
        ],
        owned: const {
          '*D1': [
            MTextEntity(
              id: 1,
              position: Vec2(5, 3),
              content: raw,
              height: 2.5,
            ),
          ],
        },
      ),
      name: 'dimcjk',
    );

    final dim = opened.entities.whereType<DimensionEntity>().single;
    final sink = emit(dim, document: opened);
    final painted = sink.texts.map((item) => item.text).join();
    expect(painted, contains('型材1'));
    expect(
      painted.contains(r'\F') || painted.contains(r'\f') || painted.contains('{'),
      isFalse,
      reason: 'MTEXT font codes must not remain in the painted string',
    );
  }, timeout: Roundtrip.timeout);

  test('a drawing with CJK names reopens as UTF-8', () async {
    const layerName = '工艺';
    final opened = await rt.dwg(
      drawing(
        layers: const [LayerDef(name: layerName, color: CadColor.indexed(1))],
        entities: const [
          TextEntity(
            id: 1,
            props: EntityProps(layer: layerName),
            position: Vec2.zero(),
            content: '开槽',
            height: 2.5,
          ),
          MTextEntity(
            id: 2,
            props: EntityProps(layer: layerName),
            position: Vec2(0, 10),
            content: '锡东',
            height: 2.5,
          ),
        ],
      ),
      name: 'cjkutf',
    );

    final texts = <String>[
      ...opened.layers.keys,
      for (final entity in opened.entities)
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
    expect(opened.layers.keys.any((name) => name.contains(r'\U+')), isFalse);
  }, timeout: Roundtrip.timeout);

  test('a named layer keeps an indexed colour instead of ByLayer', () async {
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
  }, timeout: Roundtrip.timeout);
}
