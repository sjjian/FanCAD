import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
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
