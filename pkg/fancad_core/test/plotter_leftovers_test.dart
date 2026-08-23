import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished paper size still plots onto a default sheet', () {
    final document = CadDocument();
    document.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 0,
        paperHeight: 0,
        plotFit: true,
      ),
    );

    final svg = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(svg, startsWith('<?xml'));
    expect(svg, contains('297'));
    expect(svg, contains('210'));
  });

  test('a non-positive plot scale cannot invent a vanished sheet', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    document.addLayout(
      const Layout(
        name: 'Sheet',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotScale: 0,
        plotOffsetX: 5,
      ),
    );

    final svg = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(svg, contains('<svg'));
    expect(svg, isNot(contains('NaN')));
  });

  test('an empty drawing still produces a well-formed PDF sheet', () {
    final pdf = const Plotter().toPdf(CadDocument());
    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });
}
