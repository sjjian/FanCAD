import 'dart:async';
import 'dart:math' as math;

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoordinateParser', () {
    test('absolute, relative and polar forms resolve to a point', () {
      expect(CoordinateParser.parse('10,20'), const Vec2(10, 20));
      expect(
        CoordinateParser.parse('@5,0', base: const Vec2(2, 3)),
        const Vec2(7, 3),
      );
      expect(CoordinateParser.parse('@5,0'), isNull);
      final polar = CoordinateParser.parse('@10<90', base: Vec2.zero());
      expect(polar!.x, closeTo(0, 1e-9));
      expect(polar.y, closeTo(10, 1e-9));
      expect(CoordinateParser.parse(''), isNull);
      expect(CoordinateParser.parse('nope'), isNull);
      expect(CoordinateParser.parseDistance('2.5'), 2.5);
      expect(CoordinateParser.parseDistance('x'), isNull);
      expect(CoordinateParser.parseAngle('<90'), closeTo(math.pi / 2, 1e-12));
    });
  });

  group('CommandLineController', () {
    test('empty writes are ignored and the history is capped', () {
      final line = CommandLineController(historyLimit: 2);
      line.write('');
      expect(line.lines, isEmpty);
      line.write('one\ntwo\nthree');
      expect(line.lines.map((item) => item.text), ['two', 'three']);
      line.clear();
      expect(line.lines, isEmpty);
    });

    test('a leftover log click offers text without submitting it', () {
      final line = CommandLineController();
      line.offerInput('LINE');
      expect(line.offeredInput, 'LINE');
      expect(line.takeOfferedInput(), 'LINE');
      expect(line.offeredInput, isNull);
      expect(line.submit('LINE'), 'LINE');
    });

    test('submit feeds a prompt or returns a command when idle', () async {
      final line = CommandLineController();
      expect(line.submit('LINE'), 'LINE');
      expect(line.enteredHistory, ['LINE']);

      final future = line.request(
        PendingEntry(
          message: 'From point:',
          completer: Completer<Object?>(),
          accept: (raw) => CoordinateParser.parse(raw),
        ),
      );
      expect(line.isAwaitingInput, isTrue);
      expect(line.submit('nope'), isNull);
      expect(
        line.lines.any((item) => item.level == HistoryLevel.error),
        isTrue,
      );
      expect(line.submit('1,2'), isNull);
      expect(await future, const Vec2(1, 2));
      expect(line.isAwaitingInput, isFalse);
    });

    test(
      'empty Enter cancels, a pointer can answer, and recall walks history',
      () async {
        final line = CommandLineController();
        final cancelled = line.request(
          PendingEntry(
            message: 'Point:',
            completer: Completer<Object?>(),
            accept: (raw) => raw,
          ),
        );
        expect(line.submit(''), isNull);
        await expectLater(cancelled, throwsA(isA<CommandCancelled>()));

        final fromPointer = line.request(
          PendingEntry(
            message: 'Point:',
            completer: Completer<Object?>(),
            accept: (raw) => raw,
          ),
        );
        expect(line.supplyFromPointer(const Vec2(4, 5)), isTrue);
        expect(await fromPointer, const Vec2(4, 5));

        line.submit('A');
        line.submit('B');
        expect(line.recallPrevious(), 'B');
        expect(line.recallPrevious(), 'A');
        expect(line.recallNext(), 'B');
        expect(line.recallNext(), '');
      },
    );
  });
}
