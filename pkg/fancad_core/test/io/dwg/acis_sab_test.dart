import 'dart:typed_data';

import 'package:fancad_core/src/io/dwg/acis_sab.dart';
import 'package:test/test.dart';

void main() {
  test('sabToSat1 reads tag 18 long transform strings', () {
    final bytes = <int>[];
    void rc(int v) => bytes.add(v & 0xff);
    void rs(int v) {
      bytes.add(v & 0xff);
      bytes.add((v >> 8) & 0xff);
    }

    void rl(int v) {
      rs(v & 0xffff);
      rs((v >> 16) & 0xffff);
    }

    void rd(double v) {
      final data = ByteData(8)..setFloat64(0, v, Endian.little);
      bytes.addAll(data.buffer.asUint8List());
    }

    void tagged(String text) {
      rc(13);
      rc(text.length);
      bytes.addAll(text.codeUnits);
    }

    bytes.addAll('ACIS BinaryFile'.codeUnits);
    rl(20800);
    rl(1);
    rl(1);
    rl(0);
    tagged('product');
    tagged('208.0');
    tagged('date');
    rc(0);
    rd(0);
    rc(0);
    rd(0);
    rc(0);
    rd(0);
    rc(13);
    rc('transform'.length);
    bytes.addAll('transform'.codeUnits);
    rc(18);
    final transform = '1 0 0 1 0 0';
    rl(transform.length);
    bytes.addAll(transform.codeUnits);
    rc(17); // end of record
    rc(13);
    rc(0); // end of stream

    final sat = sabToSat1(Uint8List.fromList(bytes));
    expect(sat, isNotNull);
    expect(sat, contains('transform $transform'));
  });
}
