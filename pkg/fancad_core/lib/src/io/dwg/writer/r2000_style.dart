import 'dart:typed_data';

import 'bit_writer.dart';
import 'r2000_object.dart';

/// Encodes an R2000 STYLE table record (type 0x35).
Uint8List encodeTextStyleObject({
  required int handle,
  required String name,
  required String fontFamily,
  required String bigFontFamily,
  required double height,
  required double widthFactor,
  required double obliqueAngle,
  required int generation,
  required int owner,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x35);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  writeTv(data, name);
  data.b(true); // is_xref_ref
  data.bs(0); // is_xref_resolved
  data.b(false); // is_xref_dep
  data.b(false); // is_shape
  data.b(false); // is_vertical
  data.bd(height);
  data.bd(widthFactor);
  data.bd(obliqueAngle);
  data.rc(generation);
  data.bd(0.2); // last height
  writeTv(data, fontFamily);
  writeTv(data, bigFontFamily);

  endObjectData(data, bitsizePos);

  data.h(owner, code: 0xc);
  data.h(0, code: 3); // xdic
  data.h(0, code: 5); // xref
  return finishObject(data);
}

/// Encodes the R2000 STYLE_CONTROL object (type 0x34).
Uint8List encodeStyleControl({
  required int handle,
  required List<int> entries,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x34);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  data.bl(entries.length);

  endObjectData(data, bitsizePos);

  data.h(0, code: 4); // owner
  data.h(0, code: 3); // xdic
  for (final entry in entries) {
    data.h(entry, code: 2);
  }
  return finishObject(data);
}
