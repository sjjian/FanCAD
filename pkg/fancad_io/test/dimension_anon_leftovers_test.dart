@Tags(['native'])
library;

import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test(
    'linear definition points stay off the text so a host can regen ticks',
    () async {
      final directory = Directory.systemTemp.createTempSync('fancad-dimpts');
      addTearDown(() => directory.deleteSync(recursive: true));

      const x1 = Vec2(50, 50);
      const x2 = Vec2(60, 50);
      const def = Vec2(55, 54);
      const text = Vec2(55, 58);
      const dimLayer = EntityProps(layer: '标注线');

      final document = CadDocument()
        ..putLayer(const LayerDef(name: '标注线', color: CadColor.indexed(1)))
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..addEntity(
          const LineEntity(id: 1, props: dimLayer, start: x1, end: x2),
          blockName: '*D1',
        )
        ..addEntity(
          const DimensionEntity(
            id: 2,
            props: dimLayer,
            blockName: '*D1',
            measurement: 10,
            definitionPoints: [x1, x2, def],
            textPosition: text,
          ),
        );

      final path = '${directory.path}/dim.dwg';
      await DrawingImporter().save(path, document);
      final opened = (await DrawingImporter().open(path)).document;
      final dim = opened.entities.whereType<DimensionEntity>().single;

      expect(dim.definitionPoints, hasLength(3));
      expect(dim.definitionPoints[0].x, closeTo(x1.x, 1e-6));
      expect(dim.definitionPoints[0].y, closeTo(x1.y, 1e-6));
      expect(dim.definitionPoints[1].x, closeTo(x2.x, 1e-6));
      expect(dim.definitionPoints[1].y, closeTo(x2.y, 1e-6));
      expect(dim.definitionPoints[2].x, closeTo(def.x, 1e-6));
      expect(dim.definitionPoints[2].y, closeTo(def.y, 1e-6));
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
    timeout: Timeout.parse('2m'),
  );
}
