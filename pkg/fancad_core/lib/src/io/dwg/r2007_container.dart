import 'dart:math' as math;
import 'dart:typed_data';

/// R2007+ container: Reed-Solomon-interleaved system pages, page and section
/// maps, and the R2007 LZ77 decompressor.
///
/// The entity stream itself is decoded by the shared object reader; this file
/// only turns the AC1021+ file into whole section byte arrays.
final class R2007Container {
  R2007Container._({
    required this.data,
    required this.pages,
    required this.sections,
    required this.header,
  });

  final Uint8List data;
  final Map<int, R2007Page> pages;
  final Map<String, R2007Section> sections;
  final R2007FileHeader header;

  static R2007Container read(Uint8List data) {
    final magic = data.length >= 6 ? _ascii(data, 0, 6) : '';
    if (data.length < 0x480 ||
        (magic != 'AC1021' &&
            magic != 'AC1024' &&
            magic != 'AC1027' &&
            magic != 'AC1032')) {
      throw const FormatException('not an R2007+ DWG');
    }
    final header = _readFileHeader(data);

    final pagesBytes = _readSystemPage(
      data,
      0x480 + header.pagesMapOffset,
      header.pagesMapSizeComp,
      header.pagesMapSizeUncomp,
      header.pagesMapCorrection,
    );
    final pages = <int, R2007Page>{};
    var offset = 0x480;
    for (var at = 0; at + 16 <= pagesBytes.length; at += 16) {
      final size = _i64(pagesBytes, at);
      final id = _i64(pagesBytes, at + 8);
      pages[id] = R2007Page(id: id, size: size, offset: offset);
      offset += size;
    }

    final sectionsPage = pages[header.sectionsMapId];
    if (sectionsPage == null) {
      throw const FormatException('R2007 sections map page is missing');
    }
    final sectionBytes = _readSystemPage(
      data,
      sectionsPage.offset,
      header.sectionsMapSizeComp,
      header.sectionsMapSizeUncomp,
      header.sectionsMapCorrection,
    );
    final sections = _readSectionsMap(sectionBytes);

    return R2007Container._(
      data: data,
      pages: pages,
      sections: sections,
      header: header,
    );
  }

  R2007Section? sectionNamed(String name) {
    for (final section in sections.values) {
      if (section.name == name) return section;
    }
    return null;
  }

  /// Reads and decompresses a whole section by name, e.g. `AcDb:AcDbObjects`.
  Uint8List? readSection(String name) {
    final section = sectionNamed(name);
    if (section == null) return null;
    final out = Uint8List(section.dataSize);
    for (final sectionPage in section.pages) {
      final page = pages[sectionPage.id];
      if (page == null) continue;
      if (page.offset < 0 || page.offset >= data.length) continue;
      final destination = sectionPage.offset;
      if (destination < 0 || destination > out.length) continue;

      final rsCoded =
          sectionPage.compSize != sectionPage.uncompSize ||
          page.size == _pageSizeIfRsCoded(sectionPage.compSize);
      if (rsCoded) {
        final decoded = _readDataPage(
          data,
          page.offset,
          page.size,
          sectionPage.compSize,
          sectionPage.uncompSize,
        );
        final size = math.min(decoded.length, out.length - destination);
        out.setRange(destination, destination + size, decoded);
      } else {
        final size = math.min(sectionPage.uncompSize, out.length - destination);
        if (page.offset + size > data.length) continue;
        out.setRange(
          destination,
          destination + size,
          data.sublist(page.offset, page.offset + size),
        );
      }
    }
    return out;
  }

