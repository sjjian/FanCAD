import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(center: Vec2(5, 0), scale: 10, size: Size(200, 200));

  test('an invisible entity cannot invent scene strokes', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(visible: false),
          start: Vec2.zero(),
          end: Vec2(10, 0),
        ),
      );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.entityCount, 0);
    expect(scene.lineBatches, isEmpty);
  });

  test('a visible line still lands in a batch', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.entityCount, 1);
    expect(scene.lineBatches, hasLength(1));
  });

  test('a NaN neighbour cannot empty the scene', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      )
      ..addEntity(
        const LineEntity(
          id: 1,
          start: Vec2(-1e41, 0),
          end: Vec2(-1e41, double.nan),
        ),
      );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.entityCount, 1);
    expect(scene.lineBatches, hasLength(1));
  });

  test('a paper millimetre stroke does not grow past its paper width', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(lineWeight: 50),
          start: Vec2.zero(),
          end: Vec2(40, 0),
        ),
      );
    const size = Size(200, 200);
    SceneBuilder builder() => SceneBuilder(palette: AciPalette.dark);

    final atOne = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 1, size: size),
    );
    final atTwo = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 2, size: size),
    );
    expect(atOne.lineBatches, hasLength(1));
    expect(atTwo.lineBatches, hasLength(1));
    const paper = 0.50 / 25.4 * 96;
    expect(atOne.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
    expect(atTwo.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
  });

  test('a paper millimetre stroke is physical pixels, not logical ones', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(lineWeight: 50),
          start: Vec2.zero(),
          end: Vec2(40, 0),
        ),
      );
    const size = Size(200, 200);
    SceneBuilder builder() => SceneBuilder(palette: AciPalette.dark);
    const paper = 0.50 / 25.4 * 96;

    final onePixel = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 1, size: size),
    );
    final retina = builder().build(
      document,
      const CadViewport(
        center: Vec2(20, 0),
        scale: 1,
        size: size,
        devicePixelRatio: 2,
      ),
    );

    // Half a millimetre of ink is half a millimetre on both displays, which
    // means twice as many pixels on the denser one. Reporting the same number
    // for both is what made a Retina hairline draw two pixels wide.
    expect(onePixel.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
    expect(retina.lineBatches.single.key.strokeWidth, closeTo(paper * 2, 1e-9));
  });

  test('a paper millimetre stroke shrinks when the viewport shrinks', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(lineWeight: 100),
          start: Vec2.zero(),
          end: Vec2(40, 0),
        ),
      );
    const size = Size(200, 200);
    SceneBuilder builder() => SceneBuilder(palette: AciPalette.dark);
    const paper = 1.00 / 25.4 * 96;

    final atOne = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 1, size: size),
    );
    final atHalf = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 0.5, size: size),
    );
    expect(atOne.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
    expect(atHalf.lineBatches.single.key.strokeWidth, closeTo(paper * 0.5, 1e-9));
  });

  test('a hairline stays the hairline sentinel after a zoom change', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(lineWeight: 0),
          start: Vec2.zero(),
          end: Vec2(40, 0),
        ),
      );
    const size = Size(200, 200);
    SceneBuilder builder() => SceneBuilder(palette: AciPalette.dark);

    final near = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 1, size: size),
    );
    final far = builder().build(
      document,
      const CadViewport(center: Vec2(20, 0), scale: 10, size: size),
    );
    expect(near.lineBatches.single.key.strokeWidth, 0);
    expect(far.lineBatches.single.key.strokeWidth, 0);
  });
}
