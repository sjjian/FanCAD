import 'package:fancad_core/src/core.dart';
import 'package:test/test.dart';

void main() {
  group('CadDocument read caches', () {
    test('extents are reused until the document changes', () {
      final document = CadDocument();
      document.addEntity(
        LineEntity(id: 0, start: Vec2.zero(), end: const Vec2(10, 0)),
      );

      final first = document.extents;
      expect(identical(document.extents, first), isTrue);

      document.addEntity(
        LineEntity(id: 0, start: Vec2.zero(), end: const Vec2(100, 0)),
      );

      final second = document.extents;
      expect(identical(document.extents, second), isTrue);
      expect(identical(second, first), isFalse);
      expect(second.width, closeTo(100, 1e-9));
    });

    test('extents invalidate when a layer is hidden', () {
      final document = CadDocument();
      document.addEntity(
        LineEntity(id: 0, start: Vec2.zero(), end: const Vec2(10, 0)),
      );
      final visible = document.extents;
      expect(visible.width, closeTo(10, 1e-9));

      document.putLayer(const LayerDef(name: '0', visible: false));

      final hidden = document.extents;
      expect(identical(hidden, visible), isFalse);
      expect(hidden.isEmpty, isTrue);
    });

    test('table views are reused and refreshed after a table edit', () {
      final document = CadDocument();
      final layers = document.layers;
      expect(identical(document.layers, layers), isTrue);

      document.putLayer(const LayerDef(name: 'NOTES'));

      final next = document.layers;
      expect(identical(next, layers), isFalse);
      expect(next.containsKey('NOTES'), isTrue);
      expect(identical(document.layers, next), isTrue);
    });

    test('layout and block views invalidate after structure edits', () {
      final document = CadDocument();
      final layouts = document.layouts;
      final blocks = document.blocks;
      expect(identical(document.layouts, layouts), isTrue);
      expect(identical(document.blocks, blocks), isTrue);

      document.addLayout(
        const Layout(name: 'Sheet', blockName: '*Paper_Space'),
      );
      document.putBlock(const BlockRecord(name: 'PART'));

      expect(identical(document.layouts, layouts), isFalse);
      expect(identical(document.blocks, blocks), isFalse);
      expect(document.layouts.any((layout) => layout.name == 'Sheet'), isTrue);
      expect(document.blocks.containsKey('PART'), isTrue);
    });

    test('entity edits refresh blocks but not unrelated table views', () {
      final document = CadDocument();
      final layers = document.layers;
      final blocks = document.blocks;

      final id = document
          .addEntity(
            LineEntity(id: 0, start: Vec2.zero(), end: const Vec2(10, 0)),
          )
          .id;

      expect(identical(document.layers, layers), isTrue);
      expect(identical(document.blocks, blocks), isFalse);
      expect(
        document.blocks[DrawingData.defaultModelSpaceBlock]?.entityIds,
        contains(id),
      );
    });
  });
}