  static R2007FileHeader _readFileHeader(Uint8List data) {
    if (data.length < 0x80 + 0x3d8) {
      throw const FormatException('R2007 file header is truncated');
    }
    final pedata = _decodeRs(
      Uint8List.sublistView(data, 0x80, 0x80 + 0x3d8),
      3,
      239,
      0x3d8,
    );
    final compressedLength = _i32(pedata, 24);
    Uint8List header;
    if (compressedLength > 0) {
      final sourceLength = math.min(compressedLength, pedata.length - 32);
      header = decompressR2007(
        Uint8List.sublistView(pedata, 32, 32 + sourceLength),
        272,
      );
    } else {
      header = Uint8List.fromList(pedata.sublist(32, 32 + 272));
    }
    return R2007FileHeader(
      pagesMapOffset: _i64(header, 56),
      pagesMapId: _i64(header, 64),
      pagesMapSizeComp: _i64(header, 80),
      pagesMapSizeUncomp: _i64(header, 88),
      pagesMapCorrection: _i64(header, 24),
      sectionsMapId: _i64(header, 192),
      sectionsMapSizeComp: _i64(header, 176),
      sectionsMapSizeUncomp: _i64(header, 200),
      sectionsMapCorrection: _i64(header, 216),
    );
  }

  static Map<String, R2007Section> _readSectionsMap(Uint8List bytes) {
    final sections = <String, R2007Section>{};
    var at = 0;
    while (at + 64 <= bytes.length) {
      final dataSize = _i64(bytes, at);
      final maxSize = _i64(bytes, at + 8);
      final encrypted = _i64(bytes, at + 16);
      final hashcode = _i64(bytes, at + 24);
      final nameLength = _i64(bytes, at + 32);
      _i64(bytes, at + 40); // unknown
      final encoded = _i64(bytes, at + 48);
      final numPages = _i64(bytes, at + 56);
      at += 64;
      if (dataSize < 0 ||
          dataSize > bytes.length * 1000 ||
          nameLength < 0 ||
          nameLength > 48 ||
          at + nameLength > bytes.length) {
        break;
      }
      final name = _utf16le(bytes, at, nameLength.toInt());
      at += nameLength.toInt();
      if (numPages < 0 || numPages > 0xf0000) break;
      final pages = <R2007SectionPage>[];
      for (var i = 0; i < numPages; i++) {
        if (at + 56 > bytes.length) break;
        pages.add(
          R2007SectionPage(
            offset: _i64(bytes, at),
            size: _i64(bytes, at + 8),
            id: _i64(bytes, at + 16),
            uncompSize: _i64(bytes, at + 24),
            compSize: _i64(bytes, at + 32),
            checksum: _i64(bytes, at + 40),
            crc: _i64(bytes, at + 48),
          ),
        );
        at += 56;
      }
      sections[name] = R2007Section(
        name: name,
        dataSize: dataSize,
        maxSize: maxSize,
        encrypted: encrypted,
        hashcode: hashcode,
        encoded: encoded,
        pages: pages,
      );
      if (at >= bytes.length) break;
    }
    return sections;
  }

  static Uint8List _readSystemPage(
    Uint8List data,
    int offset,
    int sizeComp,
    int sizeUncomp,
    int repeatCount,
  ) {
    final pesize = ((sizeComp + 7) & ~7) * repeatCount;
    final blockCount = (pesize + 238) ~/ 239;
    final pageSize = (blockCount * 255 + 7) & ~7;
    if (offset < 0 || offset + pageSize > data.length) {
      throw const FormatException('R2007 system page outside file');
    }
    final pedata = _decodeRs(
      Uint8List.sublistView(data, offset, offset + pageSize),
      blockCount,
      239,
      pageSize,
    );
    final compressed = math.min(pedata.length, sizeComp);
    if (sizeComp < sizeUncomp) {
      return decompressR2007(
        Uint8List.sublistView(pedata, 0, compressed),
        sizeUncomp,
      );
    }
    return Uint8List.fromList(pedata.sublist(0, sizeUncomp));
  }

