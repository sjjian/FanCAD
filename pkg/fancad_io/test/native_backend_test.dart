@Tags(['native'])
library;

import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// Guards the half of the build that CI can only exercise when LibreDWG is
/// actually present. Without these, a broken link step would look identical to
/// a deliberate backend-less build.
void main() {
  late NativeDrawingBackend backend;

  setUpAll(() => backend = NativeDrawingBackend());

  test('the shim loads and reports a version', () {
    expect(backend.capabilities.description, isNotEmpty);
    expect(
      backend.capabilities.description,
      isNot(contains('unavailable')),
      reason: 'The code asset did not load',
    );
  });

  test('the DWG backend is linked', () {
    expect(
      backend.capabilities.readDwg,
      isTrue,
      reason:
          'Built without LibreDWG: ${backend.capabilities.description}. '
          'Set FANCAD_LIBREDWG_ROOT and rebuild.',
    );
    expect(backend.capabilities.writeDwg, isTrue);
  });

  test('a line survives DXF to DWG and back', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-libredwg');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument();
    final session = DocumentSession(id: 'native', document: document);
    session.edit('line', (transaction) {
      transaction.add(
        LineEntity(
          id: 0,
          start: const Vec2.zero(),
          end: const Vec2(100, 40),
        ),
      );
    });

    final dxfPath = '${directory.path}/line.dxf';
    final dwgPath = '${directory.path}/line.dwg';
    await const DxfWriter().writeFile(dxfPath, document);
    await backend.exportDwgFromDxf(dxfPath, dwgPath, targetVersion: 2000);
    expect(File(dwgPath).existsSync(), isTrue);
    expect(File(dwgPath).lengthSync(), greaterThan(0));

    final opened = await DrawingImporter(backend: backend).open(dwgPath);
    final lines = opened.document.entities.whereType<LineEntity>().toList();
    expect(lines, isNotEmpty);
    expect(lines.first.end.x, closeTo(100, 1e-6));
    expect(lines.first.end.y, closeTo(40, 1e-6));
  });

  test('the native FCB version matches the Dart reader', () {
    // A mismatch here means the C and Dart sides of the format have drifted,
    // which would surface as corrupt geometry rather than a clean error.
    expect(backend.nativeFcbVersion, fcbVersion);
  });

  test('DWG import keeps layout names and paper size', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-layout');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument();
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
      ),
    );
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      blockName: '*Paper_Space',
    );

    final dxfPath = '${directory.path}/sheet.dxf';
    final dwgPath = '${directory.path}/sheet.dwg';
    await const DxfWriter().writeFile(dxfPath, document);
    await backend.exportDwgFromDxf(dxfPath, dwgPath, targetVersion: 2000);

    final opened = await DrawingImporter(backend: backend).open(dwgPath);
    expect(
      opened.document.blocks.containsKey('*Paper_Space'),
      isTrue,
      reason: 'the paper block should survive DXF to DWG',
    );
    expect(
      opened.document.entitiesOf('*Paper_Space').whereType<LineEntity>(),
      isNotEmpty,
      reason: 'paper-space geometry should stay out of model space',
    );
    final paper = opened.document.layouts
        .where((item) => !item.isModelSpace)
        .toList();
    expect(paper, isNotEmpty, reason: 'a paper LAYOUT should survive DWG');
    final named = paper.where((item) => item.name == 'A3');
    if (named.isNotEmpty) {
      expect(named.single.paperWidth, closeTo(420, 1));
      expect(named.single.paperHeight, closeTo(297, 1));
    }
  });

  test('BLOCK/ENDBLK stay out of the entity list and base points survive', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-block');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'TICK', basePoint: Vec2(100, 50)))
      ..addEntity(
        const LineEntity(id: 1, start: Vec2(100, 50), end: Vec2(101, 50)),
        blockName: 'TICK',
      )
      ..addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'TICK',
          position: Vec2(10, 20),
        ),
      );

    final dxfPath = '${directory.path}/tick.dxf';
    final dwgPath = '${directory.path}/tick.dwg';
    await const DxfWriter().writeFile(dxfPath, document);
    await backend.exportDwgFromDxf(dxfPath, dwgPath, targetVersion: 2000);

    final opened = await DrawingImporter(backend: backend).open(dwgPath);
    expect(
      opened.document.entities
          .whereType<UnknownEntity>()
          .map((entity) => entity.originalType),
      isNot(anyOf(contains('BLOCK'), contains('ENDBLK'))),
    );
    expect(
      opened.document.blocks['TICK']?.basePoint,
      const Vec2(100, 50),
    );
  });

  test('a missing file fails cleanly rather than crashing', () {
    expect(
      () => backend.readToFcb('/definitely/not/a/drawing.dwg'),
      throwsA(isA<ImportException>()),
    );
  });
}
