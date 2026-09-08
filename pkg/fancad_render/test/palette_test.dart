import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unresolved ByLayer and ByBlock fall back to the theme foreground', () {
    expect(
      AciPalette.dark.colorOf(const CadColor.byLayer()),
      AciPalette.dark.foreground,
    );
    expect(
      AciPalette.dark.colorOf(const CadColor.byBlock()),
      AciPalette.dark.foreground,
    );
    expect(
      AciPalette.light.colorOf(const CadColor.byLayer()),
      AciPalette.light.foreground,
    );
  });

  test('an out-of-range ACI index cannot vanish into the background', () {
    expect(AciPalette.dark.indexed(-1), AciPalette.dark.foreground);
    expect(AciPalette.dark.indexed(256), AciPalette.dark.foreground);
    expect(AciPalette.light.indexed(999), AciPalette.light.foreground);
  });

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
}
