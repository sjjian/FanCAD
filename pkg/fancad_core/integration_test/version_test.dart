@Tags(['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/drawing_file_service.dart';
import 'package:fancad_core/src/io/fcb/writer.dart';
import 'package:fancad_core/src/io/native/native_dwg_backend.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG version', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test(
      'an empty R2004 save does not pad the preview page to 1.27MB',
      () async {
        final path = await rt.writeDwg(
          drawing(
            entities: const [
              LineEntity(id: 1, start: Vec2.zero(), end: Vec2(100, 40)),
            ],
          ),
          name: 'preview',
        );
        final bytes = File(path).readAsBytesSync();
        expect(String.fromCharCodes(bytes.sublist(0, 6)), 'AC1018');
        expect(
          bytes.length,
          lessThan(512 * 1024),
          reason: 'R2004 PREVIEW must not be written at the 0x144400 read cap',
        );
        expect(_longestZeroRun(bytes), lessThan(0x10000));

        final opened = (await rt.importer.open(path)).document;
        final lines = opened.entities.whereType<LineEntity>().toList();
        expect(lines, isNotEmpty);
        expect(lines.first.end.x, closeTo(100, 1e-6));
      },
      timeout: Roundtrip.timeout,
    );

    test('r2000 and r2004 both reopen a line', () async {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(100, 40)),
        );
      final fcb = FcbWriter().write(document);
      final backend = NativeDwgBackend();
      final files = drawingFilesWithBackend(backend);
      for (final version in const [2000, 2004]) {
        final directory = tempDir(prefix: 'fancad-r$version');
        final path = '${directory.path}/line.dwg';
        await backend.writeFromFcb(path, fcb, targetVersion: version);
        final bytes = File(path).readAsBytesSync();
        expect(
          String.fromCharCodes(bytes.sublist(0, 6)),
          version == 2000 ? 'AC1015' : 'AC1018',
        );
        final opened = await files.open(path);
        final line = opened.document.entities.whereType<LineEntity>().single;
        expect(line.end.x, closeTo(100, 1e-6));
        expect(line.end.y, closeTo(40, 1e-6));
      }
    }, timeout: Roundtrip.timeout);
  });
}

int _longestZeroRun(Uint8List bytes) {
  var longest = 0;
  var run = 0;
  for (final b in bytes) {
    if (b == 0) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }
  return longest;
}
