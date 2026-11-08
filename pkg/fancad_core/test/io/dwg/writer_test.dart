import 'dart:typed_data';

import 'package:fancad_core/src/io/dwg/dwg_reader.dart';
import 'package:fancad_core/src/io/dwg/writer/dwg_crc.dart';
import 'package:fancad_core/src/io/dwg/writer/r2000_appender.dart';
import 'package:fancad_core/src/io/dwg/writer/r2000_classes.dart';
import 'package:fancad_core/src/io/dwg/writer/r2000_writer.dart';
import 'package:fancad_core/src/io/dwg/writer/template_layout.dart';
import 'package:test/test.dart';

void main() {
  group('R2000 writer', () {
    test('writes an empty drawing the reader can open', () {
      final bytes = const R2000Writer().writeEmpty();
      expect(DwgReader.supportsBytes(bytes), isTrue);

      final drawing = DwgReader.readBytes(bytes);
      expect(drawing.version, 2000);
      expect(drawing.objectCount, 0);
      expect(drawing.entities, isEmpty);
    });

    test('exposes the template object map and model-space block', () {
      final layout = R2000TemplateLayout.read();
      expect(layout.sections, hasLength(6));
      expect(layout.objects, hasLength(33));
      expect(layout.blockNames.values, contains('*MODEL_SPACE'));
      expect(layout.modelSpaceHandle, isNonZero);
      expect(layout.firstEntity, 0);
      expect(layout.lastEntity, 0);
    });

    test('appends a LINE the reader can read back', () {
      final bytes = const R2000Appender().appendLine(
        x1: 0,
        y1: 0,
        x2: 21,
        y2: 13,
      );
      final drawing = DwgReader.readBytes(bytes);
      expect(drawing.version, 2000);
      expect(drawing.entities, hasLength(1));
      final line = drawing.entities.single;
      expect(line.typeName, 'LINE');
      expect(line.values, [0, 0, 0, 21, 13, 0]);
    });

    test('writes several entity types in one drawing', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.line(0, 0, 21, 13),
        R2000WriteItem.circle(50, 50, 10),
        R2000WriteItem.arc(80, 80, 20, 0, 1.5),
        R2000WriteItem.text(10, 30, 5, 0, 'Hello'),
        R2000WriteItem.lwPolyline([0, 0, 10, 0, 10, 10], closed: true),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      expect(drawing.entities, hasLength(5));
      expect(
        drawing.entities.map((entity) => entity.typeName),
        containsAll(['LINE', 'CIRCLE', 'ARC', 'TEXT', 'LWPOLYLINE']),
      );
      final text = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'TEXT',
      );
      expect(text.text, 'Hello');
    });

    test('writes CJK text as UTF-8 in DVW strings', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.text(0, 0, 2.5, 0, '开槽 工艺'),
        R2000WriteItem.mleader([
          [0.0, 0.0, 5.0, 5.0],
        ], r'{\F宋体|c134;注释}'),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      expect(
        drawing.entities.firstWhere((e) => e.typeName == 'TEXT').text,
        '开槽 工艺',
      );
      expect(
        drawing.entities.firstWhere((e) => e.typeName == 'MULTILEADER').text,
        r'{\F宋体|c134;注释}',
      );
    });

    test('writes a MULTILEADER class object', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.mleader(
          [
            [0.0, 0.0, 5.0, 5.0, 10.0, 10.0],
          ],
          'Hello MLeader',
          textX: 10,
          textY: 10,
          textHeight: 2.5,
          attachment: 4,
        ),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      final mleader = drawing.entities.single;
      expect(mleader.typeName, 'MULTILEADER');
      expect(mleader.text, 'Hello MLeader');
      expect(mleader.values[0], 10);
      expect(mleader.values[1], 10);
      expect(mleader.values[2], 2.5);
      expect(mleader.values[5], 3);
      expect(mleader.values.sublist(6), [0, 0, 5, 5, 10, 10]);
    });

    test('writes a WIPEOUT class object', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.wipeout(
          [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
          originX: 10,
          originY: 20,
          ux: 5,
          uy: 0,
          vx: 0,
          vy: 8,
        ),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      final wipeout = drawing.entities.single;
      expect(wipeout.typeName, 'WIPEOUT');
      expect(wipeout.values.sublist(0, 6), [10, 20, 5, 0, 0, 8]);
      expect(wipeout.values.sublist(8), [0, 0, 1, 0, 1, 1, 0, 1]);
    });

    test('writes point, solid, face, ellipse, spline and insert', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.point(1, 2),
        R2000WriteItem.solid([0, 0, 10, 0, 10, 10, 0, 10]),
        R2000WriteItem.face([0, 0, 10, 0, 5, 10, 5, 5]),
        R2000WriteItem.ellipse(20, 20, 10, 0, 0.5),
        R2000WriteItem.spline(
          knots: [0, 0, 0, 0, 1, 1, 1, 1],
          controlPoints: [0, 0, 10, 20, 20, 20, 30, 0],
        ),
        R2000WriteItem.insert(5, 5, '*MODEL_SPACE'),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      expect(drawing.entities, hasLength(6));
      expect(
        drawing.entities.map((entity) => entity.typeName),
        containsAll([
          'POINT',
          'SOLID',
          '3DFACE',
          'ELLIPSE',
          'SPLINE',
          'INSERT',
        ]),
      );

      final point = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'POINT',
      );
      expect(point.values.take(2), [1, 2]);
      expect(drawing.layerOf(point)?.name, '0');

      final face = drawing.entities.firstWhere(
        (entity) => entity.typeName == '3DFACE',
      );
      expect(face.values, [0, 0, 0, 10, 0, 0, 5, 10, 0, 5, 5, 0]);

      final ellipse = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'ELLIPSE',
      );
      expect(ellipse.values.take(7), [20, 20, 0, 10, 0, 0, 0.5]);

      final spline = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'SPLINE',
      );
      expect(spline.values.take(5), [3, 0, 8, 4, 0]);
      expect(spline.values.skip(14), [0, 0, 1, 10, 20, 1, 20, 20, 1, 30, 0, 1]);

      final insert = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'INSERT',
      );
      expect(insert.values, [5, 5, 0, 1, 1, 1, 0]);
      expect(drawing.blocks[insert.blockHandle]?.name, '*MODEL_SPACE');
    });

    test('writes text, attributes, leaders and construction lines', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.mtext(10, 10, 2.5, 0, 20, 'note'),
        R2000WriteItem.attrib(
          0,
          0,
          2.5,
          0,
          'value',
          'TAG',
          hAlign: 1,
          vAlign: 2,
          flags: 1,
        ),
        R2000WriteItem.attdef(
          1,
          1,
          2.5,
          0,
          'default',
          'TAG2',
          'Prompt?',
          flags: 2,
        ),
        R2000WriteItem.leader([0.0, 0.0, 5.0, 5.0], arrow: true),
        R2000WriteItem.ray(1, 2, 3, 4),
        R2000WriteItem.xline(5, 6, 7, 8),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      expect(
        drawing.entities.map((entity) => entity.typeName),
        containsAll(['MTEXT', 'ATTRIB', 'ATTDEF', 'LEADER', 'RAY', 'XLINE']),
      );
      final mtext = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'MTEXT',
      );
      expect(mtext.text, 'note');
      final attrib = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'ATTRIB',
      );
      expect(attrib.text, 'value');
      expect(attrib.tag, 'TAG');
      expect(attrib.attribFlags, 1);
      final attdef = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'ATTDEF',
      );
      expect(attdef.prompt, 'Prompt?');
      expect(attdef.attribFlags, 2);
    });

    test('writes LWPOLYLINE bulges and constant width', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.lwPolyline(
          [0, 0, 10, 0, 10, 10],
          closed: true,
          bulges: [0.5, -0.25, 0],
          constantWidth: 0.4,
        ),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      final polyline = drawing.entities.single;
      expect(polyline.typeName, 'LWPOLYLINE');
      final flag = polyline.values[1].toInt();
      expect(flag & 512, 512);
      expect(flag & 16, 16);
      expect(flag & 4, 4);
      expect(polyline.values.sublist(2 + 3 * 2, 2 + 3 * 2 + 3), [
        0.5,
        -0.25,
        0,
      ]);
      expect(polyline.values.last, 0.4);
    });

    test('writes solid and pattern HATCH boundaries', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.hatch([
          [0.0, 0.0, 10.0, 0.0, 10.0, 10.0, 0.0, 10.0],
        ]),
        R2000WriteItem.hatch(
          [
            [0.0, 0.0, 20.0, 0.0, 20.0, 10.0, 0.0, 10.0],
          ],
          solid: false,
          name: 'ANSI31',
          angle: 0.2,
          scale: 2,
          patternLines: const [
            [0.785, 0, 0, 0, 3.175, 0],
          ],
        ),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      final hatches = drawing.entities
          .where((entity) => entity.typeName == 'HATCH')
          .toList();
      expect(hatches, hasLength(2));
      expect(hatches[0].values[0], 1);
      expect(hatches[1].values[0], 0);
      expect(hatches[1].text.toUpperCase(), 'ANSI31');
    });

    test('writes IMAGE with an IMAGEDEF and REGION/3DSOLID ACIS text', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.image(10, 20, 30, 0, 0, 15, 'logo.png'),
        R2000WriteItem.region('700 0 1 0\n'),
        R2000WriteItem.region('700 0 1 0\n', solid: true),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      final image = drawing.entities.firstWhere(
        (entity) => entity.typeName == 'IMAGE',
      );
      expect(drawing.imageDefs[image.imageDefHandle], 'logo.png');
      expect(
        drawing.entities.where((entity) => entity.typeName == 'REGION'),
        hasLength(1),
      );
      expect(
        drawing.entities.where((entity) => entity.typeName == '3DSOLID'),
        hasLength(1),
      );
    });

    test('writes all seven fixed dimension families', () {
      final points = <int, List<double>>{
        0: [0, 0, 10, 0, 5, 5],
        1: [0, 0, 10, 0, 5, 5],
        2: [0, 0, 10, 0, 10, 10, 0, 10, 5, 5],
        3: [0, 0, 10, 0],
        4: [0, 0, 10, 0],
        5: [0, 0, 10, 0, 10, 10, 0, 10],
        6: [0, 0, 10, 0, 5, 5],
      };
      final bytes = const R2000Appender().appendItems([
        for (final entry in points.entries)
          R2000WriteItem.dimension(entry.key, entry.value, measurement: 10),
      ]);
      final drawing = DwgReader.readBytes(bytes);
      expect(
        drawing.entities.map((entity) => entity.typeName),
        containsAll([
          'DIMENSION_LINEAR',
          'DIMENSION_ALIGNED',
          'DIMENSION_ANG2LN',
          'DIMENSION_DIAMETER',
          'DIMENSION_RADIUS',
          'DIMENSION_ANG3PT',
          'DIMENSION_ORDINATE',
        ]),
      );
    });

    test('registers MULTILEADER and WIPEOUT classes densely', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.mleader([
          [0.0, 0.0, 5.0, 5.0],
        ], 'note'),
        R2000WriteItem.wipeout([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]),
      ]);
      final layout = R2000TemplateLayout.read(bytes);
      final section = layout.sections.firstWhere((entry) => entry.number == 1);
      final table = R2000ClassTable.read(bytes, section.address, section.size);
      final numbers = table.classes.map((entry) => entry.number).toList();
      expect(
        numbers,
        orderedEquals(List.generate(numbers.length, (i) => 500 + i)),
      );
      expect(table.numberNamed('MULTILEADER'), numbers[numbers.length - 2]);
      expect(table.numberNamed('WIPEOUT'), numbers.last);
    });

    test('writes a valid header CRC and handles-page CRC', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.line(0, 0, 21, 13),
        R2000WriteItem.circle(50, 50, 10),
      ]);
      final view = ByteData.sublistView(bytes);
      final sections = view.getUint32(0x15, Endian.little);
      final headerCrcAt = 0x19 + sections * 9;
      expect(
        view.getUint16(headerCrcAt, Endian.little),
        dwgCrc16(0xc0c1, bytes, 0, headerCrcAt),
      );

      var handlesAt = 0;
      var handlesSize = 0;
      for (var i = 0; i < sections; i++) {
        final at = 0x19 + i * 9;
        if (bytes[at] != 2) continue;
        handlesAt = view.getUint32(at + 1, Endian.little);
        handlesSize = view.getUint32(at + 5, Endian.little);
      }
      expect(handlesAt, isNonZero);
      final pageSize = view.getUint16(handlesAt, Endian.big);
      expect(pageSize, lessThanOrEqualTo(handlesSize));
      expect(
        view.getUint16(handlesAt + pageSize, Endian.big),
        dwgCrc16(0xc0c1, bytes, handlesAt, handlesAt + pageSize),
      );
    });

    test('creates layers and assigns each entity', () {
      final bytes = const R2000Appender().appendItems(
        [
          R2000WriteItem.line(0, 0, 21, 13).withLayer('Walls'),
          R2000WriteItem.circle(50, 50, 10).withLayer('Dims'),
          R2000WriteItem.text(10, 30, 5, 0, 'Hello').withLayer('Walls'),
        ],
        layerColors: {'Walls': 1, 'Dims': 2},
      );
      final drawing = DwgReader.readBytes(bytes);
      expect(
        drawing.layers.values.map((layer) => layer.name),
        containsAll(['0', 'Walls', 'Dims']),
      );
      expect(
        drawing.layers.values
            .firstWhere((layer) => layer.name == 'Walls')
            .colorIndex,
        1,
      );
      expect(drawing.layerOf(drawing.entities[0])?.name, 'Walls');
      expect(drawing.layerOf(drawing.entities[1])?.name, 'Dims');
      expect(drawing.layerOf(drawing.entities[2])?.name, 'Walls');
    });

    test('appends to an already written drawing', () {
      final first = const R2000Appender().appendItems([
        R2000WriteItem.line(0, 0, 1, 1).withLayer('A'),
      ]);
      final second = const R2000Appender().appendItems([
        R2000WriteItem.circle(2, 2, 1).withLayer('B'),
      ], template: first);
      final drawing = DwgReader.readBytes(second);
      expect(drawing.entities, hasLength(2));
      expect(drawing.layerOf(drawing.entities[0])?.name, 'A');
      expect(drawing.layerOf(drawing.entities[1])?.name, 'B');
    });

    test('relinks the model-space block header to the new entities', () {
      final bytes = const R2000Appender().appendItems([
        R2000WriteItem.line(0, 0, 21, 13),
        R2000WriteItem.circle(50, 50, 10),
      ]);
      final layout = R2000TemplateLayout.read(bytes);
      final drawing = DwgReader.readBytes(bytes);
      expect(layout.firstEntity, drawing.entities.first.handle);
      expect(layout.lastEntity, drawing.entities.last.handle);
    });

    test(
      'emits a valid empty R2000 template the reference decoder accepts',
      () {
        final bytes = const R2000Writer().writeEmptyTemplate();
        final drawing = DwgReader.readBytes(bytes);
        expect(drawing.version, 2000);
        expect(drawing.entities, isEmpty);
        expect(drawing.objectCount, greaterThan(0));
      },
    );
  });
}
