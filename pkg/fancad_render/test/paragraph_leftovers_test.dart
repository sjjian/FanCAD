import 'dart:ui';

import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TextItem item(
    String text, {
    double wrapWidth = 0,
    int hAlign = 0,
    bool isMultiline = false,
  }) => TextItem(
    text: text,
    origin: Offset.zero,
    pixelHeight: 12,
    rotation: 0,
    color: const Color(0xFFFFFFFF),
    hAlign: hAlign,
    vAlign: 0,
    wrapWidth: wrapWidth,
    isMultiline: isMultiline,
  );

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
}
