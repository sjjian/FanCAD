import 'dart:typed_data';

/// MSB-first bit writer used by the DWG encoder. Kept bit-list based for
/// clarity while the writer is young; the public helpers mirror the reader.
final class DwgBitWriter {
  final List<int> _bits = [];

  int get bitLength => _bits.length;

  void writeBit(int value) => _bits.add(value & 1);

  void append(DwgBitWriter other) => _bits.addAll(other._bits);

  void umc(int value) {
    var copy = value;
    while (copy >= 0x80) {
      rc((copy & 0x7f) | 0x80);
      copy >>= 7;
    }
    rc(copy & 0x7f);
  }

  void mc(int value) {
    var copy = value.abs();
    final bytes = <int>[];
    do {
      bytes.add(copy & 0x7f);
      copy >>= 7;
    } while (copy > 0);
    if ((bytes.last & 0x40) != 0) bytes.add(0);
    for (var i = 0; i < bytes.length; i++) {
      final last = i == bytes.length - 1;
      var byte = bytes[i];
      if (!last) byte |= 0x80;
      if (last && value < 0) byte |= 0x40;
      rc(byte);
    }
  }

  void writeBits(int value, int count) {
    for (var i = count - 1; i >= 0; i--) {
      _bits.add((value >> i) & 1);
    }
  }

  void patchBits(int at, int value, int count) {
    for (var i = 0; i < count; i++) {
      _bits[at + i] = (value >> (count - 1 - i)) & 1;
    }
  }

  void b(bool value) => writeBit(value ? 1 : 0);
  void bb(int value) => writeBits(value, 2);
  void rc(int value) => writeBits(value & 0xff, 8);

  void rs(int value) {
    rc(value & 0xff);
    rc((value >> 8) & 0xff);
  }

  void rl(int value) {
    rs(value & 0xffff);
    rs((value >> 16) & 0xffff);
  }

  /// Patches an RL already written at [at] (two little-endian RS words).
  void patchRl(int at, int value) {
    for (var i = 0; i < 2; i++) {
      patchBits(at + i * 8, (value >> (i * 8)) & 0xff, 8);
    }
    for (var i = 0; i < 2; i++) {
      patchBits(at + 16 + i * 8, (value >> (16 + i * 8)) & 0xff, 8);
    }
  }

  void rd(double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.little);
    for (var i = 0; i < 8; i++) {
      rc(data.getUint8(i));
    }
  }

  void bs(int value) {
    if (value == 0) {
      bb(2);
    } else if (value == 256) {
      bb(3);
    } else if (value < 256) {
      bb(1);
      rc(value);
    } else {
      bb(0);
      rs(value);
    }
  }

  void bl(int value) {
    if (value == 0) {
      bb(2);
    } else if (value == 256) {
      bb(3);
    } else if (value < 256) {
      bb(1);
      rc(value);
    } else {
      bb(0);
      rl(value);
    }
  }

  void bd(double value) {
    if (value == 0) {
      bb(2);
    } else if (value == 1) {
      bb(1);
    } else {
      bb(0);
      rd(value);
    }
  }

  void dd(double value, double fallback) {
    if (value == fallback) {
      bb(0);
    } else {
      bb(3);
      rd(value);
    }
  }

  void bt(double value) {
    b(value == 0);
    if (value != 0) bd(value);
  }

  void be(double x, double y, double z) {
    final isDefault = x == 0 && y == 0 && z == 1;
    b(isDefault);
    if (!isDefault) {
      bd(x);
      bd(y);
      bd(z);
    }
  }

  void h(int value, {int code = 0}) {
    var size = 0;
    var copy = value;
    while (copy != 0) {
      size++;
      copy >>= 8;
    }
    rc((code << 4) | size);
    for (var i = size - 1; i >= 0; i--) {
      rc((value >> (i * 8)) & 0xff);
    }
  }

  void ms(int value) {
    if (value < 0x8000) {
      rs(value);
    } else {
      rs((value & 0x7fff) | 0x8000);
      rs((value >> 15) & 0x7fff);
    }
  }

  Uint8List finish() {
    final bytes = Uint8List((_bits.length + 7) >> 3);
    for (var i = 0; i < _bits.length; i++) {
      if (_bits[i] != 0) bytes[i >> 3] |= 1 << (7 - (i & 7));
    }
    return bytes;
  }
}
