import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(1000, 800);

  CadDocument paperWithModelLine() {
    final document = CadDocument();
    document.addEntity(
      LineEntity(
        id: 0,
        start: const Vec2(0, 0),
        end: const Vec2(80, 0),
      ),
      blockName: document.modelSpaceBlockName,
    );
    document.addLayout(
      Layout(
        name: 'Layout1',
        blockName: '*Paper_Space',
        tabOrder: 1,
        viewports: const [
          PaperViewport(
            paperBounds: Bounds2(10, 10, 200, 150),
            modelCenter: Vec2(40, 0),
            scale: 1,
          ),
        ],
      ),
    );
    document.setActiveLayout('Layout1');
    return document;
  }

  test('picks a model-space line through a paper viewport', () {
    final document = paperWithModelLine();
    final view = CadViewport.fit(document.extents, size);
    // Midpoint of the line, mapped onto the sheet by the viewport.
    const onSheet = Vec2(105, 80);

    final hit = const Picker().pickTopmost(document, view, onSheet);

    expect(hit, isNotNull);
    expect(document.entity(hit!.entityId), isA<LineEntity>());
  });

  test('does not pick model geometry beside the viewport', () {
    final document = paperWithModelLine();
    final view = CadViewport.fit(document.extents, size);

    final hit = const Picker().pickTopmost(
      document,
      view,
      const Vec2(280, 80),
    );

    expect(hit, isNull);
  });

  test('a crossing window over the viewport selects the model line', () {
    final document = paperWithModelLine();
    final view = CadViewport.fit(document.extents, size);

    final ids = const Picker().pickWindow(
      document,
      view,
      const Bounds2(90, 70, 120, 90),
      crossing: true,
    );

    expect(ids, isNotEmpty);
    expect(document.entity(ids.first), isA<LineEntity>());
  });
}
