@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG multileader', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test(
      'a CJK multileader note stays visible through DWG save',
      () async {
        final opened = await rt.dwg(
          drawingOf(
            MLeaderEntity(
              id: 1,
              vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
              content: r'{\F宋体|c134;注释}',
              textPosition: const Vec2(16, 10),
              textHeight: 35,
              attachment: 6,
            ),
          ),
          name: 'mleader',
        );
        final sink = PolylineSink();
        for (final entity in opened.entities) {
          entity.emit(opened.emitContext(tolerance: 0.1), sink);
        }
        expect(sink.texts.any((run) => run.text.contains('注释')), isTrue);
        expect(sink.texts.any((run) => run.fontFamily == '宋体'), isTrue);
      },
      timeout: Roundtrip.timeout,
    );
  });
}
