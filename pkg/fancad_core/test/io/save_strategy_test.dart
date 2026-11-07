import 'package:fancad_core/src/core.dart';
import 'package:fancad_core/src/io/save_strategy.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('DXF keeps the requested path and format', () {
    const strategy = SaveStrategy();
    final dxf = strategy.plan('/tmp/part.DXF');
    expect(dxf.format, SaveFormat.dxf);
    expect(dxf.targetPath, '/tmp/part.DXF');
    expect(dxf.usedFallback, isFalse);
    expect(dxf.reason, isEmpty);
  });

  test('DWG is written when the document is representable', () {
    const strategy = SaveStrategy(canWriteDwg: true);
    final plan = strategy.plan('/work/sheet.dwg');
    expect(plan.format, SaveFormat.dwg);
    expect(plan.targetPath, '/work/sheet.dwg');
    expect(plan.usedFallback, isFalse);
  });

  test(
    'DWG falls back to a sibling DXF when the writer cannot represent it',
    () {
      const blocked = SaveStrategy();
      final plan = blocked.plan('/work/sheet.dwg');
      expect(plan.format, SaveFormat.dxf);
      expect(plan.targetPath, '/work/sheet.dxf');
      expect(plan.fallbackPath, '/work/sheet.dxf');
      expect(plan.usedFallback, isTrue);
      expect(plan.reason, contains('cannot be written as DWG'));
    },
  );

  eachCase(
    [
      (
        name: 'notes.txt falls back to DXF',
        path: '/tmp/notes.txt',
        target: '/tmp/notes.dxf',
        reasonHas: '.txt',
      ),
      (
        name: 'a missing extension falls back to DXF',
        path: '/tmp/untitled',
        target: '/tmp/untitled.dxf',
        reasonHas: null,
      ),
      (
        name: 'the removed FCB format falls back to DXF',
        path: '/tmp/part.fcb',
        target: '/tmp/part.dxf',
        reasonHas: '.fcb',
      ),
      (
        name: 'a dotted parent folder does not steal the file name',
        path: '/tmp/project.v2/untitled',
        target: '/tmp/project.v2/untitled.dxf',
        reasonHas: null,
      ),
    ],
    (c) {
      const strategy = SaveStrategy();
      final plan = strategy.plan(c.path);
      expect(plan.format, SaveFormat.dxf);
      expect(plan.targetPath, c.target);
      expect(plan.usedFallback, isTrue);
      if (c.reasonHas != null) {
        expect(plan.reason, contains(c.reasonHas));
      }
    },
  );

  test('a dotted parent folder and padding do not confuse the extension', () {
    const blocked = SaveStrategy();
    final dwgInDotted = blocked.plan(r'C:\proj.v2\sheet.dwg');
    expect(dwgInDotted.targetPath, r'C:\proj.v2\sheet.dxf');

    const strategy = SaveStrategy();
    final padded = strategy.plan('  /tmp/part.dxf  ');
    expect(padded.format, SaveFormat.dxf);
    expect(padded.targetPath, '/tmp/part.dxf');

    const outcome = SavedDrawing(
      path: '/tmp/untitled.dxf',
      usedFallback: true,
      reason: 'unknown extension',
    );
    expect(outcome.usedFallback, isTrue);
  });
}
