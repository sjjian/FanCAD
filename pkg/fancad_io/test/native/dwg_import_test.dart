@Tags(['native'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../support/roundtrip.dart';

void main() {
  group('UCS-2 text', () {
    eachCase([
      (
        name: 'a UCS-2 MTEXT brace is not a C-string terminator',
        note: r'{\F宋体|c134;注释}',
        check: (Uint8List tu, String note) {
          expect(String.fromCharCodes(_cStringBytes(tu)), '{');
          expect(_decodeUcs2Le(tu), note);
        },
      ),
      (
        name: 'a CJK-only UCS-2 note survives the wide-string walk',
        note: '注释',
        check: (Uint8List tu, String note) {
          expect(String.fromCharCodes(_cStringBytes(tu)), isNot(note));
          expect(_decodeUcs2Le(tu), note);
        },
      ),
    ], (c) {
      final tu = _encodeUcs2Le(c.note);
      c.check(tu, c.note);
    });

    test('an ASCII-leading UCS-2 field is recognized without a DWG version', () {
      final tu = _encodeUcs2Le(r'{\F宋体|c134;注释}');
      expect(tu[0], 0x7B);
      expect(tu[1], 0);
      expect(_looksLikeUcs2(tu), isTrue);
      expect(_looksLikeUcs2(r'{\F宋体|c134;注释}'.codeUnits), isFalse);
    });
  });

  group('ownership fields', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip()..requireDwg();
    });

    test(
      'a title-block INSERT stays in model space beside an overlapping *D',
      () async {
        const dimLayer = EntityProps(layer: '标注线');
        final source = drawing(
          layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
          blocks: const [
            BlockRecord(name: 'bk'),
            BlockRecord(name: '*D1', isAnonymous: true),
          ],
          entities: [
            const InsertEntity(id: 4, blockName: 'bk', position: Vec2.zero()),
            const DimensionEntity(
              id: 5,
              props: dimLayer,
              blockName: '*D1',
              measurement: 10,
              definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 4)],
              textPosition: Vec2(5, 8),
            ),
            LeaderEntity(
              id: 6,
              vertices: Float64List.fromList([0, 20, 12, 28]),
            ),
            HatchEntity(
              id: 7,
              loops: [
                HatchLoop(
                  vertices: Float64List.fromList([40, 0, 50, 0, 50, 10, 40, 10]),
                ),
              ],
            ),
          ],
          owned: const {
            'bk': [
              LineEntity(id: 1, start: Vec2.zero(), end: Vec2(80, 0)),
              LineEntity(id: 2, start: Vec2.zero(), end: Vec2(0, 40)),
              MTextEntity(
                id: 3,
                position: Vec2(10, 10),
                content: 'XDFB-J15',
                height: 2.5,
              ),
            ],
            '*D1': [
              LineEntity(
                id: 10,
                props: dimLayer,
                start: Vec2.zero(),
                end: Vec2(10, 0),
              ),
            ],
          },
        );

        final opened = await rt.dwg(source, name: 'title');
        final insert = opened.entities.whereType<InsertEntity>().singleWhere(
          (entity) => entity.blockName == 'bk',
        );
        expectOwner(opened, insert, opened.modelSpaceBlockName);

        for (final entity in opened.entities.whereType<InsertEntity>()) {
          if (entity.blockName != 'bk') continue;
          final owner = opened.ownerOf(entity.id) ?? '';
          expect(owner.startsWith('*D'), isFalse);
        }

        for (final entity in opened.entities) {
          if (entity is! LeaderEntity && entity is! HatchEntity) continue;
          final owner = opened.ownerOf(entity.id) ?? '';
          expect(
            owner.startsWith('*D'),
            isFalse,
            reason: '${entity.kind}#${entity.id}',
          );
        }
      },
      timeout: Roundtrip.timeout,
    );

    test('two DIMENSION entities keep distinct *D blocks', () async {
      const dimLayer = EntityProps(layer: '标注线');
      final source = drawing(
        layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
        blocks: const [
          BlockRecord(name: '*D1', isAnonymous: true),
          BlockRecord(name: '*D2', isAnonymous: true),
        ],
        entities: const [
          DimensionEntity(
            id: 1,
            props: dimLayer,
            blockName: '*D1',
            measurement: 10,
            definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 4)],
            textPosition: Vec2(5, 8),
          ),
          DimensionEntity(
            id: 2,
            props: dimLayer,
            blockName: '*D2',
            measurement: 20,
            definitionPoints: [Vec2(30, 0), Vec2(50, 0), Vec2(40, 4)],
            textPosition: Vec2(40, 8),
          ),
        ],
        owned: const {
          '*D1': [
            LineEntity(
              id: 3,
              props: dimLayer,
              start: Vec2.zero(),
              end: Vec2(10, 0),
            ),
          ],
          '*D2': [
            LineEntity(
              id: 4,
              props: dimLayer,
              start: Vec2(30, 0),
              end: Vec2(50, 0),
            ),
          ],
        },
      );

      final opened = await rt.dwg(source, name: 'twodim');
      final dims = opened.entities.whereType<DimensionEntity>().toList();
      expect(dims, hasLength(2));
      expect(dims[0].blockName, isNotEmpty);
      expect(dims[1].blockName, isNot(dims[0].blockName));
    }, timeout: Roundtrip.timeout);

    test(
      'an unreferenced *D does not take model-space leaders',
      () async {
        final source = drawing(
          blocks: const [BlockRecord(name: '*D9', isAnonymous: true)],
          entities: [
            LeaderEntity(
              id: 1,
              vertices: Float64List.fromList([0, 20, 12, 28]),
            ),
          ],
          owned: const {
            '*D9': [
              LineEntity(id: 2, start: Vec2(100, 100), end: Vec2(110, 100)),
            ],
          },
        );

        final opened = await rt.dwg(source, name: 'orphand');
        final leader = opened.entities.whereType<LeaderEntity>().single;
        expectOwner(opened, leader, opened.modelSpaceBlockName);
        final referenced = {
          for (final entity in opened.entities)
            if (entity is DimensionEntity && entity.blockName.isNotEmpty)
              entity.blockName,
        };
        expect(referenced, isEmpty);
        expect(
          opened.entitiesOf(opened.modelSpaceBlockName).whereType<LeaderEntity>(),
          isNotEmpty,
        );
      },
      timeout: Roundtrip.timeout,
    );
  });

  group('REGION SAT', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip()..requireDwg();
    });

    test('a REGION keeps SAT loops instead of one scribble', () async {
      final outer = _ring(126, 96.5, 126, 96.5);
      final inner = _ring(126, 96.5, 40, 30);
      final source = drawingOf(
        UnknownEntity(
          id: 1,
          originalType: 'REGION',
          strokes: Float64List.fromList([...outer, ...inner]),
          strokeCounts: [outer.length ~/ 2, inner.length ~/ 2],
        ),
      );

      final opened = await rt.dwg(source, name: 'region');
      final region = opened.entities.whereType<UnknownEntity>().single;
      expect(region.originalType, 'REGION');
      expect(region.strokeCounts, hasLength(2));
      expect(region.strokeCounts.every((count) => count >= 8), isTrue);
      expect(region.strokeCounts, isNot(equals([56])));
    }, timeout: Roundtrip.timeout);
  });
}

