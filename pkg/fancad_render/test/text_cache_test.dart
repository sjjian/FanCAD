import 'dart:ui';

import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TextItem item(
    String text, {
    double height = 12,
    Color color = const Color(0xFFFFFFFF),
    double wrapWidth = 0,
    int hAlign = 0,
    bool isMultiline = false,
  }) => TextItem(
    text: text,
    origin: Offset.zero,
    pixelHeight: height,
    rotation: 0,
    color: color,
    hAlign: hAlign,
    vAlign: 0,
    wrapWidth: wrapWidth,
    isMultiline: isMultiline,
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

  test('an unset wrap shares one bucket; a real wrap cannot reuse it', () {
    final cache = ParagraphCache();
    cache.obtain(item('NOTE'), fontFamily: 'Roboto');
    cache.obtain(item('NOTE', wrapWidth: -1), fontFamily: 'Roboto');
    expect(cache.length, 1);
    expect(cache.hits, 1);

    cache.obtain(item('NOTE', wrapWidth: 80), fontFamily: 'Roboto');
    expect(cache.length, 2);
    expect(cache.misses, 2);
  });

  test('nearby wrap widths share a bucket so 80.02 px is not a new layout', () {
    expect(ParagraphCache.quantiseHeight(80.02), 80);
    final cache = ParagraphCache();
    cache.obtain(item('NOTE', wrapWidth: 80), fontFamily: 'Roboto');
    cache.obtain(item('NOTE', wrapWidth: 80.02), fontFamily: 'Roboto');
    expect(cache.length, 1);
    expect(cache.hits, 1);
  });

  test(
    'alignment and multiline are part of the key so a wrap cannot steal a title',
    () {
      final cache = ParagraphCache();
      cache.obtain(item('NOTE'), fontFamily: 'Roboto');
      cache.obtain(item('NOTE', hAlign: 1), fontFamily: 'Roboto');
      cache.obtain(item('NOTE', isMultiline: true), fontFamily: 'Roboto');
      expect(cache.length, 3);
      expect(cache.misses, 3);
      expect(cache.hits, 0);
    },
  );

  test('width factor stretches the measured advance', () {
    final cache = ParagraphCache();
    final narrow = cache.measureWidth(
      'MM',
      height: 10,
      fontFamily: 'Roboto',
    );
    final wide = cache.measureWidth(
      'MM',
      height: 10,
      fontFamily: 'Roboto',
      widthFactor: 2,
    );
    expect(wide, closeTo(narrow * 2, 0.5));
  });

  test('oblique shears after layout so the baseline stays put', () {
    final cache = ParagraphCache();
    TextItem slantedItem({double oblique = 0}) => TextItem(
      text: 'H',
      origin: Offset.zero,
      pixelHeight: 20,
      rotation: 0,
      color: const Color(0xFFFFFFFF),
      hAlign: 0,
      vAlign: 0,
      fontFamily: 'Roboto',
      obliqueAngle: oblique,
    );
    final upright = cache.obtain(slantedItem(), fontFamily: 'Roboto');
    final slanted = cache.obtain(slantedItem(oblique: 0.3), fontFamily: 'Roboto');
    expect(identical(upright, slanted), isTrue);
    expect(slanted.alphabeticBaseline, closeTo(upright.alphabeticBaseline, 1e-9));
  });

  test('a 20 px TEXT is 20 px tall at the cap, not 0.72 of an em', () {
    final cache = ParagraphCache();
    final paragraph = cache.obtain(
      const TextItem(
        text: 'H',
        origin: Offset.zero,
        pixelHeight: 20,
        rotation: 0,
        color: Color(0xFFFFFFFF),
        hAlign: 0,
        vAlign: 0,
        fontFamily: 'Roboto',
      ),
      fontFamily: 'Roboto',
    );
    final boxes = paragraph.getBoxesForRange(0, 1);
    expect(boxes, isNotEmpty);
    expect(boxes.first.bottom - boxes.first.top, closeTo(20, 2));
  });
}
