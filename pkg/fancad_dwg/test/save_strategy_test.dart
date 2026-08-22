import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  test('DXF and FCB paths keep the requested format', () {
    const strategy = SaveStrategy();
    final dxf = strategy.plan('/tmp/part.DXF');
    expect(dxf.format, SaveFormat.dxf);
    expect(dxf.targetPath, '/tmp/part.DXF');
    expect(dxf.usedFallback, isFalse);
    expect(dxf.reason, isEmpty);

    final fcb = strategy.plan(r'C:\drawings\a.fcb');
    expect(fcb.format, SaveFormat.fcb);
    expect(fcb.usedFallback, isFalse);
  });

  test('DWG falls back to a sibling DXF when the writer is missing', () {
    const blocked = SaveStrategy();
    final plan = blocked.plan('/work/sheet.dwg');
    expect(plan.format, SaveFormat.dxf);
    expect(plan.targetPath, '/work/sheet.dxf');
    expect(plan.fallbackPath, '/work/sheet.dxf');
    expect(plan.usedFallback, isTrue);
    expect(plan.reason, contains('cannot write DWG'));

    const native = SaveStrategy(canWriteDwg: true);
    final dwg = native.plan('/work/sheet.dwg');
    expect(dwg.format, SaveFormat.dwg);
    expect(dwg.targetPath, '/work/sheet.dwg');
    expect(dwg.dwgVersion, 2000);
    expect(dwg.usedFallback, isFalse);
  });

  test('an unknown or missing extension falls back to FCB', () {
    const strategy = SaveStrategy();
    final unknown = strategy.plan('/tmp/notes.txt');
    expect(unknown.format, SaveFormat.fcb);
    expect(unknown.targetPath, '/tmp/notes.fcb');
    expect(unknown.usedFallback, isTrue);
    expect(unknown.reason, contains('.txt'));

    final none = strategy.plan('/tmp/untitled');
    expect(none.targetPath, '/tmp/untitled.fcb');
    expect(none.format, SaveFormat.fcb);

    const outcome = SaveOutcome(
      plan: SavePlan(
        targetPath: '/tmp/untitled.fcb',
        format: SaveFormat.fcb,
        fallbackPath: '/tmp/untitled.fcb',
      ),
      path: '/tmp/untitled.fcb',
    );
    expect(outcome.usedFallback, isTrue);
  });
}
