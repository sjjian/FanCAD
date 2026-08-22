import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  test('identical drawings are clean', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    final report = const FidelityAuditor().compare(document, document);
    expect(report.isClean, isTrue);
  });

  test('a lost paper tab is not a clean round trip', () {
    final source = CadDocument();
    source.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    source.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
      ),
    );
    final target = CadDocument();
    target.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingLayouts, contains('A3'));
    expect(report.summary, contains('A3'));
  });

  test('entities that moved from paper to model are reported', () {
    final source = CadDocument();
    source.addLayout(
      const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
    );
    source.addEntity(
      const LineEntity(id: 0, start: Vec2(10, 10), end: Vec2(40, 10)),
      blockName: '*Paper_Space',
    );
    final target = CadDocument();
    target.addLayout(
      const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
    );
    target.addEntity(
      const LineEntity(id: 0, start: Vec2(10, 10), end: Vec2(40, 10)),
    );

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingByKind, isEmpty);
    expect(report.missingBySpace['*Paper_Space'], 1);
  });

  test('a changed sheet size is a layout mismatch', () {
    final source = CadDocument();
    source.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
      ),
    );
    final target = CadDocument();
    target.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 297,
        paperHeight: 210,
      ),
    );

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.layoutMismatches, isNotEmpty);
    expect(report.layoutMismatches.single, contains('Sheet'));
  });

  test('a lost xref path is not a clean round trip', () {
    final source = CadDocument();
    source.putBlock(
      const BlockRecord(
        name: 'BRACKET',
        xrefPath: r'C:\parts\bracket.dxf',
        description: r'Xref C:\parts\bracket.dxf',
      ),
    );
    final target = CadDocument();
    target.putBlock(const BlockRecord(name: 'BRACKET'));

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingXrefs, contains('BRACKET'));
    expect(report.summary, contains('BRACKET'));
  });

  test('an xref whose file path changed is reported', () {
    final source = CadDocument();
    source.putBlock(
      const BlockRecord(name: 'PART', xrefPath: '/tmp/old.dxf'),
    );
    final target = CadDocument();
    target.putBlock(
      const BlockRecord(name: 'PART', xrefPath: '/tmp/new.dxf'),
    );

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.xrefMismatches.single, contains('PART'));
    expect(report.xrefMismatches.single, contains('/tmp/old.dxf'));
  });

  test('a lost layer, extra sheet and extra xref are not a clean trip', () {
    final source = CadDocument();
    source.putLayer(const LayerDef(name: 'DIM'));
    source.putBlock(
      const BlockRecord(name: 'ONLY_HERE', xrefPath: '/tmp/only.dxf'),
    );

    final target = CadDocument();
    target.addLayout(
      const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
    );
    target.putBlock(
      const BlockRecord(name: 'NEW_XREF', xrefPath: '/tmp/new.dxf'),
    );
    target.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );

    final report = const FidelityAuditor().compare(source, target);
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

  test('a changed plot rotation is a layout mismatch', () {
    final source = CadDocument();
    source.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotRotation: 0,
      ),
    );
    final target = CadDocument();
    target.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotRotation: 90,
      ),
    );

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.layoutMismatches.single, contains('plot rotation'));
  });

  test('an identical pair still reports a clean summary', () {
    final document = CadDocument();
    final report = const FidelityAuditor().compare(document, document);
    expect(report.isClean, isTrue);
    expect(report.summary, contains('kept all 0 entities'));
    expect(report.toJson()['clean'], isTrue);
  });
}
