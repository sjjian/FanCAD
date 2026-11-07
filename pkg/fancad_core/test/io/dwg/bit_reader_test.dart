import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/src/io/dwg/bit_reader.dart';
import 'package:fancad_core/src/io/dwg/writer/bit_writer.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:test/test.dart';

Uint8List _encoded(void Function(DwgBitWriter writer) build) {
  final writer = DwgBitWriter();
  build(writer);
  return writer.finish();
}

void main() {
  setUp(() => DwgBitReader.defaultCodepage = 0);
  tearDown(() => DwgBitReader.defaultCodepage = 0);

  group('DwgBitReader primitives', () {
    test('reads fixed-width integers', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.rc(0x12);
          w.rs(0x3456);
          w.rl(0x789abcde);
        }),
      );
      expect(reader.rc(), 0x12);
      expect(reader.rs(), 0x3456);
      expect(reader.rl(), 0x789abcde);
      expect(reader.ok, isTrue);
    });

    test('readBytes copies a byte-aligned window', () {
      final bytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      final reader = DwgBitReader(bytes)..bitPos = 8;
      expect(reader.readBytes(2), [0x34, 0x56]);
      expect(reader.bitPos, 24);
      expect(reader.ok, isTrue);
    });

    test('readBytes copies across a non-byte-aligned window', () {
      final bytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc]);
      final reader = DwgBitReader(bytes)..bitPos = 4;
      expect(reader.readBytes(3), [0x23, 0x45, 0x67]);
      expect(reader.bitPos, 28);
      expect(reader.ok, isTrue);
    });

    test('reads BS variants', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bs(0);
          w.bs(256);
          w.bs(7);
          w.bs(300);
        }),
      );
      expect(reader.bs(), 0);
      expect(reader.bs(), 256);
      expect(reader.bs(), 7);
      expect(reader.bs(), 300);
    });

    test('reads BL variants', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bl(0);
          w.bl(256);
          w.bl(19);
          w.bl(70000);
        }),
      );
      expect(reader.bl(), 0);
      expect(reader.bl(), 256);
      expect(reader.bl(), 19);
      expect(reader.bl(), 70000);
    });

    test('reads BD, DD, BT and BE', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bd(0);
          w.bd(1);
          w.bd(0.25);
          w.dd(0.5, 0.5);
          w.dd(-3.75, 0.5);
          w.bt(0);
          w.bt(2.5);
          w.be(0, 0, 1);
          w.be(0, 0, -1);
          w.be(1, 2, 3);
        }),
      );
      expect(reader.bd(), 0);
      expect(reader.bd(), 1);
      expect(reader.bd(), 0.25);
      expect(reader.dd(0.5), 0.5);
      expect(reader.dd(0.5), -3.75);
      expect(reader.bt(), 0);
      expect(reader.bt(), 2.5);
      expect(reader.be(), [0, 0, 1]);
      expect(reader.be(), [0, 0, -1]);
      expect(reader.be(), [1, 2, 3]);
    });

    test('reads MS sizes below and above 15 bits', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.ms(0x7fff);
          w.ms(0x8000);
          w.ms(0x123456);
        }),
      );
      expect(reader.ms(), 0x7fff);
      expect(reader.ms(), 0x8000);
      expect(reader.ms(), 0x123456);
    });

    test('reads UMC and signed MC deltas', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.umc(0);
          w.umc(127);
          w.umc(300);
          w.mc(0);
          w.mc(63);
          w.mc(-63);
          w.mc(123456);
          w.mc(-123456);
        }),
      );
      expect(reader.umc(), 0);
      expect(reader.umc(), 127);
      expect(reader.umc(), 300);
      expect(reader.mc(), 0);
      expect(reader.mc(), 63);
      expect(reader.mc(), -63);
      expect(reader.mc(), 123456);
      expect(reader.mc(), -123456);
    });

    test('reads H handles with their code', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.h(0);
          w.h(0x1234, code: 5);
          w.h(0x123456789abc, code: 4);
        }),
      );
      expect(reader.h(), 0);
      expect(reader.h(), 0x1234);
      expect(reader.hCode, 5);
      expect(reader.h(), 0x123456789abc);
      expect(reader.hCode, 4);
    });

    test('reads BOT and BLL', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bb(0);
          w.rc(0x42);
          w.bb(1);
          w.rc(0x21);
          w.bb(2);
          w.rs(0x1234);
          w.bb(0);
          w.b(true);
          w.rc(0x56);
          w.bb(1);
          w.b(false);
          w.rs(0x789a);
        }),
      );
      expect(reader.bot(), 0x42);
      expect(reader.bot(), 0x21 + 0x1f0);
      expect(reader.bot(), 0x1234);
      expect(reader.bll(), 0x56);
      expect(reader.bll(), 0x789a);
    });
  });

  group('DwgBitReader strings', () {
    test('decodes ASCII and UTF-8', () {
      final reader = DwgBitReader(
        _encoded((w) {
          void tv(List<int> bytes) {
            w.bs(bytes.length);
            for (final byte in bytes) {
              w.rc(byte);
            }
          }

          tv(ascii.encode('Standard'));
          tv(utf8.encode('开槽 工艺'));
        }),
      );
      expect(reader.tv(), 'Standard');
      expect(reader.tv(), '开槽 工艺');
    });

    test('decodes GBK layer names', () {
      DwgBitReader.defaultCodepage = 39;
      final bytes = gbk_bytes.encode('粗实线');
      final reader = DwgBitReader(
        _encoded((w) {
          w.bs(bytes.length);
          for (final byte in bytes) {
            w.rc(byte);
          }
        }),
      );
      expect(reader.tv(), '粗实线');
    });

    test('decodes GBK Greek without requiring a CJK character', () {
      DwgBitReader.defaultCodepage = 39;
      final bytes = gbk_bytes.encode('Φ');
      final reader = DwgBitReader(
        _encoded((w) {
          w.bs(bytes.length);
          for (final byte in bytes) {
            w.rc(byte);
          }
        }),
      );
      expect(reader.tv(), 'Φ');
    });

    test('expands AutoCAD \\U+ text escapes', () {
      final reader = DwgBitReader(
        _encoded((w) {
          final bytes = latin1.encode(r'Ø\U+2205 25');
          w.bs(bytes.length);
          for (final byte in bytes) {
            w.rc(byte);
          }
        }),
      );
      expect(reader.tv(), 'Ø∅ 25');
    });

    test('falls back to Latin-1 when the bytes are not CJK', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bs(4);
          for (final byte in [0x43, 0x61, 0x66, 0xe9]) {
            w.rc(byte);
          }
        }),
      );
      expect(reader.tv(), 'Café');
    });

    test('stops at a terminating NUL', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bs(4);
          for (final byte in ascii.encode('A\x00BC')) {
            w.rc(byte);
          }
        }),
      );
      expect(reader.tv(), 'A');
    });
  });

  group('DwgBitReader bounds', () {
    test('marks the reader invalid past the end', () {
      final reader = DwgBitReader(Uint8List(1));
      expect(reader.rc(), 0);
      expect(reader.ok, isTrue);
      expect(reader.rc(), 0);
      expect(reader.ok, isFalse);
    });

    test('skip past the end marks the reader invalid', () {
      final reader = DwgBitReader(Uint8List(2));
      reader.skip(17);
      expect(reader.ok, isFalse);
    });

    test('honours limitBits', () {
      final reader = DwgBitReader(Uint8List(4), limitBits: 16);
      expect(reader.rs(), 0);
      expect(reader.ok, isTrue);
      expect(reader.rs(), 0);
      expect(reader.ok, isFalse);
    });

    test('a zero-length string does not move the stream', () {
      final reader = DwgBitReader(
        _encoded((w) {
          w.bs(0);
          w.rc(0x7e);
        }),
      );
      expect(reader.tv(), '');
      expect(reader.rc(), 0x7e);
    });
  });
}
