import 'dart:typed_data';

/// Converts the binary ACIS "ACIS BinaryFile" (SAB) stream used by R2004
/// REGION/3DSOLID into SAT1 text, following the same tag stream reference
/// writes for DXF.
///
/// The caller feeds the result to `AcisSatReader`.
String? sabToSat1(Uint8List data) {
  if (data.length < 15) return null;
  final magic = String.fromCharCodes(Uint8List.sublistView(data, 0, 15));
  if (!magic.startsWith('ACIS BinaryFile')) return null;

  var at = 15;
  int rc() {
    if (at >= data.length) throw const FormatException('SAB overflow');
    return data[at++];
  }

  int rs() {
    final lo = rc();
    final hi = rc();
    return (hi << 8) | lo;
  }

  int rl() {
    final lo = rs();
    final hi = rs();
    return (hi << 16) | lo;
  }

  int rll() => rl() | (rl() << 32);

  final doubleBytes = ByteData(8);
  final floatBytes = ByteData(4);

  double rd() {
    for (var i = 0; i < 8; i++) {
      doubleBytes.setUint8(i, rc());
    }
    return doubleBytes.getFloat64(0, Endian.little);
  }

  double rlFloat() {
    floatBytes.setUint32(0, rl(), Endian.little);
    return floatBytes.getFloat32(0, Endian.little);
  }

  String readTaggedString() {
    rc(); // tag
    final len = rc();
    final end = at + len;
    if (end > data.length) throw const FormatException('SAB string overflow');
    final value = String.fromCharCodes(Uint8List.sublistView(data, at, end));
    at = end;
    return value;
  }

  final out = StringBuffer();
  try {
    final version = rl();
    final numRecords = rl();
    final numEntities = rl();
    final hasHistory = rl();
    out.write('$version $numRecords $numEntities $hasHistory \n');

    readTaggedString(); // product
    readTaggedString(); // acis version
    readTaggedString(); // date
    out.write('\n');

    rc();
    rd();
    rc();
    rd();
    rc();
    rd();
    out.write('\n');

    var tag = rc();
    var actRecord = '';
    var lineLength = 0;
    final line = StringBuffer();

    void flushLine() {
      if (lineLength >= 250) {
        out.write('\n');
        lineLength = 0;
      }
    }

    void writeText(String value) {
      flushLine();
      line.write(value);
      lineLength += value.length;
    }

    while (at < data.length) {
      switch (tag) {
        case 17: // end of record
          out.write(line.toString());
          out.write('#\n');
          line.clear();
          lineLength = 0;
          break;
        case 13: // identifier
        case 7: // char length
        case 14: // subidentifier
          final len = rc();
          if (len == 0) {
            out.write(line.toString());
            return out.toString();
          }
          final end = at + len;
          if (end > data.length) return null;
          final value = String.fromCharCodes(
            Uint8List.sublistView(data, at, end),
          );
          if (tag == 14) {
            writeText('$value-');
          } else {
            writeText('$value ');
          }
          if (tag == 13) actRecord = value;
          at = end;
          break;
        case 8:
          final len = rs();
          final end = at + len;
          if (end > data.length) return null;
          writeText(
            '${String.fromCharCodes(Uint8List.sublistView(data, at, end))} ',
          );
          at = end;
          break;
        case 9:
        case 18: // long string, used by newer writers for transform records
          final len = rl();
          final end = at + len;
          if (end > data.length) return null;
          writeText(
            '${String.fromCharCodes(Uint8List.sublistView(data, at, end))} ',
          );
          at = end;
          break;
        case 10:
          writeText('${_boolean(actRecord, true)} ');
          break;
        case 11:
          writeText('${_boolean(actRecord, false)} ');
          break;
        case 15:
          writeText('{ ');
          break;
        case 16:
          writeText('} ');
          break;
        case 2:
          writeText('${_toSigned(rc(), 8)} ');
          break;
        case 3:
          writeText('${_toSigned(rs(), 16)} ');
          break;
        case 4:
        case 21:
          writeText('\$${_toSigned(rl(), 32)} ');
          break;
        case 5:
          writeText('${rlFloat()} ');
          break;
        case 12:
          writeText('\$${_toSigned(rl(), 32)} ');
          break;
        case 6:
          writeText('${rd()} ');
          break;
        case 19:
        case 20:
          writeText('${rd()} ');
          writeText('${rd()} ');
          writeText('${rd()} ');
          break;
        case 23:
          writeText('\$${rll()} ');
          break;
        default:
          // Trailing bytes after the End-of-ACIS-data marker are not SAB.
          out.write(line.toString());
          out.write('\n');
          return out.toString();
      }
      if (at >= data.length) break;
      tag = rc();
    }
    out.write(line.toString());
    out.write('\n');
    return out.toString();
  } on FormatException catch (e) {
    // ignore: avoid_print
    print('SAB exception at $at: $e');
    return null;
  }
}

String _boolean(String record, bool value) {
  switch (record) {
    case 'edge':
    case 'spline':
    case 'meshsurf':
    case 'pcurve':
    case 'intcurve':
      return value ? 'reversed' : 'forward';
    case 'face':
      return value ? 'reversed' : 'forward';
    case 'sphere':
    case 'plane':
    case 'stripc':
    case 'torus':
      return value ? 'reverse_v' : 'forward_v';
    default:
      return value ? 'true' : 'false';
  }
}

int _toSigned(int value, int bits) {
  final sign = 1 << (bits - 1);
  return (value & sign) != 0 ? value - (1 << bits) : value;
}
