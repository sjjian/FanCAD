import 'dart:convert';
import 'dart:typed_data';

import 'r2000_empty_template.dart';

/// Minimal R2000 DWG writer.
///
/// M4a only writes the file header, section locator and an empty object map.
/// The bit writer and object encoders are added next; keeping the container
/// separate means the first round-trip test does not depend on entity encoding.
final class R2000Writer {
  const R2000Writer();

  /// A valid empty R2000 drawing. Currently a one-time generated template;
  /// replacing it with encoded header/classes sections is the next M4 step.
  Uint8List writeEmptyTemplate() => base64Decode(r2000EmptyTemplateBase64);

  Uint8List writeEmpty() {
    const headerAddress = 0x80;
    const classesAddress = 0xA0;
    const handlesAddress = 0xC0;
    const fileSize = 0xC4;

    final out = Uint8List(fileSize);
    final view = ByteData.view(out.buffer);

    // Version magic is 11 bytes, then the R13+ header fields.
    out.setRange(0, 6, 'AC1015'.codeUnits);
    out[0x0B] = 0; // zero_one_or_three
    view.setUint32(0x0C, 0, Endian.little); // thumbnail address
    out[0x10] = 0; // dwg_version
    out[0x11] = 0x21; // maintenance version
    out[0x12] = 0;
    view.setUint16(0x13, 30, Endian.little); // ANSI_1252
    view.setUint32(0x15, 3, Endian.little); // sections
    // Section locator records: number RC, address RL, size RL.
    _section(out, view, 0x19, 0, headerAddress, 0x20);
    _section(out, view, 0x19 + 9, 1, classesAddress, 0x20);
    _section(out, view, 0x19 + 18, 2, handlesAddress, 0x04);

    // Header and classes sections are placeholders for now. The reader does
    // not interpret them yet; the handles section below is what it needs.
    out.fillRange(headerAddress, headerAddress + 0x20, 0);
    out.fillRange(classesAddress, classesAddress + 0x20, 0);

    // One empty object-map page: BE16 size 2, no entries, BE16 CRC.
    view.setUint16(handlesAddress, 2, Endian.big);
    view.setUint16(handlesAddress + 2, 0, Endian.big);

    return out;
  }

  void _section(
    Uint8List out,
    ByteData view,
    int at,
    int number,
    int address,
    int size,
  ) {
    out[at] = number;
    view.setUint32(at + 1, address, Endian.little);
    view.setUint32(at + 5, size, Endian.little);
  }
}
