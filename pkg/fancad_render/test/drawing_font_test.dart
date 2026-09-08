import 'package:fancad_render/testing.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const map = DrawingFontMap();

  eachCase(
    [
      (
        name: 'CJK notes pick a CJK face even when the style is txt.shx',
        styleFont: 'txt',
        bigFont: '',
        text: '开槽',
        want: map.cjkFamily,
      ),
      (
        name: 'a CJK bigFont still picks a CJK face for ASCII',
        styleFont: 'txt.shx',
        bigFont: 'gbcbig.shx',
        text: 'ABC',
        want: map.cjkFamily,
      ),
      (
        name: 'a TTF style name maps without inventing a missing file',
        styleFont: 'arial.ttf',
        bigFont: '',
        text: 'Note',
        want: 'Arial',
      ),
      (
        name: 'a Latin SHX style falls back to the system face',
        styleFont: 'txt',
        bigFont: '',
        text: 'NOTE',
        want: map.latinFallback,
      ),
    ],
    (row) {
      expect(
        map.resolve(
          styleFont: row.styleFont,
          bigFont: row.bigFont,
          text: row.text,
        ),
        row.want,
      );
    },
  );
}
