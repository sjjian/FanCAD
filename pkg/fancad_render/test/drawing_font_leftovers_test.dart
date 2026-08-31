import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CJK notes pick a CJK face even when the style is txt.shx', () {
    const map = DrawingFontMap();
    expect(
      map.resolve(styleFont: 'txt', bigFont: '', text: '开槽'),
      map.cjkFamily,
    );
    expect(
      map.resolve(styleFont: 'txt.shx', bigFont: 'gbcbig.shx', text: 'ABC'),
      map.cjkFamily,
    );
  });

  test('a TTF style name maps without inventing a missing file', () {
    const map = DrawingFontMap();
    expect(
      map.resolve(styleFont: 'arial.ttf', bigFont: '', text: 'Note'),
      'Arial',
    );
    expect(
      map.resolve(styleFont: 'txt', bigFont: '', text: 'NOTE'),
      map.latinFallback,
    );
  });
}