/// Matches `dwg_text_is_ucs2` in dwg_import.c: first ASCII unit is `c, 0`.
bool _looksLikeUcs2(List<int> raw) =>
    raw.isNotEmpty && raw.first != 0 && raw.length > 1 && raw[1] == 0;

/// Matches `ucs2le_to_utf8` in dwg_import.c.
String _decodeUcs2Le(List<int> src) {
  final codes = <int>[];
  var i = 0;
  while (i + 1 < src.length) {
    final cp = src[i] | (src[i + 1] << 8);
    i += 2;
    if (cp == 0) break;
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < src.length) {
      final lo = src[i] | (src[i + 1] << 8);
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        codes.add(0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00));
        i += 2;
        continue;
      }
    }
    codes.add(cp);
  }
  return String.fromCharCodes(codes);
}

Uint8List _encodeUcs2Le(String text) {
  final out = BytesBuilder();
  for (final cp in text.runes) {
    if (cp <= 0xFFFF) {
      out.addByte(cp & 0xFF);
      out.addByte((cp >> 8) & 0xFF);
      continue;
    }
    final x = cp - 0x10000;
    final hi = 0xD800 + (x >> 10);
    final lo = 0xDC00 + (x & 0x3FF);
    out.addByte(hi & 0xFF);
    out.addByte((hi >> 8) & 0xFF);
    out.addByte(lo & 0xFF);
    out.addByte((lo >> 8) & 0xFF);
  }
  out.addByte(0);
  out.addByte(0);
  return out.toBytes();
}

List<int> _cStringBytes(List<int> src) {
  final end = src.indexOf(0);
  return src.sublist(0, end < 0 ? src.length : end);
}

Float64List _ring(double cx, double cy, double rx, double ry) {
  const n = 8;
  final xy = <double>[];
  for (var i = 0; i < n; i++) {
    final angle = i / n * math.pi * 2;
    xy
      ..add(cx + rx * math.cos(angle))
      ..add(cy + ry * math.sin(angle));
  }
  xy
    ..add(xy[0])
    ..add(xy[1]);
  return Float64List.fromList(xy);
}
