@Tags(['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('a CJK multileader note stays visible through DWG save', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-mleader');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(
        MLeaderEntity(
          id: 1,
          vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
          content: r'{\F宋体|c134;注释}',
          textPosition: const Vec2(16, 10),
          textHeight: 35,
          attachment: 6,
        ),
      );

    final importer = DrawingImporter();
    final path = '${directory.path}/note.dwg';
    await importer.save(path, document);
    final opened = await importer.open(path);

    final sink = PolylineSink();
    for (final entity in opened.document.entities) {
      entity.emit(const EmitContext(tolerance: 0.1), sink);
    }
    expect(sink.texts.any((run) => run.text.contains('注释')), isTrue);
    expect(sink.texts.any((run) => run.fontFamily == '宋体'), isTrue);
  });
}
