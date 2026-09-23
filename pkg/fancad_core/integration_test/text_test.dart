@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG text', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('right-top TEXT stays off the origin', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          TextEntity(
            id: 1,
            position: const Vec2(250, 180),
            content: 'right',
            height: 4,
            hAlign: TextHAlign.right,
            vAlign: TextVAlign.top,
          ),
        ),
        name: 'textright',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.content, 'right');
      expect(text.position.x, closeTo(250, 1e-6));
      expect(text.position.y, closeTo(180, 1e-6));
      expect(text.hAlign, TextHAlign.right);
      expect(text.vAlign, TextVAlign.top);
    });

    test('rotated TEXT keeps its angle', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2(12, 8),
            content: 'tilt',
            height: 3,
            rotation: 0.4,
          ),
        ),
        name: 'textrot',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.content, 'tilt');
      expect(text.rotation, closeTo(0.4, 1e-6));
      expect(text.position.x, closeTo(12, 1e-6));
    });

    test('TEXT keeps width factor and oblique angle', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2(4, 5),
            content: 'oblique',
            height: 3,
            widthFactor: 0.75,
            obliqueAngle: 0.2,
          ),
        ),
        name: 'textwf',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.widthFactor, closeTo(0.75, 1e-6));
      expect(text.obliqueAngle, closeTo(0.2, 1e-6));
    });

    test('bottom-left TEXT stays at its insertion point', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          TextEntity(
            id: 1,
            position: const Vec2(30, 40),
            content: 'bl',
            height: 3,
            hAlign: TextHAlign.left,
            vAlign: TextVAlign.bottom,
          ),
        ),
        name: 'textbl',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.position.x, closeTo(30, 1e-6));
      expect(text.position.y, closeTo(40, 1e-6));
      expect(text.vAlign, TextVAlign.bottom);
    });

    test('TEXT inside a named block stays in that block', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'LABEL'))
        ..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2.zero(),
            content: 'inside',
            height: 2,
          ),
          blockName: 'LABEL',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'LABEL', position: Vec2(12, 0)),
        );
      final opened = await rt.dwg(source, name: 'blktext');
      expectMatchingSnapshots(source, opened, step: 'block text');
      expect(
        opened.entitiesOf('LABEL').whereType<TextEntity>().single.content,
        'inside',
      );
    });

    eachCase(
      [
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
      ],
      (c) {
        final tu = _encodeUcs2Le(c.note);
        c.check(tu, c.note);
      },
    );

    test(
      'an ASCII-leading UCS-2 field is recognized without a DWG version',
      () {
        final tu = _encodeUcs2Le(r'{\F宋体|c134;注释}');
        expect(tu[0], 0x7B);
        expect(tu[1], 0);
        expect(_looksLikeUcs2(tu), isTrue);
        expect(_looksLikeUcs2(r'{\F宋体|c134;注释}'.codeUnits), isFalse);
      },
    );
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
