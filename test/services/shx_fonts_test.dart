import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fancad/services/shx_fonts.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Uint8List _shx({
  String header = 'AutoCAD-86 shapes 1.0',
  required List<(int code, String name, List<int> shape)> glyphs,
}) {
  final out = <int>[
    ...latin1.encode(header),
    0x1A,
    0,
    0,
    255,
    0,
    glyphs.length & 0xFF,
    (glyphs.length >> 8) & 0xFF,
  ];
  for (final (code, name, shape) in glyphs) {
    final payload = <int>[...latin1.encode(name), 0, ...shape];
    out.add(code & 0xFF);
    out.add((code >> 8) & 0xFF);
    out.add(payload.length & 0xFF);
    out.add((payload.length >> 8) & 0xFF);
    out.addAll(payload);
  }
  return Uint8List.fromList(out);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FANCAD_FONT_PATH and the drawing folder are the only search roots', () {
    final dirs = ShxFontCatalog.searchDirectories(
      drawingPath: '/tmp/drawings/plan.dwg',
      environment: {ShxFontCatalog.envPath: '/opt/extra:/opt/more'},
    );
    expect(dirs, [
      '/opt/extra',
      '/opt/more',
      '/tmp/drawings',
      p.join('/tmp/drawings', 'fonts'),
    ]);
  });

  test('no env and no drawing cannot invent a font folder', () {
    expect(ShxFontCatalog.searchDirectories(environment: const {}), isEmpty);
  });

  test('a later folder of the same family overrides an earlier one', () {
    final first = tempDir(prefix: 'fancad-shx-a');
    final second = tempDir(prefix: 'fancad-shx-b');
    File(p.join(first.path, 'txt.shx')).writeAsBytesSync(
      _shx(
        glyphs: [
          (65, 'A', [1, 8, 4, 0, 0]),
        ],
      ),
    );
    File(p.join(second.path, 'txt.shx')).writeAsBytesSync(
      _shx(
        glyphs: [
          (66, 'B', [1, 8, 4, 0, 0]),
        ],
      ),
    );

    final table = ShxFontCatalog.load(directories: [first.path, second.path]);
    expect(table.isEmpty, isFalse);
    expect(table.lookup('txt')?.glyph(66)?.name, 'B');
    expect(table.lookup('txt')?.glyph(65), isNull);
  });

  test('an empty or truncated SHX file cannot invent a face', () {
    final dir = tempDir(prefix: 'fancad-shx-empty');
    File(p.join(dir.path, 'txt.shx')).writeAsBytesSync(Uint8List(0));
    File(p.join(dir.path, 'notes.txt')).writeAsStringSync('not a font');
    expect(ShxFontCatalog.load(directories: [dir.path]).isEmpty, isTrue);
  });
}
