part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readRegion(DwgBitReader br, int dataEndBit) {
    if (_version >= 2013) {
      // Since R2013 the ACIS payload lives in the AcDs blob carried by
      // has_ds_data, not inline; the object itself has no version field.
      _lastSab = null;
      _lastText = '';
      return const [2];
    }
    final empty = br.b();
    if (empty != 0) {
      _lastText = '';
      return const [0];
    }
    br.b(); // unknown
    final version = br.bs();
    if (version == 2) {
      // The ACIS payload ends where the handle stream starts; the object
      // limit also covers handles and must not leak into the SAB buffer.
      final limit = dataEndBit > br.bitPos
          ? dataEndBit
          : (br.limitBits ?? _data.length * 8);
      final size = (limit - br.bitPos) ~/ 8;
      final bytes = br.readBytes(size);
      if (!br.ok) {
        _lastSab = null;
        _lastText = '';
        return const [0];
      }
      _lastSab = bytes;
      _lastText = '';
      return const [2];
    }
    if (version != 1) {
      _lastText = '';
      return const [0];
    }
    final bytes = <int>[];
    while (br.ok) {
      final size = br.bl();
      if (size == 0) break;
      if (size > 10000000 || bytes.length + size > 20000000) break;
      final chunk = br.readBytes(size);
      if (!br.ok) break;
      for (final byte in chunk) {
        bytes.add(byte <= 32 ? byte : 159 - byte);
      }
    }
    _lastText = latin1.decode(bytes, allowInvalid: true);
    return const [1];
  }
}
