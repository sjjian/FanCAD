import 'dart:typed_data';

import 'package:fancad_core/src/io/dwg/bit_reader.dart';
import 'package:fancad_core/src/io/dwg/writer/bit_writer.dart';
import 'package:test/test.dart';

void main() {
  group('DwgBitWriter', () {
    test('round-trips every basic field through the reader', () {
      final writer = DwgBitWriter()
        ..b(true)
        ..bb(2)
        ..rc(0xab)
        ..rs(0x1234)
        ..rl(0x89abcdef)
        ..bs(0)
        ..bs(256)
        ..bs(7)
        ..bs(300)
        ..bl(70000)
        ..bd(0.25)
        ..bt(2.5)
        ..be(1, 2, 3)
        ..h(0x1234, code: 5)
        ..ms(0x123456);
      final reader = DwgBitReader(writer.finish());
      expect(reader.b(), 1);
      expect(reader.bb(), 2);
      expect(reader.rc(), 0xab);
      expect(reader.rs(), 0x1234);
      expect(reader.rl(), 0x89abcdef);
      expect(reader.bs(), 0);
      expect(reader.bs(), 256);
      expect(reader.bs(), 7);
      expect(reader.bs(), 300);
      expect(reader.bl(), 70000);
      expect(reader.bd(), 0.25);
      expect(reader.bt(), 2.5);
      expect(reader.be(), [1, 2, 3]);
      expect(reader.h(), 0x1234);
      expect(reader.hCode, 5);
      expect(reader.ms(), 0x123456);
      expect(reader.ok, isTrue);
    });

    test('append keeps the bit stream contiguous', () {
      final first = DwgBitWriter()..rc(0x12);
      final second = DwgBitWriter()..rc(0x34);
      first.append(second);
      final reader = DwgBitReader(first.finish());
      expect(reader.rc(), 0x12);
      expect(reader.rc(), 0x34);
    });

    test('patchBits and patchRl overwrite in place', () {
      final writer = DwgBitWriter()
        ..rc(0)
        ..rl(0);
      writer.patchBits(0, 0x5a, 8);
      writer.patchRl(8, 0x12345678);
      final reader = DwgBitReader(writer.finish());
      expect(reader.rc(), 0x5a);
      expect(reader.rl(), 0x12345678);
    });

    test('finish pads the last byte with zero bits', () {
      final writer = DwgBitWriter()..b(true);
      expect(writer.bitLength, 1);
      expect(writer.finish(), Uint8List.fromList([0x80]));
    });

    test('MS uses one or two 15-bit words', () {
      final writer = DwgBitWriter()
        ..ms(0x7fff)
        ..ms(0x8000)
        ..ms(0x123456);
      final reader = DwgBitReader(writer.finish());
      expect(reader.ms(), 0x7fff);
      expect(reader.ms(), 0x8000);
      expect(reader.ms(), 0x123456);
    });
  });
}
