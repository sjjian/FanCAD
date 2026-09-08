import 'dart:math' as math;
import 'dart:typed_data';

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

  test('a non-plottable layer is omitted from SVG', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'VIEWPORT-FRAME', plottable: false))
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(layer: 'VIEWPORT-FRAME'),
          start: Vec2.zero(),
          end: Vec2(8, 0),
        ),
      );
    final svg = const Plotter().toSvg(document);
    expect(svg, isNot(contains('<path')));
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

  CadDocument modelWithInk() {
    return CadDocument()
      ..addEntity(
        const LineEntity(
          id: 1,
          props: EntityProps(color: CadColor.rgb(0x336699)),
          start: Vec2.zero(),
          end: Vec2(20, 0),
        ),
      )
      ..addEntity(const PointEntity(id: 2, position: Vec2(4, 4)))
      ..addEntity(
        const TextEntity(
          id: 3,
          position: Vec2(1, 2),
          content: 'Hi<x>',
          rotation: math.pi / 2,
        ),
      )
      ..addEntity(
        const SolidEntity(
          id: 4,
          corners: [Vec2(0, 6), Vec2(4, 6), Vec2(4, 9), Vec2(0, 9)],
        ),
      )
      ..addEntity(
        const ImageEntity(
          id: 5,
          reference: 'photo.png',
          origin: Vec2(12, 2),
          uVector: Vec2(6, 0),
          vVector: Vec2(0, 4),
        ),
      )
      ..addEntity(
        HatchEntity(
          id: 6,
          loops: [
            HatchLoop(
              vertices: Float64List.fromList([0, 12, 8, 12, 8, 18, 0, 18]),
            ),
            HatchLoop(
              vertices: Float64List.fromList([2, 14, 4, 14, 4, 16, 2, 16]),
              isOuter: false,
            ),
          ],
        ),
      );
  }

  test('model-space SVG paints strokes, fills, text, points and image frames', () {
    final svg = const Plotter().toSvg(modelWithInk());
    expect(svg, contains('<path'));
    expect(svg, contains('<circle'));
    expect(svg, contains('<text'));
    expect(svg, contains('Hi&lt;x&gt;'));
    expect(svg, contains('fill-rule="evenodd"'));
    expect(svg, contains('#336699'));
    expect(svg, contains('rotate(90'));
  });

  test('model-space PDF paints the same ink including a rotated text run', () {
    final pdf = String.fromCharCodes(const Plotter().toPdf(modelWithInk()));
    expect(pdf, startsWith('%PDF-'));
    expect(pdf, contains('BT'));
    expect(pdf, contains('Tj'));
    expect(pdf, contains('f*'));
    expect(pdf, contains(' re'));
    expect(pdf, contains('Tm'));
  });

  test('a live viewport clips model ink and frames the paper window', () {
    final document = modelWithInk();
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotRotation: 90,
        plotFit: true,
        plotOffsetX: 4,
        plotOffsetY: 2,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(10, 10, 120, 90),
            modelCenter: Vec2(10, 8),
            scale: 2,
          ),
        ],
      ),
    );
    document.addEntity(
      const LineEntity(id: 20, start: Vec2(15, 15), end: Vec2(40, 15)),
      blockName: '*Paper_Space',
    );

    final layout = document.layouts.last;
    final svg = const Plotter().toSvg(document, layout: layout);
    expect(svg, contains('clipPath'));
    expect(svg, contains('clip-path'));
    expect(svg, contains('rotate(-90'));
    expect(svg, contains('scale('));

    final pdf = String.fromCharCodes(const Plotter().toPdf(document, layout: layout));
    expect(pdf, contains('W n'));
    expect(pdf, contains('Q'));
  });

  test('a plot window and a short stroke still produce a finite sheet', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(30, 0)),
      );
    document.addLayout(
      const Layout(
        name: 'Win',
        blockName: '*Paper_Space',
        tabOrder: 1,
        plotWindow: Bounds2(0, 0, 40, 20),
        plotScale: 2,
      ),
    );

    final svg = const Plotter().toSvg(
      document,
      layout: document.layouts.last,
      window: const Bounds2(0, 0, 40, 20),
    );
    expect(svg, contains('<svg'));
    expect(svg, isNot(contains('NaN')));
    expect(svg, contains('scale(2'));
  });

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

  test('a viewport-frozen layer cannot invent plot strokes', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 1,
          props: EntityProps(layer: 'WALLS'),
          start: Vec2.zero(),
          end: Vec2(10, 0),
        ),
      );
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(10, 10, 110, 90),
            modelCenter: Vec2.zero(),
            frozenLayers: ['WALLS'],
          ),
        ],
      ),
    );

    final svg = const Plotter().toSvg(document, layout: document.layouts.last);
    expect(svg, isNot(contains('M 0')));
  });
}
