@Tags(['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('an empty R2004 save does not pad the preview page to 1.27MB', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-preview');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument();
    final session = DocumentSession(id: 'preview', document: document);
    session.edit('line', (transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(100, 40)),
      );
    });

    final path = '${directory.path}/note.dwg';
    await DrawingImporter().save(path, document);
    final bytes = File(path).readAsBytesSync();

    expect(String.fromCharCodes(bytes.sublist(0, 6)), 'AC1018');
    expect(
      bytes.length,
      lessThan(512 * 1024),
      reason: 'R2004 PREVIEW must not be written at the 0x144400 read cap',
    );
    expect(longestZeroRun(bytes), lessThan(0x10000));

    final opened = await DrawingImporter().open(path);
    final lines = opened.document.entities.whereType<LineEntity>().toList();
    expect(lines, isNotEmpty);
    expect(lines.first.end.x, closeTo(100, 1e-6));
  }, timeout: Timeout.parse('2m'));
}

int longestZeroRun(Uint8List bytes) {
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