  static Uint8List _readDataPage(
    Uint8List data,
    int offset,
    int pageSize,
    int sizeComp,
    int sizeUncomp,
  ) {
    final pesize = (sizeComp + 7) & ~7;
    final blockCount = (pesize + 0xfb - 1) ~/ 0xfb;
    final pedataSize = blockCount * 0xfb;
    if (offset < 0 || offset + pageSize > data.length) {
      throw const FormatException('R2007 data page outside file');
    }
    final pedata = _decodeRs(
      Uint8List.sublistView(data, offset, offset + pageSize),
      blockCount,
      0xfb,
      pageSize,
    );
    if (sizeComp < sizeUncomp) {
      return decompressR2007(
        Uint8List.sublistView(pedata, 0, math.min(pedataSize, sizeComp)),
        sizeUncomp,
      );
    }
    return Uint8List.fromList(pedata.sublist(0, sizeUncomp));
  }

  static int _pageSizeIfRsCoded(int sizeComp) {
    final pesize = (sizeComp + 7) & ~7;
    final blockCount = (pesize + 0xfb - 1) ~/ 0xfb;
    return (blockCount * 0xff + 31) & ~31;
  }

  /// Undoes the R2007 interleaving: each 239-byte block is spread across
  /// `blockCount` byte lanes and padded to 255 codewords.
  static Uint8List _decodeRs(
    Uint8List src,
    int blockCount,
    int dataSize,
    int srcSize,
  ) {
    if (blockCount * dataSize > srcSize) {
      throw const FormatException('R2007 RS block outside source');
    }
    final out = Uint8List(blockCount * dataSize);
    var srcBase = 0;
    var write = 0;
    for (var i = 0; i < blockCount; i++) {
      var read = srcBase;
      for (var j = 0; j < dataSize; j++) {
        out[write++] = src[read];
        read += blockCount;
      }
      srcBase++;
    }
    return out;
  }

  static String _ascii(Uint8List data, int at, int length) =>
      String.fromCharCodes(data.sublist(at, at + length));

  static String _utf16le(Uint8List data, int at, int length) {
    final units = <int>[];
    for (var i = 0; i + 1 < length; i += 2) {
      final unit = data[at + i] | (data[at + i + 1] << 8);
      if (unit == 0) break;
      units.add(unit);
    }
    return String.fromCharCodes(units);
  }

  static int _i32(Uint8List data, int at) =>
      ByteData.sublistView(data).getInt32(at, Endian.little);

  static int _i64(Uint8List data, int at) =>
      ByteData.sublistView(data).getInt64(at, Endian.little);
}

/// R2007 LZ77 decompressor (format 2007, spec 5.0 p.30 / 5.1 p.53).
Uint8List decompressR2007(Uint8List src, int dstSize) {
  if (src.isEmpty) return Uint8List(0);
  final out = Uint8List(dstSize);
  var outLength = 0;
  var si = 0;
  var length = 0;
  var offset = 0;

  var opcode = src[si++];
  if ((opcode & 0xf0) == 0x20) {
    if (si + 2 >= src.length) {
      return Uint8List.sublistView(out, 0, outLength);
    }
    si += 2;
    length = src[si++] & 0x07;
    if (length == 0) throw const FormatException('R2007 zero literal');
  }

  void backref(int count, int distance) {
    if (distance <= 0 || distance > outLength) {
      throw const FormatException('R2007 back-reference overflow');
    }
    for (var i = 0; i < count; i++) {
      out[outLength] = out[outLength - distance];
      outLength++;
    }
  }

  while (si < src.length) {
    if (length == 0) {
      final literal = _readLiteralLength(src, si, opcode);
      length = literal.length;
      si += literal.extra;
    }
    if (outLength + length > dstSize) {
      throw const FormatException('R2007 output overflow');
    }
    if (si + length > src.length) {
      throw const FormatException('R2007 literal overflow');
    }
    _copyCompressed(out, outLength, src, si, length);
    outLength += length;
    si += length;
    length = 0;
    if (si >= src.length) break;

    opcode = src[si++];
    final first = _readInstructions(src, si, opcode, offset, length);
    si = first.next;
    offset = first.offset;
    length = first.length;
    opcode = first.opcode;

    while (true) {
      if (outLength + length > dstSize) {
        throw const FormatException('R2007 output overflow');
      }
      backref(length, offset);
      length = opcode & 7;
      if (length != 0 || si >= src.length) break;
      opcode = src[si++];
      if ((opcode >> 4) == 0) break;
      if ((opcode >> 4) == 0x0f) opcode &= 0xf;
      final next = _readInstructions(src, si, opcode, offset, length);
      si = next.next;
      offset = next.offset;
      length = next.length;
      opcode = next.opcode;
    }
  }

  if (outLength > dstSize) throw const FormatException('R2007 overshoot');
  return outLength == out.length
      ? out
      : Uint8List.sublistView(out, 0, outLength);
}

