import 'dart:typed_data';

import 'package:test/test.dart';

void main() {
  test('a UCS-2 MTEXT brace is not a C-string terminator', () {
    const note = r'{\F宋体|c134;注释}';
    final tu = encodeUcs2Le(note);
    expect(String.fromCharCodes(cStringBytes(tu)), '{');
    expect(decodeUcs2Le(tu), note);
  });

  test('an ASCII-leading UCS-2 field is recognized without a DWG version', () {
    final tu = encodeUcs2Le(r'{\F宋体|c134;注释}');
    expect(tu[0], 0x7B);
    expect(tu[1], 0);
    expect(looksLikeUcs2(tu), isTrue);
    expect(looksLikeUcs2(r'{\F宋体|c134;注释}'.codeUnits), isFalse);
  });

  test('a CJK-only UCS-2 note survives the wide-string walk', () {
    const note = '注释';
    final tu = encodeUcs2Le(note);
    expect(String.fromCharCodes(cStringBytes(tu)), isNot(note));
    expect(decodeUcs2Le(tu), note);
  });
}

/// Matches `dwg_text_is_ucs2`'s pointer check in dwg_import.c: first ASCII
/// unit is `c, 0`.
bool looksLikeUcs2(List<int> raw) =>
    raw.isNotEmpty && raw.first != 0 && raw.length > 1 && raw[1] == 0;

/// Matches `ucs2le_to_utf8` in dwg_import.c.
String decodeUcs2Le(List<int> src) {
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

Uint8List encodeUcs2Le(String text) {
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

List<int> cStringBytes(List<int> src) {
  final end = src.indexOf(0);
  return src.sublist(0, end < 0 ? src.length : end);
}
