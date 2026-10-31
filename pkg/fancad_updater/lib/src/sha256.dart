import 'dart:convert';
import 'dart:typed_data';

/// SHA-256, in house.
///
/// The updater refuses to install bytes it cannot hash, and adding a package
/// just for one digest would put a dependency between the user and every
/// future update. Streaming is supported so a 100 MB installer never has to be
/// held in memory.
class Sha256 {
  Sha256() : _state = Uint32List.fromList(_initialState);

  static const List<int> _initialState = [
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];

  static const List<int> _roundConstants = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  final Uint32List _state;
  final Uint8List _block = Uint8List(64);
  final Uint32List _schedule = Uint32List(64);
  int _blockLength = 0;
  int _length = 0;
  bool _closed = false;

  /// Hashes [bytes] in one call.
  static String of(List<int> bytes) {
    final digest = Sha256()..add(bytes);
    return digest.close();
  }

  static String ofString(String value) => of(utf8.encode(value));

  /// Feeds more bytes. Chunk boundaries may fall anywhere.
  void add(List<int> bytes) {
    if (_closed) throw StateError('Sha256 is already closed');
    _consume(bytes);
  }

  /// Returns the lowercase hex digest and closes the instance.
  String close() {
    if (_closed) throw StateError('Sha256 is already closed');
    _closed = true;
    final messageBits = _length * 8;
    final paddingLength = (56 - (_length + 1) % 64 + 64) % 64;
    final padding = Uint8List(1 + paddingLength + 8);
    padding[0] = 0x80;
    for (var index = 0; index < 8; index++) {
      padding[padding.length - 1 - index] = (messageBits >> (index * 8)) & 0xff;
    }
    _consume(padding);
    final out = StringBuffer();
    for (final word in _state) {
      out.write(word.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }

  void _consume(List<int> bytes) {
    _length += bytes.length;
    var offset = 0;
    if (_blockLength > 0) {
      final take = 64 - _blockLength < bytes.length
          ? 64 - _blockLength
          : bytes.length;
      _block.setRange(_blockLength, _blockLength + take, bytes);
      _blockLength += take;
      offset = take;
      if (_blockLength == 64) {
        _compress(_block, 0);
        _blockLength = 0;
      }
    }
    while (offset + 64 <= bytes.length) {
      _compress(bytes, offset);
      offset += 64;
    }
    if (offset < bytes.length) {
      _block.setRange(0, bytes.length - offset, bytes, offset);
      _blockLength = bytes.length - offset;
    }
  }

  void _compress(List<int> data, int offset) {
    final words = _schedule;
    for (var index = 0; index < 16; index++) {
      final at = offset + index * 4;
      words[index] =
          (data[at] << 24) |
          (data[at + 1] << 16) |
          (data[at + 2] << 8) |
          data[at + 3];
    }
    for (var index = 16; index < 64; index++) {
      final w15 = words[index - 15];
      final w2 = words[index - 2];
      final s0 = _rotateRight(w15, 7) ^ _rotateRight(w15, 18) ^ (w15 >> 3);
      final s1 = _rotateRight(w2, 17) ^ _rotateRight(w2, 19) ^ (w2 >> 10);
      words[index] =
          (words[index - 16] + s0 + words[index - 7] + s1) & 0xffffffff;
    }

    var a = _state[0];
    var b = _state[1];
    var c = _state[2];
    var d = _state[3];
    var e = _state[4];
    var f = _state[5];
    var g = _state[6];
    var h = _state[7];

    for (var index = 0; index < 64; index++) {
      final s1 = _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
      final choice = (e & f) ^ (~e & g);
      final temp1 =
          (h + s1 + choice + _roundConstants[index] + words[index]) &
          0xffffffff;
      final s0 = _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + majority) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    _state[0] = (_state[0] + a) & 0xffffffff;
    _state[1] = (_state[1] + b) & 0xffffffff;
    _state[2] = (_state[2] + c) & 0xffffffff;
    _state[3] = (_state[3] + d) & 0xffffffff;
    _state[4] = (_state[4] + e) & 0xffffffff;
    _state[5] = (_state[5] + f) & 0xffffffff;
    _state[6] = (_state[6] + g) & 0xffffffff;
    _state[7] = (_state[7] + h) & 0xffffffff;
  }

  static int _rotateRight(int value, int bits) =>
      ((value >> bits) | (value << (32 - bits))) & 0xffffffff;
}
