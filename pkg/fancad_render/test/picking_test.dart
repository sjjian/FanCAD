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

  test('maps model-space grips onto the paper viewport', () {
    final document = paperWithModelLine();
    final id = document.entities.first.id;
    final grips = const Picker().displayGrips(document, [id]);

    expect(grips, hasLength(3));
    expect(grips[0].paperPoint.x, closeTo(65, 1e-9));
    expect(grips[0].paperPoint.y, closeTo(80, 1e-9));
    expect(grips[2].paperPoint.x, closeTo(145, 1e-9));
    expect(grips[2].paperPoint.y, closeTo(80, 1e-9));
    expect(grips[0].viewport, isNotNull);
  });

  test('picks a model-space grip through a paper viewport', () {
    final document = paperWithModelLine();
    final view = CadViewport.fit(document.extents, size);
    final id = document.entities.first.id;

    final hit = const Picker().pickGripAmong(
      document,
      [id],
      view,
      const Vec2(65, 80),
    );

    expect(hit, isNotNull);
    expect(hit!.entityId, id);
    expect(hit.gripIndex, 0);
    final model = hit.viewport!.paperToModel()!.transform(const Vec2(65, 80));
    expect(model.x, closeTo(0, 1e-9));
    expect(model.y, closeTo(0, 1e-9));
  });

  test('does not pick a model grip beside the viewport', () {
    final document = paperWithModelLine();
    final view = CadViewport.fit(document.extents, size);
    final id = document.entities.first.id;

    final hit = const Picker().pickGripAmong(
      document,
      [id],
      view,
      const Vec2(0, 0),
    );

    expect(hit, isNull);
  });

  test('outlines a model-space line on the paper viewport', () {
    final document = paperWithModelLine();
    final id = document.entities.first.id;
    final sink = PolylineSink();

    Picker.emitInActiveLayout(document, [id], sink, tolerance: 0.1);

    expect(sink.polylines, isNotEmpty);
    final xy = sink.polylines.first;
    // Viewport centre (105, 80) looks at model (40, 0) at 1:1.
    expect(xy[0], closeTo(65, 1e-9));
    expect(xy[1], closeTo(80, 1e-9));
    expect(xy[2], closeTo(145, 1e-9));
    expect(xy[3], closeTo(80, 1e-9));
  });

  test('outlines a paper-space line in sheet coordinates', () {
    final document = paperWithModelLine();
    final paper = document.addEntity(
      const LineEntity(id: 0, start: Vec2(12, 14), end: Vec2(40, 14)),
      blockName: '*Paper_Space',
    );
    final sink = PolylineSink();

    Picker.emitInActiveLayout(document, [paper.id], sink, tolerance: 0.1);

    expect(sink.polylines, isNotEmpty);
    final xy = sink.polylines.first;
    expect(xy[0], closeTo(12, 1e-9));
    expect(xy[1], closeTo(14, 1e-9));
    expect(xy[2], closeTo(40, 1e-9));
    expect(xy[3], closeTo(14, 1e-9));
  });

  test('does not pick a layer frozen in the viewport', () {
    final document = paperWithModelLine();
    document.putLayer(const LayerDef(name: '0'));
    document.addLayout(
      document.activeLayout.copyWith(
        viewports: [
          document.activeLayout.viewports.single.copyWith(
            frozenLayers: const ['0'],
          ),
        ],
      ),
    );
    final view = CadViewport.fit(document.extents, size);

    expect(
      const Picker().pickTopmost(document, view, const Vec2(105, 80)),
      isNull,
    );
  });

  test('does not pick model geometry through an off viewport', () {
    final document = paperWithModelLine();
    document.addLayout(
      document.activeLayout.copyWith(
        viewports: [
          document.activeLayout.viewports.single.copyWith(isOn: false),
        ],
      ),
    );
    final view = CadViewport.fit(document.extents, size);

    expect(
      const Picker().pickTopmost(document, view, const Vec2(105, 80)),
      isNull,
    );
    expect(
      const Picker().pickViewportFrame(document, view, const Vec2(10, 80)),
      0,
    );
  });

  test('picks a paper viewport by its frame, not its interior', () {
    final document = paperWithModelLine();
    final view = CadViewport.fit(document.extents, size);

    expect(
      const Picker().pickViewportFrame(document, view, const Vec2(10, 80)),
      0,
    );
    expect(
      const Picker().pickViewportFrame(document, view, const Vec2(105, 80)),
      isNull,
    );
  });

  test('shows grips on a selected paper viewport', () {
    final document = paperWithModelLine();
    final grips = const Picker().displayViewportGrips(document, [0]);

    expect(grips, hasLength(9));
    expect(grips[0].isViewportFrame, isTrue);
    expect(grips[0].paperPoint, const Vec2(10, 10));
    expect(grips[8].paperPoint, const Vec2(105, 80));
  });
}
