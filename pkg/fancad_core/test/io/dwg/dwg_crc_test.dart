import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/src/io/dwg/writer/dwg_crc.dart';
import 'package:test/test.dart';

void main() {
  group('DWG CRC-16', () {
    test('matches the CRC-16/ARC check value', () {
      final data = Uint8List.fromList(ascii.encode('123456789'));
      expect(dwgCrc16(0, data), 0xbb3d);
    });

    test('starts from the supplied seed', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final first = dwgCrc16(0xc0c1, data);
      final second = dwgCrc16(first, data);
      expect(first, isNot(second));
      expect(first, inInclusiveRange(0, 0xffff));
    });

    test('honours start and end offsets', () {
      final data = Uint8List.fromList([9, 1, 2, 3, 9]);
      expect(
        dwgCrc16(0, data, 1, 4),
        dwgCrc16(0, Uint8List.fromList([1, 2, 3])),
      );
    });

    test('an empty range returns the seed', () {
      expect(dwgCrc16(0xc0c1, Uint8List(0)), 0xc0c1);
      expect(dwgCrc16(0, Uint8List.fromList([1, 2])), isNot(0));
    });
  });
}
