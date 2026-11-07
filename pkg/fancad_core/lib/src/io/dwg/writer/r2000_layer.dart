import 'dart:typed_data';

import 'bit_writer.dart';
import 'r2000_object.dart';

/// Encodes an R2000 LAYER table record (type 0x33).
///
/// The layout mimics the table records the reference decoder writes: common object data,
/// the name and xref flags, the layer flag/colour and the owner, xref,
/// plot-style and line-type handles. New layers keep the template's plot
/// style and Continuous line type.
Uint8List encodeLayerObject({
  required int handle,
  required String name,
  required int colorIndex,
  required int owner,
  required int plotStyle,
  required int lineType,
  int flag0 = 16,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x33);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  writeTv(data, name);
  data.b(true); // is_xref_ref
  data.bs(0); // is_xref_resolved
  data.b(false); // is_xref_dep
  // R2000 does not store the DXF flag: it is derived from the xref bits.
  data.bs(flag0); // frozen/off/locked/plottable bits
  data.bs(colorIndex); // CMC index

  endObjectData(data, bitsizePos);

  data.h(owner, code: 0xc);
  data.h(0, code: 3); // xdic
  data.h(0, code: 5); // xref
  data.h(plotStyle, code: 5);
  data.h(lineType, code: 5);
  return finishObject(data);
}

/// Encodes an R2000 LAYER_CONTROL object (type 0x32) with [entries].
Uint8List encodeLayerControl({
  required int handle,
  required List<int> entries,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x32);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  data.bl(entries.length); // num_entries

  endObjectData(data, bitsizePos);

  data.h(0, code: 4); // ownerhandle
  data.h(0, code: 3); // xdic
  for (final entry in entries) {
    data.h(entry, code: 2); // soft owner
  }
  return finishObject(data);
}