({int length, int extra}) _readLiteralLength(
  Uint8List src,
  int si,
  int opcode,
) {
  var length = opcode + 8;
  var extra = 0;
  if (length == 0x17) {
    if (si >= src.length) throw const FormatException('R2007 literal end');
    final n = src[si];
    length += n;
    extra = 1;
    if (n == 0xff) {
      var at = si + 1;
      int value;
      do {
        if (at + 1 >= src.length) {
          throw const FormatException('R2007 literal end');
        }
        value = src[at] | (src[at + 1] << 8);
        at += 2;
        extra += 2;
        length += value;
      } while (value == 0xffff);
    }
  }
  return (length: length, extra: extra);
}

({int next, int opcode, int offset, int length}) _readInstructions(
  Uint8List src,
  int si,
  int opcode,
  int offset,
  int length,
) {
  switch (opcode >> 4) {
    case 0:
      length = (opcode & 0xf) + 0x13;
      if (si + 1 >= src.length) throw const FormatException('R2007 instr');
      offset = src[si++];
      opcode = src[si++];
      length = ((opcode >> 3) & 0x10) + length;
      offset = ((opcode & 0x78) << 5) + 1 + offset;
    case 1:
      length = (opcode & 0xf) + 3;
      if (si + 1 >= src.length) throw const FormatException('R2007 instr');
      offset = src[si++];
      opcode = src[si++];
      offset = ((opcode & 0xf8) << 5) + 1 + offset;
    case 2:
      if (si + 1 >= src.length) throw const FormatException('R2007 instr');
      offset = src[si++];
      offset = ((src[si++] << 8) & 0xff00) | offset;
      length = opcode & 7;
      if ((opcode & 8) == 0) {
        if (si >= src.length) throw const FormatException('R2007 instr');
        opcode = src[si++];
        length = (opcode & 0xf8) + length;
      } else {
        offset++;
        if (si >= src.length) throw const FormatException('R2007 instr');
        length = (src[si++] << 3) + length;
        if (si >= src.length) throw const FormatException('R2007 instr');
        opcode = src[si++];
        length = (((opcode & 0xf8) << 8) + length) + 0x100;
      }
    default:
      length = opcode >> 4;
      offset = opcode & 15;
      if (si >= src.length) throw const FormatException('R2007 instr');
      opcode = src[si++];
      offset = (((opcode & 0xf8) << 1) + offset) + 1;
  }
  return (next: si, opcode: opcode, offset: offset, length: length);
}

