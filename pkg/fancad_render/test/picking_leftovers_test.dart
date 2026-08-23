import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(center: Vec2(5, 5), scale: 1, size: Size(800, 600));

  test(
    'a fill is picked inside, and locked or invisible geometry is skipped',
    () {
      final document = CadDocument()
        ..putLayer(const LayerDef(name: 'LOCK', locked: true))
        ..addEntity(
          const SolidEntity(
            id: 0,
            corners: [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10), Vec2(0, 10)],
          ),
        )
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(visible: false),
            start: Vec2(20, 0),
            end: Vec2(30, 0),
          ),
        )
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(layer: 'LOCK'),
            start: Vec2(40, 0),
            end: Vec2(50, 0),
          ),
        );

      final fill = const Picker().pickTopmost(document, view, const Vec2(5, 5));
      expect(fill, isNotNull);
      expect(document.entity(fill!.entityId), isA<SolidEntity>());

      expect(
        const Picker().pickTopmost(document, view, const Vec2(25, 0)),
        isNull,
      );
      expect(
        const Picker().pickTopmost(document, view, const Vec2(45, 0)),
        isNull,
      );
      expect(
        const Picker().pickTopmost(
          document,
          view,
          const Vec2(5, 5),
          filter: (_) => false,
        ),
        isNull,
      );
    },
  );

  test(
    'flatten length and model-space frame pick cannot invent a viewport',
    () {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      final id = document.entities.single.id;
      final sink = Picker.flatten(document, id, tolerance: 0.1);
      expect(Picker.lengthOf(sink), closeTo(10, 1e-9));

      expect(
        const Picker().pickViewportFrame(document, view, const Vec2(0, 0)),
        isNull,
      );
      expect(const Picker().displayViewportGrips(document, [0]), isEmpty);

      final grip = const Picker().pickGrip(
        document,
        document.entities.single,
        view,
        const Vec2.zero(),
      );
      expect(grip, 0);
    },
  );
}
