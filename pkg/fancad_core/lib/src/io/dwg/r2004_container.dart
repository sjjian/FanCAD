import 'dart:typed_data';

/// R2004 container: encrypted file header, section page map, section info and
/// the LZ77 page decompressor.
///
/// This is the first half of M2. It stops at whole-section bytes; object
/// decoding on top of them is the next step.
final class R2004Container {
  R2004Container._({
    required this.data,
    required this.sectionMapId,
    required this.sectionInfoId,
    required this.sectionArraySize,
    required this.sections,
    required this.infos,
  });

  final Uint8List data;
  final int sectionMapId;
  final int sectionInfoId;
  final int sectionArraySize;
  final Map<int, R2004Section> sections;
  final List<R2004SectionInfo> infos;

  static R2004Container read(Uint8List data) {
    final magic = data.length >= 6 ? _ascii(data, 0, 6) : '';
    if (data.length < 0x80 + 108 ||
        (magic != 'AC1018' &&
            magic != 'AC1024' &&
            magic != 'AC1027' &&
            magic != 'AC1032')) {
      throw const FormatException('not an R2004+ DWG');
    }
    final header = _decryptHeader(data);
    if (_ascii(header, 0, 11) != 'AcFssFcAJMB') {
      throw const FormatException('R2004 header decryption failed');
    }
    final sectionMapId = _u32(header, 0x50);
    final sectionMapAddress = _u64(header, 0x54);
    final sectionInfoId = _u32(header, 0x5C);
    final sectionArraySize = _u32(header, 0x60);

    final mapStart = sectionMapAddress + 0x100;
    if (mapStart + 0x14 > data.length) {
      throw const FormatException('section page map outside file');
    }
    if (_u32(data, mapStart) != 0x41630E3B) {
      throw const FormatException('invalid section page map');
    }
    final decompSize = _u32(data, mapStart + 4);
    final compSize = _u32(data, mapStart + 8);
    final mapBytes = _decompress(data, mapStart + 0x14, compSize, decompSize);

    final sections = <int, R2004Section>{};
    var address = 0x100;
    for (var at = 0; at + 8 <= mapBytes.length; at += 8) {
      // Section ids are signed: a negative id marks a gap in the file. The
      // gap record carries 16 extra bytes of parent information, and its size
      // still counts towards the address of every section after it. Reading
      // the id unsigned made those addresses 64 bytes short on drawings with
      // gaps, which put the section info outside the file.
      final number = _i32(mapBytes, at);
      final size = _u32(mapBytes, at + 4);
      sections[number] = R2004Section(
        number: number,
        size: size,
        address: address,
      );
      if (number <= sectionArraySize) address += size;
      if (number < 0) at += 16;
    }

    final infoSection = sections[sectionInfoId];
    if (infoSection == null) {
      throw const FormatException('section info is missing');
    }
    final infos = _readSectionInfo(data, infoSection);

    return R2004Container._(
      data: data,
      sectionMapId: sectionMapId,
      sectionInfoId: sectionInfoId,
      sectionArraySize: sectionArraySize,
      sections: sections,
      infos: infos,
    );
  }

  R2004SectionInfo? infoNamed(String name) {
    for (final info in infos) {
      if (info.name == name) return info;
    }
    return null;
  }

