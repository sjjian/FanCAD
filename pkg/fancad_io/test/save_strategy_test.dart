import 'package:fancad_io/fancad_io.dart';
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

    // A parent folder with a dot must not steal the file name.
    final dottedDir = strategy.plan('/tmp/project.v2/untitled');
    expect(dottedDir.targetPath, '/tmp/project.v2/untitled.fcb');
    expect(dottedDir.format, SaveFormat.fcb);

    const blocked = SaveStrategy();
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
