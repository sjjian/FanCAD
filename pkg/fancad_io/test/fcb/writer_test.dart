import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../support/roundtrip.dart';

void main() {
  final rt = Roundtrip();

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
    final restored = rt.fcb(
      drawing(
        entities: const [
          DimensionEntity(
            id: 1,
            definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
            textPosition: Vec2(5, 3),
            measurement: 10,
            sourceIds: [7, 8],
          ),
        ],
      ),
    );
    final dim = restored.entity(1)! as DimensionEntity;
    expect(dim.sourceIds, [7, 8]);
    expect(dim.measurement, 10);
  });

  test('attdef and insert attributes survive a write-read trip', () {
    final restored = rt.fcb(
      drawing(
        blocks: const [BlockRecord(name: 'TITLE')],
        entities: const [
          InsertEntity(
            id: 2,
            blockName: 'TITLE',
            position: Vec2(10, 0),
            attributes: {'NO': 'A-01'},
          ),
        ],
        owned: const {
          'TITLE': [
            AttdefEntity(
              id: 1,
              position: Vec2(2, 3),
              tag: 'NO',
              prompt: 'Number',
              defaultValue: 'A-00',
              height: 3,
              constant: true,
            ),
          ],
        },
      ),
    );
    final def = restored.entity(1)! as AttdefEntity;
    expect(def.tag, 'NO');
    expect(def.prompt, 'Number');
    expect(def.defaultValue, 'A-00');
    expect(def.constant, isTrue);
    final insert = restored.entity(2)! as InsertEntity;
    expect(insert.attributes, {'NO': 'A-01'});
  });

  test('a distant _Oblique definition reseats onto its geometry', () {
    final restored = rt.fcb(
      drawing(
        blocks: const [BlockRecord(name: '_Oblique')],
        entities: const [
          InsertEntity(
            id: 2,
            blockName: '_Oblique',
            position: Vec2(10, 20),
            scale: Vec2(15, 15),
          ),
        ],
        owned: const {
          '_Oblique': [
            LineEntity(
              id: 1,
              start: Vec2(161481, -377618),
              end: Vec2(161481, -378589),
            ),
          ],
        },
      ),
    );
    final base = restored.blocks['_Oblique']!.basePoint;
    expect(base.x, closeTo(161481, 1));
    expect(base.y, closeTo(-378589, 1));
    expect(restored.extents.minX, closeTo(10, 1));
    expect(restored.extents.maxX, lessThan(100));
  });

  test('anonymous dimension blocks with distinct names all survive FCB', () {
    final restored = rt.fcb(
      drawing(
        blocks: const [
          BlockRecord(name: '*D\$aa', isAnonymous: true),
          BlockRecord(name: '*D\$bb', isAnonymous: true),
        ],
        entities: const [
          DimensionEntity(
            id: 3,
            blockName: '*D\$aa',
            textPosition: Vec2(5, 2),
            measurement: 10,
          ),
          DimensionEntity(
            id: 4,
            blockName: '*D\$bb',
            textPosition: Vec2(25, 2),
            measurement: 10,
          ),
        ],
        owned: const {
          '*D\$aa': [
            LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ],
          '*D\$bb': [
            LineEntity(id: 2, start: Vec2(20, 0), end: Vec2(30, 0)),
          ],
        },
      ),
    );
    expect(restored.blocks['*D\$aa']?.entityIds, [1]);
    expect(restored.blocks['*D\$bb']?.entityIds, [2]);
    expect(
      restored.entities.whereType<DimensionEntity>().map((d) => d.blockName),
      containsAll(['*D\$aa', '*D\$bb']),
    );
  });

  eachCase([
    (
      name: 'a multileader survives FCB with its note attached',
      content: 'QC50',
      height: 3.0,
      attachment: 4,
      painted: 'QC50',
      fontFamily: null,
    ),
    (
      name: 'a CJK font-coded note stays attached through FCB',
      content: r'{\F宋体|c134;注释}',
      height: 35.0,
      attachment: 6,
      painted: '注释',
      fontFamily: '宋体',
    ),
  ], (c) {
    final entity = rt
        .fcb(
          drawingOf(
            MLeaderEntity(
              id: 1,
              vertices: Float64List.fromList([0, 0, 8, 8, 14, 8]),
              content: c.content,
              textPosition: const Vec2(14, 8),
              textHeight: c.height,
              attachment: c.attachment,
            ),
          ),
        )
        .entities
        .whereType<MLeaderEntity>()
        .single;
    expect(entity.content, c.content);
    expect(entity.content, isNot('{'));
    expect(entity.textPosition, const Vec2(14, 8));
    expect(entity.vertices.length, 6);
    expect(entity.attachment, c.attachment);
    final sink = emit(entity);
    expect(sink.texts.single.text, c.painted);
    if (c.fontFamily != null) {
      expect(sink.texts.single.fontFamily, c.fontFamily);
    }
  });

  test('unknown fallback strokes survive FCB', () {
    final entity = rt
        .fcb(
          drawingOf(
            UnknownEntity(
              id: 2,
              originalType: 'REGION',
              proxyBounds: const Bounds2(0, 0, 4, 3),
              strokes: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3]),
              strokeCounts: const [4],
            ),
          ),
        )
        .entities
        .whereType<UnknownEntity>()
        .single;
    expect(entity.originalType, 'REGION');
    expect(entity.strokes.length, 8);
    expect(entity.strokeCounts, const [4]);
    expect(emit(entity).polylines, isNotEmpty);
  });
}