/// Byte-reversing literal copy used by the R2007 compressor.
void _copyCompressed(
  Uint8List out,
  int outAt,
  Uint8List src,
  int si,
  int length,
) {
  var at = si;
  var o = outAt;
  void add(int value) => out[o++] = value;
  void copy1(int off) => add(src[at + off]);
  void copy2(int off) {
    add(src[at + off + 1]);
    add(src[at + off]);
  }

  void copy3(int off) {
    add(src[at + off + 2]);
    add(src[at + off + 1]);
    add(src[at + off]);
  }

  void copy4(int off) {
    for (var i = 0; i < 4; i++) {
      add(src[at + off + i]);
    }
  }

  void copy8(int off) {
    for (var i = 0; i < 8; i++) {
      add(src[at + off + i]);
    }
  }

  void copy16(int off) {
    for (var i = 8; i < 16; i++) {
      add(src[at + off + i]);
    }
    for (var i = 0; i < 8; i++) {
      add(src[at + off + i]);
    }
  }

  while (length >= 32) {
    copy16(16);
    copy16(0);
    at += 32;
    length -= 32;
  }
  switch (length) {
    case 0:
      break;
    case 1:
      copy1(0);
    case 2:
      copy2(0);
    case 3:
      copy3(0);
    case 4:
      copy4(0);
    case 5:
      copy1(4);
      copy4(0);
    case 6:
      copy1(5);
      copy4(1);
      copy1(0);
    case 7:
      copy2(5);
      copy4(1);
      copy1(0);
    case 8:
      copy8(0);
    case 9:
      copy1(8);
      copy8(0);
    case 10:
      copy1(9);
      copy8(1);
      copy1(0);
    case 11:
      copy2(9);
      copy8(1);
      copy1(0);
    case 12:
      copy4(8);
      copy8(0);
    case 13:
      copy1(12);
      copy4(8);
      copy8(0);
    case 14:
      copy1(13);
      copy4(9);
      copy8(1);
      copy1(0);
    case 15:
      copy2(13);
      copy4(9);
      copy8(1);
      copy1(0);
    case 16:
      copy16(0);
    case 17:
      copy8(9);
      copy1(8);
      copy8(0);
    case 18:
      copy1(17);
      copy16(1);
      copy1(0);
    case 19:
      copy3(16);
      copy16(0);
    case 20:
      copy4(16);
      copy16(0);
    case 21:
      copy1(20);
      copy4(16);
      copy16(0);
    case 22:
      copy2(20);
      copy4(16);
      copy16(0);
    case 23:
      copy3(20);
      copy4(16);
      copy16(0);
    case 24:
      copy8(16);
      copy16(0);
    case 25:
      copy8(17);
      copy1(16);
      copy16(0);
    case 26:
      copy1(25);
      copy8(17);
      copy1(16);
      copy16(0);
    case 27:
      copy2(25);
      copy8(17);
      copy1(16);
      copy16(0);
    case 28:
      copy4(24);
      copy8(16);
      copy16(0);
    case 29:
      copy1(28);
      copy4(24);
      copy8(16);
      copy16(0);
    case 30:
      copy2(28);
      copy4(24);
      copy8(16);
      copy16(0);
    case 31:
      copy1(30);
      copy4(26);
      copy8(18);
      copy16(2);
      copy2(0);
  }
}

final class R2007FileHeader {
  const R2007FileHeader({
    required this.pagesMapOffset,
    required this.pagesMapId,
    required this.pagesMapSizeComp,
    required this.pagesMapSizeUncomp,
    required this.pagesMapCorrection,
    required this.sectionsMapId,
    required this.sectionsMapSizeComp,
    required this.sectionsMapSizeUncomp,
    required this.sectionsMapCorrection,
  });

  final int pagesMapOffset;
  final int pagesMapId;
  final int pagesMapSizeComp;
  final int pagesMapSizeUncomp;
  final int pagesMapCorrection;
  final int sectionsMapId;
  final int sectionsMapSizeComp;
  final int sectionsMapSizeUncomp;
  final int sectionsMapCorrection;
}

final class R2007Page {
  const R2007Page({required this.id, required this.size, required this.offset});

  final int id;
  final int size;
  final int offset;
}

final class R2007Section {
  const R2007Section({
    required this.name,
    required this.dataSize,
    required this.maxSize,
    required this.encrypted,
    required this.hashcode,
    required this.encoded,
    required this.pages,
  });

  final String name;
  final int dataSize;
  final int maxSize;
  final int encrypted;
  final int hashcode;
  final int encoded;
  final List<R2007SectionPage> pages;
}

final class R2007SectionPage {
  const R2007SectionPage({
    required this.offset,
    required this.size,
    required this.id,
    required this.uncompSize,
    required this.compSize,
    required this.checksum,
    required this.crc,
  });

  final int offset;
  final int size;
  final int id;
  final int uncompSize;
  final int compSize;
  final int checksum;
  final int crc;
}
