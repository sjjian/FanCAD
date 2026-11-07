import 'dart:typed_data';

import '../bit_reader.dart';
import 'bit_writer.dart';
import 'dwg_crc.dart';

/// One entry in the R2000 CLASSES section.
final class R2000ClassDef {
  const R2000ClassDef({
    required this.number,
    required this.cppName,
    required this.dxfName,
    required this.itemClassId,
    this.appName = 'AutoCAD 2000',
    this.proxyFlag = 0,
    this.wasProxy = false,
  });

  final int number;
  final int proxyFlag;
  final String appName;
  final String cppName;
  final String dxfName;
  final bool wasProxy;

  /// 498 for entities, 499 for objects.
  final int itemClassId;
}

/// Parsed R2000 CLASSES section. Rebuilding it keeps existing classes and can
/// append new ones; the result is appended at the file end and the section
/// locator is repointed, so no earlier bytes move.
final class R2000ClassTable {
  const R2000ClassTable(this.classes);

  static const _beginSentinel = [
    0x8d,
    0xa1,
    0xc4,
    0xb8,
    0xc4,
    0xa9,
    0xf8,
    0xc5,
    0xc0,
    0xdc,
    0xf4,
    0x5f,
    0xe7,
    0xcf,
    0xb6,
    0x8a,
  ];
  static const _endSentinel = [
    0x72,
    0x5e,
    0x3b,
    0x47,
    0x3b,
    0x56,
    0x07,
    0x3a,
    0x3f,
    0x23,
    0x0b,
    0xa0,
    0x18,
    0x30,
    0x49,
    0x75,
  ];

  final List<R2000ClassDef> classes;

  int? numberNamed(String dxfName) {
    for (final entry in classes) {
      if (entry.dxfName.toUpperCase() == dxfName.toUpperCase()) {
        return entry.number;
      }
    }
    return null;
  }

  int get maxNumber => classes.isEmpty
      ? 499
      : classes.map((entry) => entry.number).reduce((a, b) => a > b ? a : b);

  static R2000ClassTable read(Uint8List data, int address, int size) {
    final end = (address + size).clamp(0, data.length);
    if (address + 20 > end) return const R2000ClassTable([]);
    final hasSentinel = end - address >= 20;
    var at = address;
    if (hasSentinel) at += 16;
    if (at + 4 > end) return const R2000ClassTable([]);
    final entrySize =
        data[at] |
        (data[at + 1] << 8) |
        (data[at + 2] << 16) |
        (data[at + 3] << 24);
    at += 4;
    final limit = (at + entrySize).clamp(0, end);
    final br = DwgBitReader(data)
      ..bitPos = at * 8
      ..limitBits = limit * 8;
    final classes = <R2000ClassDef>[];
    while (br.ok && br.bitPos + 8 < limit * 8) {
      final number = br.bs();
      if (number == 0) break;
      final proxy = br.bs();
      final app = br.tv();
      final cpp = br.tv();
      final dxf = br.tv();
      final wasProxy = br.b() != 0;
      final itemClassId = br.bs();
      if (!br.ok || number < 500) break;
      classes.add(
        R2000ClassDef(
          number: number,
          proxyFlag: proxy,
          appName: app,
          cppName: cpp,
          dxfName: dxf,
          wasProxy: wasProxy,
          itemClassId: itemClassId,
        ),
      );
    }
    return R2000ClassTable(classes);
  }

  /// Appends any class not already present and returns the complete section
  /// bytes plus the size to store in the section locator.
  ({Uint8List bytes, int size}) encode() {
    final data = DwgBitWriter();
    for (final entry in classes) {
      data.bs(entry.number);
      data.bs(entry.proxyFlag);
      _tv(data, entry.appName);
      _tv(data, entry.cppName);
      _tv(data, entry.dxfName);
      data.b(entry.wasProxy);
      data.bs(entry.itemClassId);
    }
    final entries = data.finish();
    final size = entries.length;

    final crcInput = Uint8List(4 + entries.length);
    crcInput[0] = size & 0xff;
    crcInput[1] = (size >> 8) & 0xff;
    crcInput[2] = (size >> 16) & 0xff;
    crcInput[3] = (size >> 24) & 0xff;
    crcInput.setRange(4, 4 + entries.length, entries);
    final crc = dwgCrc16(0xc0c1, crcInput);

    final out = Uint8List(16 + 4 + entries.length + 2 + 16 + 4);
    var at = 0;
    out.setRange(at, at + 16, _beginSentinel);
    at += 16;
    out.setRange(at, at + 4, crcInput.sublist(0, 4));
    at += 4;
    out.setRange(at, at + entries.length, entries);
    at += entries.length;
    out[at++] = crc & 0xff;
    out[at++] = (crc >> 8) & 0xff;
    out.setRange(at, at + 16, _endSentinel);
    at += 16;
    out[at] = 0xca;
    out[at + 1] = 0x0d;
    out[at + 2] = 0;
    out[at + 3] = 0;

    return (bytes: out, size: out.length - 4);
  }

  static void _tv(DwgBitWriter data, String value) {
    final bytes = value.codeUnits;
    data.bs(bytes.length);
    for (final byte in bytes) {
      data.rc(byte);
    }
  }
}
