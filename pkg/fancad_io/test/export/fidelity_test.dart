import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  const auditor = FidelityAuditor();

  test('identical drawings are clean', () {
    final document = drawing(
      entities: const [
        LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      ],
    );
    final report = auditor.compare(document, document);
    expect(report.isClean, isTrue);
  });

  test('an identical pair still reports a clean summary', () {
    final document = CadDocument();
    final report = auditor.compare(document, document);
    expect(report.isClean, isTrue);
    expect(report.summary, contains('kept all 0 entities'));
    expect(report.toJson()['clean'], isTrue);
  });

  test('a lost paper tab is not a clean round trip', () {
    final source = drawing(
      entities: const [
        LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      ],
    )..addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
      ),
    );
    final target = drawing(
      entities: const [
        LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      ],
    );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingLayouts, contains('A3'));
    expect(report.summary, contains('A3'));
  });

  test('entities that moved from paper to model are reported', () {
    final source = CadDocument()
      ..addLayout(
        const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
      )
      ..addEntity(
        const LineEntity(id: 0, start: Vec2(10, 10), end: Vec2(40, 10)),
        blockName: '*Paper_Space',
      );
    final target = CadDocument()
      ..addLayout(
        const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
      )
      ..addEntity(
        const LineEntity(id: 0, start: Vec2(10, 10), end: Vec2(40, 10)),
      );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingByKind, isEmpty);
    expect(report.missingBySpace['*Paper_Space'], 1);
  });

  test('a changed sheet size is a layout mismatch', () {
    final source = CadDocument()
      ..addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
    final target = CadDocument()
      ..addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.layoutMismatches, isNotEmpty);
    expect(report.layoutMismatches.single, contains('Sheet'));
  });

  test('a changed plot rotation is a layout mismatch', () {
    final source = CadDocument()
      ..addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          plotRotation: 0,
        ),
      );
    final target = CadDocument()
      ..addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          plotRotation: 90,
        ),
      );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.layoutMismatches.single, contains('plot rotation'));
  });

  test('a lost xref path is not a clean round trip', () {
    final source = drawing(
      blocks: const [
        BlockRecord(
          name: 'BRACKET',
          xrefPath: r'C:\parts\bracket.dxf',
          description: r'Xref C:\parts\bracket.dxf',
        ),
      ],
    );
    final target = drawing(
      blocks: const [BlockRecord(name: 'BRACKET')],
    );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingXrefs, contains('BRACKET'));
    expect(report.summary, contains('BRACKET'));
  });

  test('an xref whose file path changed is reported', () {
    final source = drawing(
      blocks: const [BlockRecord(name: 'PART', xrefPath: '/tmp/old.dxf')],
    );
    final target = drawing(
      blocks: const [BlockRecord(name: 'PART', xrefPath: '/tmp/new.dxf')],
    );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.xrefMismatches.single, contains('PART'));
    expect(report.xrefMismatches.single, contains('/tmp/old.dxf'));
  });

  test('a lost layer, extra sheet and extra xref are not a clean trip', () {
    final source = drawing(
      layers: const [LayerDef(name: 'DIM')],
      blocks: const [
        BlockRecord(name: 'ONLY_HERE', xrefPath: '/tmp/only.dxf'),
      ],
    );

    final target = CadDocument()
      ..addLayout(
        const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
      )
      ..putBlock(
        const BlockRecord(name: 'NEW_XREF', xrefPath: '/tmp/new.dxf'),
      )
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingLayers, contains('DIM'));
    expect(report.extraLayouts, contains('A3'));
    expect(report.missingXrefs, contains('ONLY_HERE'));
    expect(report.extraXrefs, contains('NEW_XREF'));
    expect(report.extraByKind['line'], 1);
    expect(report.summary, contains('missing layers DIM'));
    expect(report.summary, contains('extra layouts A3'));
    expect(report.summary, contains('extra xrefs NEW_XREF'));
    expect(report.toJson()['clean'], isFalse);
    expect(report.toJson()['missingLayers'], ['DIM']);
  });

  test('a lost circle and an extra paper line are not a clean trip', () {
    final source = CadDocument()
      ..addEntity(const CircleEntity(id: 0, center: Vec2.zero(), radius: 4))
      ..addLayout(
        const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
      );

    final target = CadDocument()
      ..addLayout(
        const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
      )
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(8, 0)),
        blockName: '*Paper_Space',
      );

    final report = auditor.compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingByKind['circle'], 1);
    expect(report.extraByKind['line'], 1);
    expect(report.extraBySpace['*Paper_Space'], 1);
    expect(report.summary, contains('lost 1 circle'));
    expect(report.summary, contains('gained 1 on *Paper_Space'));
  });

  eachCase([
    (
      name: 'a changed plot window is a layout mismatch',
      mismatch: 'plot window changed',
      target: CadDocument()
        ..addLayout(
          const Layout(
            name: 'Sheet',
            blockName: '*Paper_Space',
            tabOrder: 1,
            plotWindow: Bounds2(0, 0, 50, 40),
            plotScale: 2,
            viewports: [
              PaperViewport(
                paperBounds: Bounds2(10, 10, 200, 150),
                modelCenter: Vec2(0, 0),
                scale: 1,
              ),
            ],
          ),
        ),
    ),
    (
      name: 'a changed plot scale is a layout mismatch',
      mismatch: 'plot scale or offset changed',
      target: CadDocument()
        ..addLayout(
          const Layout(
            name: 'Sheet',
            blockName: '*Paper_Space',
            tabOrder: 1,
            plotWindow: Bounds2(0, 0, 100, 80),
            plotScale: 4,
            viewports: [
              PaperViewport(
                paperBounds: Bounds2(10, 10, 200, 150),
                modelCenter: Vec2(0, 0),
                scale: 1,
              ),
            ],
          ),
        ),
    ),
    (
      name: 'a changed viewport is a layout mismatch',
      mismatch: 'viewport 1 changed',
      target: CadDocument()
        ..addLayout(
          const Layout(
            name: 'Sheet',
            blockName: '*Paper_Space',
            tabOrder: 1,
            plotWindow: Bounds2(0, 0, 100, 80),
            plotScale: 2,
            viewports: [
              PaperViewport(
                paperBounds: Bounds2(10, 10, 200, 150),
                modelCenter: Vec2(0, 0),
                scale: 2,
              ),
            ],
          ),
        ),
    ),
  ], (c) {
    const viewport = PaperViewport(
      paperBounds: Bounds2(10, 10, 200, 150),
      modelCenter: Vec2(0, 0),
      scale: 1,
    );
    final source = CadDocument()
      ..addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          plotWindow: Bounds2(0, 0, 100, 80),
          plotScale: 2,
          viewports: [viewport],
        ),
      );
    expect(
      auditor.compare(source, c.target).layoutMismatches.single,
      contains(c.mismatch),
    );
  });
}
