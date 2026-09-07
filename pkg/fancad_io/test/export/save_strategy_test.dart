import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
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
    expect(dwg.dwgVersion, 2004);
    expect(dwg.usedFallback, isFalse);
  });

  eachCase([
    (
      name: 'notes.txt falls back to FCB',
      path: '/tmp/notes.txt',
      target: '/tmp/notes.fcb',
      reasonHas: '.txt',
    ),
    (
      name: 'a missing extension falls back to FCB',
      path: '/tmp/untitled',
      target: '/tmp/untitled.fcb',
      reasonHas: null,
    ),
    (
      name: 'a dotted parent folder does not steal the file name',
      path: '/tmp/project.v2/untitled',
      target: '/tmp/project.v2/untitled.fcb',
      reasonHas: null,
    ),
  ], (c) {
    const strategy = SaveStrategy();
    final plan = strategy.plan(c.path);
    expect(plan.format, SaveFormat.fcb);
    expect(plan.targetPath, c.target);
    expect(plan.usedFallback, isTrue);
    if (c.reasonHas != null) {
      expect(plan.reason, contains(c.reasonHas));
    }
  });

  test('an unknown or missing extension falls back to FCB', () {
    const strategy = SaveStrategy();
    const blocked = SaveStrategy();
    // A parent folder with a dot must not steal the file name.
    final dwgInDotted = blocked.plan(r'C:\proj.v2\sheet.dwg');
    expect(dwgInDotted.targetPath, r'C:\proj.v2\sheet.dxf');

    final padded = strategy.plan('  /tmp/part.dxf  ');
    expect(padded.format, SaveFormat.dxf);
    expect(padded.targetPath, '/tmp/part.dxf');

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
