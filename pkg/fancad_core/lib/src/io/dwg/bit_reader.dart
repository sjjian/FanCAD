import 'dart:convert';
import 'dart:typed_data';

import 'package:gbk_codec/gbk_codec.dart';

/// A big-endian bit reader for DWG.
///
/// DWG packs most fields into a bit stream: `BS`/`BL` are variable-width,
/// `BD`/`DD` start with a two-bit selector. Everything here is MSB-first,
/// matching the order the file writes bits in.
final class DwgBitReader {
  DwgBitReader(this.bytes, {this.limitBits, int? codepage})
    : codepage = codepage ?? defaultCodepage;

  /// DWG codepage from the file header, used for `TV` byte strings.
  ///
  /// 39 is ANSI_936 (GBK); 30 is ANSI_1252 (Latin-1). Zero means unknown and
  /// falls back to UTF-8/Latin-1.
  static int defaultCodepage = 0;

  final Uint8List bytes;

  /// Exclusive bit limit. `null` means `bytes.length * 8`.
  int? limitBits;

  final int codepage;

  int bitPos = 0;
  bool ok = true;

  int get _limit => limitBits ?? bytes.length * 8;

  void skip(int bits) {
    if (!_ensure(bits)) return;
    bitPos += bits;
  }

  /// Reads [count] bits, MSB first. At most 32 bits per call is enough for
  /// every field in this reader; 64-bit doubles are assembled byte-wise.
  int bits(int count) {
    if (count == 0) return 0;
    if (!_ensure(count)) return 0;
    if (count == 1) {
      final position = bitPos;
      final bit = (bytes[position >> 3] >> (7 - (position & 7))) & 1;
      bitPos = position + 1;
      return bit;
    }
    if (count <= 32) {
      final start = bitPos >> 3;
      final shift = bitPos & 7;
      final end = (bitPos + count + 7) >> 3;
      var value = 0;
      for (var i = start; i < end; i++) {
        value = (value << 8) | bytes[i];
      }
      final extra = (end - start) * 8 - shift - count;
      if (extra > 0) value >>= extra;
      value &= (1 << count) - 1;
      bitPos += count;
      return value;
    }
    var value = 0;
    for (var i = 0; i < count; i++) {
      final position = bitPos + i;
      final bit = (bytes[position >> 3] >> (7 - (position & 7))) & 1;
      value = (value << 1) | bit;
    }
    bitPos += count;
    return value;
  }

  int rc() {
    if (bitPos + 8 > _limit) {
      ok = false;
      return 0;
    }
    final index = bitPos >> 3;
    final shift = bitPos & 7;
    bitPos += 8;
    if (shift == 0) return bytes[index];
    final high = bytes[index];
    final low = index + 1 < bytes.length ? bytes[index + 1] : 0;
    return ((high << shift) & 0xff) | (low >> (8 - shift));
  }

  int b() => bits(1);
  int bb() => bits(2);

  /// Four raw bits, used by VIEWMODE and a few old table fields.
  int b4() => bits(4);

  /// Reads [count] bytes at the current position.
  ///
  /// When the position is byte-aligned this returns a view into [bytes] and
  /// advances in one step; otherwise it falls back to bit reads. The view is
  /// read-only by convention: callers must not mutate it.
  Uint8List readBytes(int count) {
    if (count <= 0) return Uint8List(0);
    if (!_ensure(count * 8)) return Uint8List(0);
    final start = bitPos >> 3;
    if ((bitPos & 7) == 0) {
      bitPos += count * 8;
      return Uint8List.sublistView(bytes, start, start + count);
    }
    final shift = bitPos & 7;
    final out = Uint8List(count);
    var index = start;
    for (var i = 0; i < count; i++) {
      final high = bytes[index];
      final low = bytes[index + 1];
      out[i] = ((high << shift) & 0xff) | (low >> (8 - shift));
      index++;
    }
    bitPos += count * 8;
    return out;
  }

  /// 16-bit little-endian short, bit-aligned.
  int rs() {
    final value = bits(16);
    return ((value & 0xff) << 8) | ((value >> 8) & 0xff);
  }

  /// 32-bit little-endian long: low word first.
  int rl() {
    final low = rs();
    final high = rs();
    return (high << 16) | low;
  }

  /// 64-bit IEEE double, little-endian bytes, bit-aligned.
  double rd() {
    if ((bitPos & 7) == 0 && _ensure(64)) {
      final start = bitPos >> 3;
      bitPos += 64;
      return ByteData.sublistView(
        bytes,
        start,
        start + 8,
      ).getFloat64(0, Endian.little);
    }
    final data = ByteData(8);
    for (var i = 0; i < 8; i++) {
      data.setUint8(i, rc());
    }
    return data.getFloat64(0, Endian.little);
  }

  /// `BS`: 2-bit selector; 0 -> RS, 1 -> RC, 2 -> 0, 3 -> 256.
  int bs() {
    switch (bb()) {
      case 0:
        return rs();
      case 1:
        return rc();
      case 2:
        return 0;
      default:
        return 256;
    }
  }

  /// `BL`: 2-bit selector; 0 -> RL, 1 -> RC, 2 -> 0, 3 -> 256.
  int bl() {
    switch (bb()) {
      case 0:
        return rl();
      case 1:
        return rc();
      case 2:
        return 0;
      default:
        return 256;
    }
  }

  /// `BD`: 2-bit selector; 0 -> RD, 1 -> 1.0, 2 -> 0.0.
  double bd() {
    switch (bb()) {
      case 0:
        return rd();
      case 1:
        return 1;
      case 2:
        return 0;
      default:
        ok = false;
        return 0;
    }
  }

