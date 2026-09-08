import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = ResolvedStyle.fallback;
  const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);

  Float64List longPolyline() => Float64List.fromList([
    for (var i = 0; i < 16; i++) ...[i.toDouble(), 0.0],
  ]);

  test('a two-point line is not retained; a long polyline is', () {
    final cache = TessellationCache();
    cache.obtain(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
      0,
      (sink) => sink.polyline(Float64List.fromList([0, 0, 1, 0]), style),
    );
    expect(cache.entryCount, 0);

    cache.obtain(circle, 0, (sink) => sink.polyline(longPolyline(), style));
    expect(cache.entryCount, 1);
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
        sink.polyline(longPolyline(), style);
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

  test('hover minExtent does not reuse a collapsed drawing flatten', () {
    final cache = TessellationCache();
    var emits = 0;
    void emit(RecordingSink sink) {
      emits++;
      sink.polyline(longPolyline(), style);
    }

    cache.obtain(circle, 0, emit, minExtent: 10);
    cache.obtain(circle, 0, emit, minExtent: 0);
    expect(emits, 2);
    cache.obtain(circle, 0, emit, minExtent: 10);
    cache.obtain(circle, 0, emit, minExtent: 0);
    expect(emits, 2);
    expect(cache.hits, 2);
  });

  test('curves hit the cache on a repeated build', () {
    const size = Size(1000, 800);
    final document = CadDocument();
    for (var i = 0; i < 200; i++) {
      document.addEntity(
        CircleEntity(id: 0, center: Vec2(i * 10, 0), radius: 4),
      );
    }
    final cache = TessellationCache();
    final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
    final view = CadViewport.fit(document.extents, size);

    builder.build(document, view);
    final firstMisses = cache.misses;
    expect(firstMisses, greaterThan(0));

    cache.resetStatistics();
    builder.build(document, view);
    expect(cache.misses, 0);
    expect(cache.hits, firstMisses);
  });

  test('straight geometry is not cached', () {
    const size = Size(1000, 800);
    final cache = TessellationCache();
    final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
    final document = CadDocument();
    for (var i = 0; i < 100; i++) {
      document.addEntity(
        LineEntity(
          id: i,
          start: Vec2(i * 10, 0),
          end: Vec2(i * 10 + 8, 8),
        ),
      );
    }
    builder.build(document, CadViewport.fit(document.extents, size));
    expect(cache.entryCount, 0);
  });

  test('invalidation drops only the affected entities', () {
    const size = Size(1000, 800);
    final document = CadDocument();
    final ids = [
      for (var i = 0; i < 20; i++)
        document
            .addEntity(
              CircleEntity(id: 0, center: Vec2(i * 10, 0), radius: 4),
            )
            .id,
    ];
    final cache = TessellationCache();
    final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
    final view = CadViewport.fit(document.extents, size);
    builder.build(document, view);
    final before = cache.entryCount;

    cache.invalidate([ids.first]);
    expect(cache.entryCount, before - 1);
  });

  test('the cache stays inside its budget', () {
    const size = Size(1000, 800);
    final document = CadDocument();
    for (var i = 0; i < 400; i++) {
      document.addEntity(
        CircleEntity(id: 0, center: Vec2(i * 20, 0), radius: 9),
      );
    }
    // A budget far too small for the whole drawing.
    final cache = TessellationCache(budget: 2000);
    SceneBuilder(palette: AciPalette.dark, cache: cache).build(
      document,
      CadViewport.fit(document.extents, size),
    );
    expect(cache.totalWeight, lessThanOrEqualTo(2000));
  });

  test('tolerance bucketing reuses entries across a small zoom change', () {
    const size = Size(1000, 800);
    const a = CadViewport(center: Vec2.zero(), scale: 100, size: size);
    final b = a.copyWith(scale: 105);
    expect(
      TessellationCache.toleranceBucket(a.tolerance),
      TessellationCache.toleranceBucket(b.tolerance),
    );
    // A large zoom change must land in a different band.
    expect(
      TessellationCache.toleranceBucket(a.copyWith(scale: 1600).tolerance),
      isNot(TessellationCache.toleranceBucket(a.tolerance)),
    );
  });
}
