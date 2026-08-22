import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty drawing still produces a well-formed SVG sheet', () {
    final svg = const Plotter().toSvg(CadDocument());
    expect(svg, startsWith('<?xml'));
    expect(svg, contains('<svg'));
    expect(svg, contains('</svg>'));
    expect(svg, contains('297'));
  });

  test('a model-space plot skips hidden entities', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(visible: false),
          start: Vec2.zero(),
          end: Vec2(8, 0),
        ),
      )
      ..addEntity(const PointEntity(id: 0, position: Vec2(2, 2)));
    final svg = const Plotter().toSvg(document);
    expect(svg, contains('<circle'));
    expect(svg, isNot(contains('M 0.0 0.0')));
  });

  test('a paper-space plot skips a hidden layer', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'NOTES', visible: false));
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
      ),
    );
    document.addEntity(
      const LineEntity(
        id: 0,
        props: EntityProps(layer: 'NOTES'),
        start: Vec2(10, 10),
        end: Vec2(80, 10),
      ),
      blockName: '*Paper_Space',
    );
    final svg = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(svg, isNot(contains('<path')));
  });

  test('a viewport plot skips hidden model entities', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(visible: false),
          start: Vec2.zero(),
          end: Vec2(8, 0),
        ),
      );
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(10, 10, 100, 80),
            modelCenter: Vec2(4, 0),
          ),
        ],
      ),
    );
    final svg = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(svg, isNot(contains('M 0.0 0.0')));
  });

  test('a viewport plot omits layers frozen in that window', () {
    final document = CadDocument()..putLayer(const LayerDef(name: 'DIM'));
    document.addEntity(
      const LineEntity(
        id: 0,
        props: EntityProps(layer: 'DIM'),
        start: Vec2(0, 4),
        end: Vec2(8, 4),
      ),
    );
    const viewport = PaperViewport(
      paperBounds: Bounds2(10, 10, 100, 80),
      modelCenter: Vec2(4, 2),
    );
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        viewports: [viewport],
      ),
    );
    final shown = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(shown, contains('<path'));

    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(10, 10, 100, 80),
            modelCenter: Vec2(4, 2),
            frozenLayers: ['DIM'],
          ),
        ],
      ),
    );
    final hidden = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(hidden, isNot(contains('<path')));
    expect(document.activeLayoutName, 'Model');
  });

  test('an off viewport is not clipped or framed', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(10, 10, 100, 80),
            modelCenter: Vec2.zero(),
            isOn: false,
          ),
        ],
      ),
    );

    final svg = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(svg, isNot(contains('clipPath')));
    expect(svg, isNot(contains('clip-path')));
  });

  test('text escapes markup in SVG', () {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(id: 0, position: Vec2(1, 2), content: 'Hi&'),
      );
    expect(const Plotter().toSvg(document), contains('Hi&amp;'));
  });
}
