import 'dart:typed_data';

import 'bit_writer.dart';
import 'r2000_object.dart';

/// Encodes an R2000 LTYPE table record (type 0x39).
///
/// R2000 LTYPE records reserve a 256-byte string area for the old text form of
/// the dash pattern; it is written as zeros and keeps the object layout that
/// the reference decoder expects.
Uint8List encodeLineTypeObject({
  required int handle,
  required String name,
  required String description,
  required List<double> pattern,
  required double patternLength,
  required int owner,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x39);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  writeTv(data, name);
  data.b(true); // is_xref_ref
  data.bs(0); // is_xref_resolved
  data.b(false); // is_xref_dep
  writeTv(data, description);
  data.bd(patternLength);
  data.rc(65); // alignment code 'A'
  data.rc(pattern.length.clamp(0, 255));
  for (final dash in pattern) {
    data.bd(dash);
    data.bs(0); // complex shape code
    data.rd(0); // x offset
    data.rd(0); // y offset
    data.bd(0); // scale
    data.bd(0); // rotation
    data.bs(0); // shape flag
  }
  for (var i = 0; i < 256; i++) {
    data.rc(0); // legacy strings area
  }

  endObjectData(data, bitsizePos);

  data.h(owner, code: 0xc);
  data.h(0, code: 3); // xdic
  data.h(0, code: 5); // xref
  for (var i = 0; i < pattern.length; i++) {
    data.h(0, code: 5); // dash shape style
  }
  return finishObject(data);
}

/// Encodes the R2000 LTYPE_CONTROL object (type 0x38).
Uint8List encodeLineTypeControl({
  required int handle,
  required List<int> entries,
  required int byBlock,
  required int byLayer,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x38);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  data.bs(entries.length);

  endObjectData(data, bitsizePos);

  data.h(0, code: 4); // owner
  data.h(0, code: 3); // xdic
  for (final entry in entries) {
    data.h(entry, code: 2);
  }
  data.h(byBlock, code: 3);
  data.h(byLayer, code: 3);
  return finishObject(data);
}
