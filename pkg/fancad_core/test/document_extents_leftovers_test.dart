import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('hidden geometry cannot invent model extents', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 1,
          props: EntityProps(visible: false),
          start: Vec2.zero(),
          end: Vec2(10, 0),
        ),
      );
    expect(document.extents.isEmpty, isTrue);
  });

  test('a NaN or infinite point cannot collapse Zoom Extents', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 4)),
      )
      ..addEntity(
        const LineEntity(
          id: 2,
          start: Vec2(-1e41, 0),
          end: Vec2(-1e41, double.nan),
        ),
      )
      ..addEntity(
        const PointEntity(id: 3, position: Vec2(double.infinity, 3)),
      );
    expect(document.extents.minX, closeTo(0, 1e-9));
    expect(document.extents.minY, closeTo(0, 1e-9));
    expect(document.extents.maxX, closeTo(10, 1e-9));
    expect(document.extents.maxY, closeTo(4, 1e-9));
    expect(document.queryVisible(const Bounds2(-1, -1, 11, 5)), [1]);
  });

  test('an unused block with world-coord junk cannot stretch extents', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'bk'))
      ..addEntity(
        const LineEntity(
          id: 1,
          start: Vec2(296000, 160000),
          end: Vec2(296100, 160000),
        ),
        blockName: 'bk',
      )
      ..addEntity(
        const LineEntity(id: 2, start: Vec2.zero(), end: Vec2(10, 4)),
      );
    expect(document.extents.minX, closeTo(0, 1e-9));
    expect(document.extents.maxX, closeTo(10, 1e-9));
  });

  test('a world-coord insert cannot stretch Zoom Extents among local lines', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'bk'));
    for (var i = 0; i < 20; i++) {
      document.addEntity(
        LineEntity(
          id: i,
          start: Vec2(i * 10, 0),
          end: Vec2(i * 10 + 5, 1),
        ),
      );
    }
    document
      ..addEntity(
        const LineEntity(
          id: 100,
          start: Vec2(296000, 160000),
          end: Vec2(296100, 160000),
        ),
        blockName: 'bk',
      )
      ..addEntity(
        const InsertEntity(
          id: 101,
          blockName: 'bk',
          position: Vec2(50, 0),
          scale: Vec2(20, 20),
        ),
      );
    expect(document.extents.minX, closeTo(0, 20));
    expect(document.extents.maxX, lessThan(1000));
  });

  test('an insert of a local tick stays near the insertion point', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: '_Oblique'))
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0.5)),
        blockName: '_Oblique',
      );
    for (var i = 0; i < 8; i++) {
      document.addEntity(
        InsertEntity(
          id: 10 + i,
          blockName: '_Oblique',
          position: Vec2(100.0 * i, 20),
          scale: const Vec2(15, 15),
        ),
      );
    }
    expect(document.extents.minX, closeTo(0, 1e-9));
    expect(document.extents.maxX, closeTo(715, 1e-9));
    expect(document.extents.height, lessThan(20));
  });

  test('an insert frames local geometry after subtracting the block base', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'TICK', basePoint: Vec2(100, 50)))
      ..addEntity(
        const LineEntity(id: 1, start: Vec2(100, 50), end: Vec2(101, 50)),
        blockName: 'TICK',
      )
      ..addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'TICK',
          position: Vec2(10, 20),
        ),
      );
    expect(document.extents.minX, closeTo(10, 1e-9));
    expect(document.extents.minY, closeTo(20, 1e-9));
    expect(document.extents.maxX, closeTo(11, 1e-9));
    expect(document.extents.maxY, closeTo(20, 1e-9));
  });
}
