import 'dart:typed_data';

/// CRC-16 used by DWG object pages and the R13-R2000 file header.
///
/// The table-driven implementation in the reference decoder is the standard reflected
/// CRC-16/ARC polynomial (0xA001) seeded with 0xC0C1.
int dwgCrc16(int seed, Uint8List data, [int start = 0, int? end]) {
  var crc = seed & 0xffff;
  final limit = end ?? data.length;
  for (var i = start; i < limit; i++) {
    crc ^= data[i];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xa001 : crc >> 1;
    }
  }
  return crc & 0xffff;
}
