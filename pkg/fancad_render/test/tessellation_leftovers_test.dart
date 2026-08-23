import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = ResolvedStyle.fallback;
  const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);

  test('straight lines stay off the cache; a bulge polyline does not', () {
    expect(
      TessellationCache.isWorthCaching(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
      ),
      isFalse,
    );
    expect(TessellationCache.isWorthCaching(circle), isTrue);
    expect(
      TessellationCache.isWorthCaching(
        PolylineEntity(
          id: 1,
          vertices: Float64List.fromList([0, 0, 0, 1, 0, 0, 2, 0, 0]),
        ),
      ),
      isFalse,
    );
    expect(
      TessellationCache.isWorthCaching(
        PolylineEntity(
          id: 2,
          vertices: Float64List.fromList([0, 0, 0.5, 10, 0, 0]),
        ),
      ),
      isTrue,
    );
  });

  test('a non-positive tolerance shares bucket 0 instead of NaN', () {
    expect(TessellationCache.toleranceBucket(0), 0);
    expect(TessellationCache.toleranceBucket(-1), 0);
    expect(TessellationCache.toleranceBucket(double.nan), 0);
  });

  test(
    'a short polyline is not recorded so a degenerate emit cannot fill the cache',
    () {
      final sink = RecordingSink();
      sink.polyline(Float64List.fromList([0, 0]), style);
      expect(sink.primitives, isEmpty);
      sink.polyline(Float64List.fromList([0, 0, 1, 0]), style);
      expect(sink.primitives.single.kind, PrimitiveKind.polyline);
      expect(sink.weight, greaterThan(0));
    },
  );

  test(
    'obtain hits after a miss and an empty invalidate cannot drop the entry',
    () {
      final cache = TessellationCache();
      expect(cache.hitRate, 0);

      void emit(RecordingSink sink) {
        sink.polyline(Float64List.fromList([0, 0, 1, 0]), style);
      }

      cache.obtain(circle, 0, emit);
      cache.obtain(circle, 0, emit);
      expect(cache.hits, 1);
      expect(cache.misses, 1);
      expect(cache.hitRate, 0.5);

      cache.invalidate(const []);
      expect(cache.entryCount, 1);
      cache.clear();
      expect(cache.entryCount, 0);
      expect(cache.toString(), contains('0 entries'));
    },
  );
}
