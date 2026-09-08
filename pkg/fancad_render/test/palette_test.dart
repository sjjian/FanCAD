import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  eachCase(
    [
      (
        name: 'dark ByLayer falls back to the theme foreground',
        palette: AciPalette.dark,
        color: const CadColor.byLayer(),
      ),
      (
        name: 'dark ByBlock falls back to the theme foreground',
        palette: AciPalette.dark,
        color: const CadColor.byBlock(),
      ),
      (
        name: 'light ByLayer falls back to the theme foreground',
        palette: AciPalette.light,
        color: const CadColor.byLayer(),
      ),
    ],
    (row) {
      expect(row.palette.colorOf(row.color), row.palette.foreground);
    },
  );

  eachCase(
    [
      (name: 'dark ACI -1 cannot vanish', palette: AciPalette.dark, index: -1),
      (
        name: 'dark ACI 256 cannot vanish',
        palette: AciPalette.dark,
        index: 256,
      ),
      (
        name: 'light ACI 999 cannot vanish',
        palette: AciPalette.light,
        index: 999,
      ),
    ],
    (row) {
      expect(row.palette.indexed(row.index), row.palette.foreground);
    },
  );

  test('true black on a dark canvas is replaced by the foreground', () {
    expect(
      AciPalette.dark.colorOf(const CadColor.rgb(0x000000)),
      AciPalette.dark.foreground,
    );
    expect(
      AciPalette.light.colorOf(const CadColor.rgb(0x000000)),
      const Color(0xFF000000),
    );
  });

  test('index 7 follows the background', () {
    expect(AciPalette.dark.indexed(7), const Color(0xFFFFFFFF));
    expect(AciPalette.light.indexed(7), const Color(0xFF000000));
  });

  test('the primaries are the colours CAD users expect', () {
    expect(AciPalette.dark.indexed(1), const Color(0xFFFF0000));
    expect(AciPalette.dark.indexed(3), const Color(0xFF00FF00));
    expect(AciPalette.dark.indexed(5).b, greaterThan(0.5));
  });

  test('near-black is lifted so it stays visible on a dark canvas', () {
    final lifted = AciPalette.dark.colorOf(const CadColor.rgb(0x050505));
    expect(lifted.computeLuminance(), greaterThan(0.01));
    // On a light canvas it must be left exactly as authored.
    expect(
      AciPalette.light.colorOf(const CadColor.rgb(0x050505)),
      const Color(0xFF050505),
    );
  });
}
