@Tags(['native'])
library;

import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// HunterDouglas process drawing whose dimension note is
/// `{\F宋体|c134;型材1}`. CI does not ship it.
const String _sample =
    '/Users/sunjian/Downloads/亨特道格拉斯/案例2/'
    'SOAS00009323---FL25预埋型材/工艺-00009323.dwg';

void main() {
  test(
    'a CJK font-coded dimension note paints glyphs after save-reopen',
    () async {
      if (!File(_sample).existsSync()) {
        markTestSkipped('sample DWG is not on this machine');
        return;
      }

      final importer = DrawingImporter();
      final source = (await importer.open(_sample)).document;
      final coded = _fontCodedNotes(source);
      expect(
        coded,
        isNotEmpty,
        reason: 'the sample stores 型材1 behind an MTEXT font switch',
      );
      for (final dim in coded) {
        _expectGlyphs(source, dim);
      }

      final clip = DrawingClip.extract(
        source,
        coded.map((dim) => dim.id),
        basePoint: coded.first.textPosition,
      );
      expect(clip, isNotNull);
      final slice = CadDocument();
      final paste = Transaction(slice, label: 'slice');
      clip!.paste(paste, insertion: clip.basePoint);
      paste.commit();

      final directory = Directory.systemTemp.createTempSync('fancad-dimcjk');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/note.dwg';
      await importer.save(path, slice);
      final opened = (await importer.open(path)).document;
      final reopened = _fontCodedNotes(opened);
      expect(reopened, isNotEmpty);
      for (final dim in reopened) {
        _expectGlyphs(opened, dim);
      }
    },
    timeout: Timeout.parse('2m'),
  );
}

List<DimensionEntity> _fontCodedNotes(CadDocument document) => [
  for (final entity in document.entities)
    if (entity is DimensionEntity &&
        entity.overrideText.contains('型材1') &&
        (entity.overrideText.contains(r'\F') ||
            entity.overrideText.contains(r'\f')))
      entity,
];

void _expectGlyphs(CadDocument document, DimensionEntity dim) {
  final sink = PolylineSink();
  dim.emit(document.emitContext(tolerance: 0.1), sink);
  final painted = sink.texts.map((item) => item.text).join();
  expect(painted, contains('型材1'));
  expect(
    painted.contains(r'\F') || painted.contains(r'\f') || painted.contains('{'),
    isFalse,
    reason: 'MTEXT font codes must not remain in the painted string',
  );
}
