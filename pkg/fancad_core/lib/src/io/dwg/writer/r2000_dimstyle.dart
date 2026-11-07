import 'dart:typed_data';

import 'bit_writer.dart';
import 'r2000_object.dart';

/// Encodes an R2000 DIMSTYLE table record (type 0x45).
///
/// The document model only carries the fields FanCAD regenerates dimensions
/// from; the remaining DIMSTYLE fields are written with AutoCAD defaults so
/// the record is complete and valid.
Uint8List encodeDimStyleObject({
  required int handle,
  required String name,
  required double textHeight,
  required double arrowSize,
  required double extensionLineOffset,
  required double extensionLineExtend,
  required double textGap,
  required double scale,
  required int decimalPlaces,
  required int textStyleHandle,
  required int owner,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x45);
  void sbs(int value) => data.bs(value & 0xffff);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  writeTv(data, name);
  data.b(true); // is_xref_ref
  data.bs(0); // is_xref_resolved
  data.b(false); // is_xref_dep

  writeTv(data, ''); // DIMPOST
  writeTv(data, ''); // DIMAPOST
  data.bd(scale); // DIMSCALE
  data.bd(arrowSize); // DIMASZ
  data.bd(extensionLineOffset); // DIMEXO
  data.bd(3.75); // DIMDLI
  data.bd(extensionLineExtend); // DIMEXE
  data.bd(0); // DIMRND
  data.bd(0); // DIMDLE
  data.bd(0); // DIMTP
  data.bd(0); // DIMTM
  data.b(false); // DIMTOL
  data.b(false); // DIMLIM
  data.b(false); // DIMTIH
  data.b(false); // DIMTOH
  data.b(false); // DIMSE1
  data.b(false); // DIMSE2
  data.bs(1); // DIMTAD
  data.bs(8); // DIMZIN
  data.bs(0); // DIMAZIN
  data.bd(textHeight); // DIMTXT
  data.bd(2.5); // DIMCEN
  data.bd(0); // DIMTSZ
  data.bd(0.03937007874016); // DIMALTF
  data.bd(1); // DIMLFAC
  data.bd(0); // DIMTVP
  data.bd(1); // DIMTFAC
  data.bd(textGap); // DIMGAP
  data.bd(0); // DIMALTRND
  data.b(false); // DIMALT
  data.bs(3); // DIMALTD
  data.b(true); // DIMTOFL
  data.b(false); // DIMSAH
  data.b(false); // DIMTIX
  data.b(false); // DIMSOXD
  data.bs(0); // DIMCLRD (R2000 plain ACI)
  data.bs(0); // DIMCLRE
  data.bs(0); // DIMCLRT
  data.bs(0); // DIMADEC
  data.bs(decimalPlaces); // DIMDEC
  data.bs(decimalPlaces); // DIMTDEC
  data.bs(2); // DIMALTU
  data.bs(3); // DIMALTTD
  data.bs(0); // DIMAUNIT
  data.bs(0); // DIMFRAC
  data.bs(2); // DIMLUNIT
  data.bs(44); // DIMDSEP
  data.bs(0); // DIMTMOVE
  data.bs(0); // DIMJUST
  data.b(false); // DIMSD1
  data.b(false); // DIMSD2
  data.bs(0); // DIMTOLJ
  data.bs(8); // DIMTZIN
  data.bs(0); // DIMALTZ
  data.bs(0); // DIMALTTZ
  data.b(false); // DIMUPT
  data.bs(3); // DIMATFIT
  sbs(-2); // DIMLWD
  sbs(-2); // DIMLWE
  data.b(false); // flag0

  endObjectData(data, bitsizePos);

  data.h(owner, code: 0xc);
  data.h(0, code: 3); // xdic
  data.h(0, code: 5); // xref
  data.h(textStyleHandle, code: 5); // DIMTXSTY
  for (var i = 0; i < 4; i++) {
    data.h(0, code: 5); // DIMLDRBLK, DIMBLK, DIMBLK1, DIMBLK2
  }
  return finishObject(data);
}

/// Encodes the R2000 DIMSTYLE_CONTROL object (type 0x44).
Uint8List encodeDimStyleControl({
  required int handle,
  required List<int> entries,
  required List<int> moreHandles,
}) {
  final data = DwgBitWriter();
  final bitsizePos = beginObject(data, 0x44);

  data.h(handle);
  data.bs(0); // EED
  data.bl(0); // reactors
  data.bs(entries.length);
  data.rc(moreHandles.length);

  endObjectData(data, bitsizePos);

  data.h(0, code: 4); // owner
  data.h(0, code: 3); // xdic
  for (final entry in entries) {
    data.h(entry, code: 2);
  }
  for (final entry in moreHandles) {
    data.h(entry, code: 5);
  }
  return finishObject(data);
}
