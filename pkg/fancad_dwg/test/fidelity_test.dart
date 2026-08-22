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
}
