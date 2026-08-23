import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));

  test('a parameter span keeps only that remnant of the line', () {
    final mid = Construct.resizedLine(line, 0.25, 0.75);
    expect(mid.start.x, closeTo(2.5, 1e-9));
    expect(mid.end.x, closeTo(7.5, 1e-9));
    expect(mid.id, line.id);

    final whole = Construct.resizedLine(line, 0, 1);
    expect(whole.start, line.start);
    expect(whole.end, line.end);
  });

  test('a collapsed parameter range cannot invent a remnant length', () {
    final point = Construct.resizedLine(line, 0.4, 0.4);
    expect(point.start, point.end);
    expect(point.start.x, closeTo(4, 1e-9));
    expect(point.start.distanceTo(point.end), 0);
  });
}