  /// Reads and decompresses a whole section by name.
  ///
  /// R2004+ allocates `num_sections * max_decomp_size`; a compressed page may
  /// run past its nominal page size and into the following slot, so the whole
  /// section shares one buffer.
  Uint8List readSection(String name) {
    final info = infoNamed(name);
    if (info == null) throw FormatException('section $name is missing');
    final sectionsCount = info.pageNumbers.length;
    final bufferSize = [
      info.size,
      sectionsCount * info.maxDecompSize,
    ].reduce((a, b) => a > b ? a : b);
    final dec = Uint8List(bufferSize);
    for (final pageNumber in info.pageNumbers) {
      final page = sections[pageNumber];
      if (page == null || page.address + 32 > data.length) continue;
      final header = _pageHeader(page.address);
      final startOffset = header.address;
      final dataSize = header.dataSize;
      if (page.address + 32 + dataSize > data.length) {
        throw FormatException('section $name page outside file');
      }
      if (info.compressed == 2) {
        _decompressInto(
          data,
          page.address + 32,
          dataSize,
          dec,
          startOffset,
          bufferSize,
        );
      } else {
        final size = _min(header.pageSize, bufferSize - startOffset);
        if (size <= 0 || startOffset + size > dec.length) continue;
        dec.setRange(
          startOffset,
          startOffset + size,
          data.sublist(page.address + 32, page.address + 32 + size),
        );
      }
    }
    final size = _min(info.size, dec.length);
    return Uint8List.sublistView(dec, 0, size);
  }

  _PageHeader _pageHeader(int address) {
    final mask = 0x4164536B ^ address;
    final words = List<int>.generate(
      8,
      (i) => _u32(data, address + i * 4) ^ mask,
    );
    if (words[0] != 0x4163043B) {
      throw FormatException(
        'invalid section page header at 0x${address.toRadixString(16)}',
      );
    }
    return _PageHeader(
      dataSize: words[2],
      pageSize: words[3],
      address: words[4],
    );
  }

  static List<R2004SectionInfo> _readSectionInfo(
    Uint8List data,
    R2004Section section,
  ) {
    if (section.address + 20 > data.length) {
      throw const FormatException('section info outside file');
    }
    if (_u32(data, section.address) != 0x4163003B) {
      throw const FormatException('invalid section info page map');
    }
    final decompSize = _u32(data, section.address + 4);
    final compSize = _u32(data, section.address + 8);
    final bytes = _decompress(data, section.address + 20, compSize, decompSize);
    final numDesc = _u32(bytes, 0);
    var at = 20;
    final infos = <R2004SectionInfo>[];
    for (var i = 0; i < numDesc; i++) {
      if (at + 96 > bytes.length) break;
      final size = _u64(bytes, at);
      final numSections = _u32(bytes, at + 8);
      final maxDecompSize = _u32(bytes, at + 12);
      final compressed = _u32(bytes, at + 20);
      final name = _ascii(bytes, at + 32, 64);
      at += 96;
      final pages = <int>[];
      for (var j = 0; j < numSections; j++) {
        if (at + 16 > bytes.length) break;
        pages.add(_u32(bytes, at));
        at += 16;
      }
      infos.add(
        R2004SectionInfo(
          name: name,
          size: size,
          pageNumbers: pages,
          maxDecompSize: maxDecompSize,
          compressed: compressed,
        ),
      );
    }
    return infos;
  }

  static Uint8List _decryptHeader(Uint8List data) {
    final out = Uint8List(108);
    var seed = 1;
    for (var i = 0; i < out.length; i++) {
      seed = (seed * 0x343FD + 0x269EC3) & 0xFFFFFFFF;
      out[i] = data[0x80 + i] ^ ((seed >> 16) & 0xFF);
    }
    return out;
  }

  static Uint8List _decompress(
    Uint8List data,
    int offset,
    int compSize,
    int decompSize,
  ) {
    final out = Uint8List(decompSize);
    _decompressInto(data, offset, compSize, out, 0, decompSize);
    return out;
  }

