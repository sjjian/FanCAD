import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown pattern name cannot invent a new family', () {
    final fallback = HatchPattern.named('NOPE');
    expect(fallback.name, 'ANSI31');
    expect(fallback.lines, HatchPattern.named('ansi31').lines);
  });

  test('built-in names resolve case-insensitively', () {
    expect(HatchPattern.named('net').name, 'NET');
    expect(HatchPattern.named('DOTS').lines, isNotEmpty);
    expect(HatchPattern.named('SOLID').lines, isEmpty);
  });
}