  /// `DD`: 2-bit selector for a double stored as a delta from [defaultValue].
  double dd(double defaultValue) {
    final data = ByteData(8)..setFloat64(0, defaultValue, Endian.little);
    switch (bb()) {
      case 0:
        return defaultValue;
      case 1:
        data.setUint8(0, rc());
        data.setUint8(1, rc());
        data.setUint8(2, rc());
        data.setUint8(3, rc());
      case 2:
        data.setUint8(4, rc());
        data.setUint8(5, rc());
        data.setUint8(0, rc());
        data.setUint8(1, rc());
        data.setUint8(2, rc());
        data.setUint8(3, rc());
      default:
        return rd();
    }
    return data.getFloat64(0, Endian.little);
  }

  /// `BT`: R2000+ prepends a bit meaning "thickness is zero".
  double bt() {
    if (b() != 0) return 0;
    return bd();
  }

  /// `BE`: R2000+ prepends a bit meaning the default normal (0, 0, 1).
  List<double> be() {
    if (b() != 0) return const [0, 0, 1];
    final x = bd();
    final y = bd();
    var z = bd();
    if (x == 0 && y == 0) z = z <= 0 ? -1 : 1;
    return [x, y, z];
  }

  /// `TV`: BS byte length followed by that many bytes. R2000 strings use the
  /// drawing codepage; callers that care decode them, this keeps bytes 1:1.
  String tv() {
    final length = bs();
    if (!ok) return '';
    if (!_ensure(length * 8)) return '';
    final aligned = (bitPos & 7) == 0;
    final Uint8List raw;
    if (!aligned) {
      final out = Uint8List(length);
      for (var i = 0; i < length; i++) {
        out[i] = bits(8);
      }
      raw = out;
    } else {
      final start = bitPos >> 3;
      bitPos += length * 8;
      raw = Uint8List.sublistView(bytes, start, start + length);
    }
    final text = _decodeCodepage(raw, codepage);
    // R2000 often counts the terminating NUL in the length. A C string would
    // stop there, so do the same before callers compare text.
    final nul = text.indexOf('\x00');
    return expandDwgTextEscapes(nul < 0 ? text : text.substring(0, nul));
  }

  /// Decodes bytes using the drawing codepage (used by inline xdata strings).
  String decodeCodepage(Uint8List raw) => _decodeCodepage(raw, codepage);

  /// `H`: 4-bit code, 4-bit size, then size bytes big-endian.
  int h() {
    final first = rc();
    final size = first & 0x0f;
    hCode = (first >> 4) & 0x0f;
    if (size > 8) {
      ok = false;
      return 0;
    }
    var value = 0;
    for (var i = 0; i < size; i++) {
      value = (value << 8) | rc();
    }
    return value;
  }

  /// `BOT`: R2010+ object type (BB + RC or BB + RC/RS).
  int bot() {
    final code = bb();
    if (code == 0) return rc();
    if (code == 1) return rc() + 0x1f0;
    return rs();
  }

  /// `BLL`: R2010+ bit-long-long used for binary sizes.
  int bll() {
    final length = (bb() << 1) | b();
    switch (length) {
      case 0:
        return 0;
      case 1:
        return rc();
      case 2:
        return rs();
      case 4:
        return rl();
      default:
        var value = 0;
        for (var i = 0; i < length; i++) {
          value |= rc() << (i * 8);
        }
        return value;
    }
  }

  /// Code of the last [h] handle.
  int hCode = 0;

  /// Unsigned modular char: 7 bits per byte, high bit is "continue".
  int umc() {
    var result = 0;
    var shift = 0;
    for (var i = 0; i < 8; i++) {
      final byte = rc();
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    ok = false;
    return 0;
  }

  /// Signed modular char: up to 5 bytes, 0x40 of the last byte is the sign.
  int mc() {
    var result = 0;
    var shift = 0;
    for (var i = 0; i < 5; i++) {
      var byte = rc();
      if ((byte & 0x80) == 0) {
        final negative = (byte & 0x40) != 0;
        if (negative) byte &= 0xbf;
        result |= byte << shift;
        return negative ? -result : result;
      }
      result |= (byte & 0x7f) << shift;
      shift += 7;
    }
    ok = false;
    return 0;
  }

  /// `MS`: up to two 15-bit words, low word first.
  int ms() {
    final low = rs();
    if ((low & 0x8000) == 0) return low;
    final high = rs();
    return (low & 0x7fff) | ((high & 0x7fff) << 15);
  }

  bool _ensure(int count) {
    if (count < 0 || bitPos + count > _limit) {
      ok = false;
      return false;
    }
    return true;
  }
}

/// Decodes a DWG byte string: UTF-8 when valid, GBK when it yields CJK, and
/// Latin-1 otherwise.
String _decodeCodepage(Uint8List raw, int codepage) {
  if (codepage == 39) {
    // The file header names ANSI_936, so every TV string is GBK, including
    // Greek and punctuation that are not in the CJK blocks.
    return gbk_bytes.decode(raw);
  }
  try {
    return utf8.decode(raw);
  } on FormatException {
    // Not UTF-8, fall through to Latin-1.
  }
  return latin1.decode(raw);
}

final _unicodeEscape = RegExp(r'\\U\+([0-9A-Fa-f]{4})');

/// Expands AutoCAD's `\\U+XXXX` text escapes into real Unicode characters.
String expandDwgTextEscapes(String text) {
  if (!text.contains(r'\U+')) return text;
  return text.replaceAllMapped(
    _unicodeEscape,
    (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
  );
}
