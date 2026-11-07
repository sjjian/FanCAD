import 'dart:typed_data';

import 'bit_writer.dart';
import 'r2000_object.dart';

/// Encodes an R2000 BLOCK_HEADER table record (type 0x31).
Uint8List encodeBlockHeader({
  required int handle,
  required String name,
  required int blockEntity,
  required int endblkEntity,
  required int blockControl,
  int firstEntity = 0,
  int lastEntity = 0,
  int layout = 0,
  double baseX = 0,
  double baseY = 0,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x31);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  writeTv(data, name);
  data.b(true); // is_xref_ref
  data.bs(0); // is_xref_resolved
  data.b(false); // is_xref_dep
  data.b(false); // anonymous
  data.b(false); // hasattrs
  data.b(false); // blkisxref
  data.b(false); // xrefoverlaid
  data.b(false); // xref_loaded
  data.bd(baseX);
  data.bd(baseY);
  data.bd(0); // base point
  writeTv(data, ''); // xref path
  data.rc(0); // zero-terminated num_inserts list
  writeTv(data, ''); // description
  data.bl(0); // preview size

  endObjectData(data, bitsizePos);

  data.h(blockControl, code: 4);
  data.h(0, code: 3); // xdic
  data.h(0, code: 5); // xref
  data.h(blockEntity, code: 3);
  data.h(firstEntity, code: 4);
  data.h(lastEntity, code: 4);
  data.h(endblkEntity, code: 3);
  data.h(layout, code: 5);
  return finishObject(data);
}

/// Encodes the BLOCK entity (type 0x04) that opens a block definition.
Uint8List encodeBlockBegin({
  required int handle,
  required String name,
  required int owner,
  required int layer,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x04);
  writeCommonEntityData(data, handle: handle, entmode: 0);
  writeTv(data, name);
  endObjectData(data, bitsizePos);
  data.h(owner, code: 4);
  data.h(0, code: 3); // xdic
  data.h(layer, code: 5);
  return finishObject(data);
}

/// Encodes the ENDBLK entity (type 0x05) that closes a block definition.
Uint8List encodeBlockEnd({
  required int handle,
  required int owner,
  required int layer,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x05);
  writeCommonEntityData(data, handle: handle, entmode: 0);
  endObjectData(data, bitsizePos);
  data.h(owner, code: 4);
  data.h(0, code: 3); // xdic
  data.h(layer, code: 5);
  return finishObject(data);
}

/// Encodes an R2000 BLOCK_CONTROL object (type 0x30).
Uint8List encodeBlockControl({
  required int handle,
  required List<int> entries,
  required int modelSpace,
  required int paperSpace,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x30);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  data.bl(entries.length);

  endObjectData(data, bitsizePos);

  data.h(0, code: 4); // ownerhandle
  data.h(0, code: 3); // xdic
  for (final entry in entries) {
    data.h(entry, code: 2);
  }
  data.h(modelSpace, code: 3);
  data.h(paperSpace, code: 3);
  return finishObject(data);
}
