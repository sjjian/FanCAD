import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('a lost circle and an extra paper line are not a clean trip', () {
    final source = CadDocument();
    source.addEntity(const CircleEntity(id: 0, center: Vec2.zero(), radius: 4));
    source.addLayout(
      const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
    );

    final target = CadDocument();
    target.addLayout(
      const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
    );
    target.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: '*Paper_Space',
    );

    final report = const FidelityAuditor().compare(source, target);
    expect(report.isClean, isFalse);
    expect(report.missingByKind['circle'], 1);
    expect(report.extraByKind['line'], 1);
    expect(report.extraBySpace['*Paper_Space'], 1);
    expect(report.summary, contains('lost 1 circle'));
    expect(report.summary, contains('gained 1 on *Paper_Space'));
  });

  test('a changed plot window, scale or viewport is a layout mismatch', () {
    const viewport = PaperViewport(
      paperBounds: Bounds2(10, 10, 200, 150),
      modelCenter: Vec2(0, 0),
      scale: 1,
    );
    final source = CadDocument();
    source.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotWindow: Bounds2(0, 0, 100, 80),
        plotScale: 2,
        viewports: [viewport],
      ),
    );

    final windowTarget = CadDocument();
    windowTarget.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotWindow: Bounds2(0, 0, 50, 40),
        plotScale: 2,
        viewports: [viewport],
      ),
    );
    expect(
      const FidelityAuditor()
          .compare(source, windowTarget)
          .layoutMismatches
          .single,
      contains('plot window changed'),
    );

    final scaleTarget = CadDocument();
    scaleTarget.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotWindow: Bounds2(0, 0, 100, 80),
        plotScale: 4,
        viewports: [viewport],
      ),
    );
    expect(
      const FidelityAuditor()
          .compare(source, scaleTarget)
          .layoutMismatches
          .single,
      contains('plot scale or offset changed'),
    );

    final viewportTarget = CadDocument();
    viewportTarget.addLayout(
      Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotWindow: const Bounds2(0, 0, 100, 80),
        plotScale: 2,
        viewports: [viewport.copyWith(scale: 2)],
      ),
    );
    expect(
      const FidelityAuditor()
          .compare(source, viewportTarget)
          .layoutMismatches
          .single,
      contains('viewport 1 changed'),
    );
  });
}
