import 'dart:ui';

import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TextItem item(String text, {double height = 12, Color color = const Color(0xFFFFFFFF)}) =>
      TextItem(
        text: text,
        origin: Offset.zero,
        pixelHeight: height,
        rotation: 0,
        color: color,
        hAlign: 0,
        vAlign: 0,
      );

  test('nearby heights share a bucket so 12.02 px is not a new layout', () {
    expect(ParagraphCache.quantiseHeight(12), 12);
    expect(ParagraphCache.quantiseHeight(12.02), 12);
    expect(ParagraphCache.quantiseHeight(12.2), 12.25);
  });

  test('the same string hits and a colour change misses', () {
    final cache = ParagraphCache();
    cache.obtain(item('A1'), fontFamily: 'Roboto');
    cache.obtain(item('A1'), fontFamily: 'Roboto');
    expect(cache.hits, 1);
    expect(cache.misses, 1);
    expect(cache.length, 1);

    cache.obtain(item('A1', color: const Color(0xFFFF0000)), fontFamily: 'Roboto');
    expect(cache.misses, 2);
    expect(cache.length, 2);
  });

  test('the oldest entry is dropped when the budget is one', () {
    final cache = ParagraphCache(capacity: 1);
    cache.obtain(item('first'), fontFamily: 'Roboto');
    cache.obtain(item('second'), fontFamily: 'Roboto');
    expect(cache.length, 1);
    cache.obtain(item('first'), fontFamily: 'Roboto');
    expect(cache.misses, 3);
    cache.clear();
    expect(cache.length, 0);
  });
}
