import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('HatchPattern', () {
    test('names are case-insensitive and unknown names fall back to ANSI31', () {
      expect(HatchPattern.named('ansi31').name, 'ANSI31');
      expect(HatchPattern.named('nope').name, 'ANSI31');
      expect(HatchPattern.named('NOPE').lines, HatchPattern.named('ansi31').lines);
      expect(HatchPattern.named('SOLID').lines, isEmpty);
      expect(HatchPattern.named('net').name, 'NET');
      expect(HatchPattern.named('DOTS').lines, isNotEmpty);
      expect(HatchPattern.builtIn.containsKey('NET'), isTrue);
    });
  });
}
