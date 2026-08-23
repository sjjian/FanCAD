import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('missing or unknown JSON cannot invent drawable geometry', () {
    final unknown = CadEntity.fromJson(const {});
    expect(unknown, isA<UnknownEntity>());
    expect(unknown.computeBounds().isEmpty, isTrue);
    expect((unknown as UnknownEntity).originalType, 'UNKNOWN');

    expect(CadEntity.fromJson(const {'type': 'nope'}), isA<UnknownEntity>());

    final line = CadEntity.fromJson(const {'type': 'line'}) as LineEntity;
    expect(line.start, const Vec2.zero());
    expect(line.end, const Vec2.zero());
    expect(line.length, 0);

    final circle = CadEntity.fromJson(const {'type': 'circle'}) as CircleEntity;
    expect(circle.center, const Vec2.zero());
    expect(circle.radius, 0);

    final polyline =
        CadEntity.fromJson(const {'type': 'polyline'}) as PolylineEntity;
    expect(polyline.vertices, isEmpty);
  });
}
