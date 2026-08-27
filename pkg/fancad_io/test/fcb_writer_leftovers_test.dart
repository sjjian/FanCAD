import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('an empty document cannot invent entities on a write-read trip', () {
    final encoded = FcbWriter().write(CadDocument());
    final view = ByteData.sublistView(encoded);
    expect(view.getUint32(0, Endian.little), fcbMagic);
    expect(view.getUint16(4, Endian.little), fcbVersion);

    final result = FcbReader(encoded).decode();
    expect(result.entityCount, 0);
    expect(result.document.entityCount, 0);
    expect(result.diagnostics, isEmpty);
    expect(result.toString(), contains('0 entities'));
  });

  test('a second write of the empty drawing stays byte identical', () {
    final first = FcbWriter().write(CadDocument());
    final second = FcbWriter().write(FcbReader(first).decode().document);
    expect(second, first);
  });

  test('dimension source ids survive a write-read trip', () {
    final document = CadDocument();
    document.addEntity(
      const DimensionEntity(
        id: 1,
        definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
        textPosition: Vec2(5, 3),
        measurement: 10,
        sourceIds: [7, 8],
      ),
    );
    final restored = FcbReader(FcbWriter().write(document)).decode().document;
    final dim = restored.entity(1)! as DimensionEntity;
    expect(dim.sourceIds, [7, 8]);
    expect(dim.measurement, 10);
  });

  test('attdef and insert attributes survive a write-read trip', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'TITLE', entityIds: []));
    document.addEntity(
      const AttdefEntity(
        id: 1,
        position: Vec2(2, 3),
        tag: 'NO',
        prompt: 'Number',
        defaultValue: 'A-00',
        height: 3,
        constant: true,
      ),
      blockName: 'TITLE',
    );
    document.addEntity(
      const InsertEntity(
        id: 2,
        blockName: 'TITLE',
        position: Vec2(10, 0),
        attributes: {'NO': 'A-01'},
      ),
    );
    final restored = FcbReader(FcbWriter().write(document)).decode().document;
    final def = restored.entity(1)! as AttdefEntity;
    expect(def.tag, 'NO');
    expect(def.prompt, 'Number');
    expect(def.defaultValue, 'A-00');
    expect(def.constant, isTrue);
    final insert = restored.entity(2)! as InsertEntity;
    expect(insert.attributes, {'NO': 'A-01'});
  });
}
