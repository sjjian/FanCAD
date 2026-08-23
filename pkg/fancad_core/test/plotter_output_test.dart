import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const plotter = Plotter();

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
    final svg = plotter.toSvg(modelWithInk());
    expect(svg, contains('<path'));
    expect(svg, contains('<circle'));
    expect(svg, contains('<text'));
    expect(svg, contains('Hi&lt;x&gt;'));
    expect(svg, contains('fill-rule="evenodd"'));
    expect(svg, contains('#336699'));
    expect(svg, contains('rotate(90'));
  });

  test('model-space PDF paints the same ink including a rotated text run', () {
    final pdf = String.fromCharCodes(plotter.toPdf(modelWithInk()));
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
    final svg = plotter.toSvg(document, layout: layout);
    expect(svg, contains('clipPath'));
    expect(svg, contains('clip-path'));
    expect(svg, contains('rotate(-90'));
    expect(svg, contains('scale('));

    final pdf = String.fromCharCodes(plotter.toPdf(document, layout: layout));
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

    final svg = plotter.toSvg(
      document,
      layout: document.layouts.last,
      window: const Bounds2(0, 0, 40, 20),
    );
    expect(svg, contains('<svg'));
    expect(svg, isNot(contains('NaN')));
    expect(svg, contains('scale(2'));
  });
}
