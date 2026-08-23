import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
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
}
