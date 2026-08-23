import 'dart:async';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an absolute polar point and a bare angle still parse', () {
    final polar = CoordinateParser.parse('10<90');
    expect(polar!.x, closeTo(0, 1e-9));
    expect(polar.y, closeTo(10, 1e-9));
    expect(CoordinateParser.parse('@<45', base: Vec2.zero()), isNull);
    expect(CoordinateParser.parseAngle('180'), closeTo(math.pi, 1e-12));
    expect(CoordinateParser.parseDistance('inf'), isNull);
  });

  test(
    'status, errors and a superseding prompt cannot leave a stale wait',
    () async {
      final line = CommandLineController();
      addTearDown(line.dispose);
      line.writeError('bad');
      line.writeSuccess('ok');
      line.setStatus('LINE');
      expect(line.promptText, 'LINE');
      expect(line.lines.map((item) => item.level), [
        HistoryLevel.error,
        HistoryLevel.success,
      ]);

      final first = line.request(
        PendingEntry(
          message: 'First:',
          completer: Completer<Object?>(),
          accept: (raw) => raw,
        ),
      );
      final second = line.request(
        PendingEntry(
          message: 'Second:',
          completer: Completer<Object?>(),
          accept: (raw) => raw,
          allowEmpty: true,
        ),
      );
      await expectLater(first, throwsA(isA<CommandCancelled>()));
      expect(line.submit(''), isNull);
      expect(await second, '');
    },
  );

  test('Escape cancels a leftover prompt instead of hanging', () async {
    final line = CommandLineController();
    addTearDown(line.dispose);
    expect(line.supplyFromPointer(const Vec2.zero()), isFalse);

    final pending = line.request(
      PendingEntry(
        message: 'Point:',
        completer: Completer<Object?>(),
        accept: (raw) => raw,
      ),
    );
    line.cancelPending();
    await expectLater(pending, throwsA(isA<CommandCancelled>()));
    expect(line.isAwaitingInput, isFalse);
  });
}
