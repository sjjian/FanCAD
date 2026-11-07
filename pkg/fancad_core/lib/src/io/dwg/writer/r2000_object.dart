import 'dart:typed_data';

import 'bit_writer.dart';
import 'dwg_crc.dart';

/// Wraps an encoded object body in its R2000 object record.
///
/// The MS size counts the body but not the trailing CRC-16, which is
/// computed over the size field and body.
Uint8List finishObject(DwgBitWriter data) {
  final body = data.finish();
  final object = Uint8List(2 + body.length + 2);
  object[0] = body.length & 0xff;
  object[1] = (body.length >> 8) & 0xff;
  object.setRange(2, 2 + body.length, body);
  final crc = dwgCrc16(0xc0c1, object, 0, 2 + body.length);
  object[2 + body.length] = crc & 0xff;
  object[3 + body.length] = (crc >> 8) & 0xff;
  return object;
}

/// Writes an object type, a placeholder bitsize, and returns where the
/// bitsize must be patched once the data and handle stream are complete.
int beginObject(DwgBitWriter data, int type) {
  data.bs(type);
  final bitsizePos = data.bitLength;
  data.rl(0);
  return bitsizePos;
}

/// Patches the bitsize to the current stream position, i.e. the start of the
/// handle stream. Call this after the object data and before the handles.
void endObjectData(DwgBitWriter data, int bitsizePos) {
  data.patchRl(bitsizePos, data.bitLength);
}

/// Common entity data shared by every R2000 entity. The handle stream follows
/// the type-specific data.
void writeCommonEntityData(
  DwgBitWriter data, {
  required int handle,
  required int entmode,
  int colorIndex = 256,
  bool visible = true,
  int lineWeight = 29,
  int ltypeFlags = 0,
  double lineTypeScale = 1,
}) {
  data.h(handle);
  data.bs(0); // EED
  data.b(false); // preview
  data.bb(entmode);
  data.bl(0); // reactors
  data.b(true); // nolinks
  data.bs(colorIndex);
  data.bd(lineTypeScale > 0 ? lineTypeScale : 1); // linetype scale
  data.bb(ltypeFlags);
  data.bb(0); // plotstyle flags
  data.bs(visible ? 0 : 1);
  data.rc(lineWeight);
}

/// R2000 `TV` string: BS byte length followed by raw bytes.
void writeTv(DwgBitWriter data, String value) {
  final bytes = value.codeUnits;
  data.bs(bytes.length);
  for (final byte in bytes) {
    data.rc(byte);
  }
}
