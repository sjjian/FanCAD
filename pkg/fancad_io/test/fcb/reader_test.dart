import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_io/src/fcb/format.dart';
import 'package:fancad_io/src/fcb/reader.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  Uint8List header({
    required int version,
    required int tocCount,
    int extra = 0,
  }) {
    final bytes = Uint8List(fcbHeaderSize + extra);
    final view = ByteData.sublistView(bytes);
    view.setUint32(0, fcbMagic, Endian.little);
    view.setUint16(4, version, Endian.little);
    view.setUint32(8, tocCount, Endian.little);
    return bytes;
  }

  test('an unsupported version cannot look like a valid drawing', () {
    expect(
      () => FcbReader(header(version: fcbVersion + 7, tocCount: 0)),
      throwsA(
        isA<FcbFormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported FCB version'),
        ),
      ),
    );
  });

  test('a truncated TOC or a section past the buffer cannot invent geometry',
      () {
    expect(
      () => FcbReader(header(version: fcbVersion, tocCount: 1, extra: 8)),
      throwsA(
        isA<FcbFormatException>().having(
          (error) => error.message,
          'message',
          contains('Truncated table of contents'),
        ),
      ),
    );

    final overrun = header(
      version: fcbVersion,
      tocCount: 1,
      extra: fcbTocEntrySize,
    );
    final view = ByteData.sublistView(overrun);
    view.setUint32(fcbHeaderSize, FcbSection.entities, Endian.little);
    view.setUint64(fcbHeaderSize + 8, 1024, Endian.little);
    view.setUint64(fcbHeaderSize + 16, 64, Endian.little);
    expect(
      () => FcbReader(overrun),
      throwsA(
        isA<FcbFormatException>().having(
          (error) => error.message,
          'message',
          contains('extends past the end of the buffer'),
        ),
      ),
    );
  });

  eachNamed({
    'six numbers stay at the insertion point': [0.0, 0.0, 2.5, 0.0, 1.0, 0.0],
    'eight numbers use the trailing alignment point': [
      0.0,
      0.0,
      2.5,
      0.0,
      1.0,
      0.0,
      50.0,
      20.0,
    ],
  }, (geom) {
    expect(
      fcbTextPosition(geom),
      geom.length > 6 ? const Vec2(50, 20) : const Vec2(0, 0),
    );
  });

  test('a bad magic is rejected', () {
    expect(() => FcbReader(Uint8List(64)), throwsA(isA<FcbFormatException>()));
  });

  test('a truncated buffer is rejected', () {
    final full = FcbWriter().write(CadDocument());
    final truncated = Uint8List.sublistView(full, 0, 40);
    expect(() => FcbReader(truncated), throwsA(isA<FcbFormatException>()));
  });
}