  /// LZ77 variant used by R2004 system and data sections.
  static void _decompressInto(
    Uint8List src,
    int offset,
    int compSize,
    Uint8List out,
    int outOffset,
    int maxPageSize,
  ) {
    final end = offset + compSize;
    var si = offset;
    var di = outOffset;
    final limit = _min(out.length, outOffset + maxPageSize);

    int readByte() {
      if (si >= end || si >= src.length) {
        throw const FormatException('truncated R2004 compressed stream');
      }
      return src[si++];
    }

    int literalLength(int opcode) {
      var low = opcode & 0xF;
      if (low == 0) {
        while (true) {
          final byte = readByte();
          if (byte != 0) {
            low += 0xF + byte;
            break;
          }
          low += 0xFF;
        }
      }
      return low + 3;
    }

    int compressedBytes(int opcode, int bits) {
      var count = opcode & bits;
      if (count == 0) {
        while (true) {
          final byte = readByte();
          if (byte != 0) {
            count += byte + bits;
            break;
          }
          count += 0xFF;
        }
      }
      return count + 2;
    }

    ({int opcode, int offset}) twoByteOffset(int plus, int current) {
      final first = readByte();
      final second = readByte();
      current |= first >> 2;
      current |= second << 6;
      return (opcode: first, offset: current + plus);
    }

    int copyBytes(int count) {
      if (di + count > out.length) {
        throw const FormatException('R2004 literal overflow');
      }
      if (si + count > end || si + count > src.length) {
        throw const FormatException('truncated R2004 compressed stream');
      }
      out.setRange(di, di + count, src, si);
      di += count;
      si += count;
      return readByte();
    }

    var opcode = readByte();
    if ((opcode & 0xF0) == 0) {
      opcode = copyBytes(literalLength(opcode));
    }

    while (si < end && di < limit && opcode != 0x11) {
      var count = 0;
      var back = 0;
      if (opcode < 0x10 || opcode >= 0x40) {
        count = (opcode >> 4) - 1;
        final second = readByte();
        back = (((opcode >> 2) & 3) | (second << 2)) + 1;
      } else if (opcode < 0x20) {
        count = compressedBytes(opcode, 7);
        back = (opcode & 8) << 11;
        final next = twoByteOffset(0x4000, back);
        opcode = next.opcode;
        back = next.offset;
      } else {
        count = compressedBytes(opcode, 0x1F);
        final next = twoByteOffset(1, back);
        opcode = next.opcode;
        back = next.offset;
      }
      if (count < 0 || back <= 0 || di < back) {
        throw const FormatException('R2004 back-reference out of range');
      }
      for (var i = 0; i < count; i++) {
        if (di >= out.length) break;
        out[di] = out[di - back];
        di++;
      }
      var literal = opcode & 3;
      if (literal == 0) {
        opcode = readByte();
        if ((opcode & 0xF0) == 0) literal = literalLength(opcode);
      }
      if (literal != 0) {
        if (di + literal > out.length) break;
        opcode = copyBytes(literal);
      }
    }
  }

  static int _min(int a, int b) => a < b ? a : b;

  static int _i32(Uint8List data, int at) {
    final value = _u32(data, at);
    return value >= 0x80000000 ? value - 0x100000000 : value;
  }

  static int _u32(Uint8List data, int at) =>
      data[at] |
      (data[at + 1] << 8) |
      (data[at + 2] << 16) |
      (data[at + 3] << 24);

  static int _u64(Uint8List data, int at) =>
      _u32(data, at) | (_u32(data, at + 4) << 32);

  static String _ascii(Uint8List data, int at, int length) {
    final end = _min(at + length, data.length);
    var stop = at;
    while (stop < end && data[stop] != 0) {
      stop++;
    }
    return String.fromCharCodes(data.sublist(at, stop));
  }
}

final class R2004Section {
  const R2004Section({
    required this.number,
    required this.size,
    required this.address,
  });

  final int number;
  final int size;
  final int address;

  @override
  String toString() =>
      'section($number, size=$size, @0x${address.toRadixString(16)})';
}

final class R2004SectionInfo {
  const R2004SectionInfo({
    required this.name,
    required this.size,
    required this.pageNumbers,
    required this.maxDecompSize,
    required this.compressed,
  });

  final String name;
  final int size;
  final List<int> pageNumbers;
  final int maxDecompSize;
  final int compressed;

  @override
  String toString() =>
      'info("$name", size=$size, pages=${pageNumbers.length}, '
      'max=$maxDecompSize, compressed=$compressed)';
}

final class _PageHeader {
  const _PageHeader({
    required this.dataSize,
    required this.pageSize,
    required this.address,
  });

  final int dataSize;
  final int pageSize;
  final int address;
}
