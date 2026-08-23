import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a lone piece or unsupported object cannot invent a join', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(Construct.joinEntities([line]), isNull);
    expect(Construct.joinEntities(const []), isNull);

    expect(
      Construct.joinEntities([
        line,
        const CircleEntity(id: 2, center: Vec2.zero(), radius: 5),
      ]),
      isNull,
    );
    expect(
      Construct.joinEntities([
        line,
        Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!,
      ]),
      isNull,
    );
    expect(
      Construct.joinEntities([
        line,
        const LineEntity(id: 3, start: Vec2.zero(), end: Vec2.zero()),
      ]),
      isNull,
    );
    expect(
      Construct.joinEntities([
        line,
        const ArcEntity(
          id: 4,
          center: Vec2.zero(),
          radius: 10,
          startAngle: 0,
          endAngle: 0,
        ),
      ]),
      isNull,
    );
  });

  test('a piece that meets the start is prepended, not dropped', () {
    final prepended = Construct.joinEntities([
      const LineEntity(id: 1, start: Vec2(10, 0), end: Vec2(20, 0)),
      const LineEntity(id: 2, start: Vec2.zero(), end: Vec2(10, 0)),
    ]);
    expect(prepended, isNotNull);
    expect(prepended!.vertexAt(0), const Vec2.zero());
    expect(prepended.vertexAt(2), const Vec2(20, 0));

    final reversed = Construct.joinEntities([
      const LineEntity(id: 1, start: Vec2(10, 0), end: Vec2(20, 0)),
      const LineEntity(id: 2, start: Vec2(10, 0), end: Vec2.zero()),
    ]);
    expect(reversed, isNotNull);
    expect(reversed!.vertexAt(0), const Vec2.zero());
    expect(reversed.vertexAt(2), const Vec2(20, 0));
  });

  test('a wide polyline keeps its width when joined onto a line', () {
    final wide = PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 0, 10, 0, 0]),
      constantWidth: 2,
    );
    final joined = Construct.joinEntities([
      wide,
      const LineEntity(id: 2, start: Vec2(10, 0), end: Vec2(20, 0)),
    ]);

    expect(joined, isNotNull);
    expect(joined!.constantWidth, 2);
    expect(joined.vertexCount, 3);
  });
}
