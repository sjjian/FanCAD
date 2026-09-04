import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    TextItem item({double oblique = 0}) => TextItem(
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
    final upright = cache.obtain(item(), fontFamily: 'Roboto');
    final slanted = cache.obtain(item(oblique: 0.3), fontFamily: 'Roboto');
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

  test('MTEXT attachment 1 stays on the box, not a baseline lift', () {
    const view = CadViewport(
      center: Vec2(20, 20),
      scale: 1,
      size: Size(200, 200),
    );
    final document = CadDocument()
      ..addEntity(
        const MTextEntity(
          id: 1,
          position: Vec2(10, 30),
          content: 'Note',
          height: 8,
          attachment: 1,
        ),
      );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.texts, isNotEmpty);
    expect(scene.texts.single.boxAnchor, isTrue);
    expect(scene.texts.single.vAlign, TextVAlign.top.index);
  });

  test('an MTEXT underline reaches the text item', () {
    const view = CadViewport(
      center: Vec2(20, 20),
      scale: 1,
      size: Size(200, 200),
    );
    final document = CadDocument()
      ..addEntity(
        const MTextEntity(
          id: 1,
          position: Vec2(10, 30),
          content: r'\LNote\l',
          height: 8,
        ),
      );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.texts, isNotEmpty);
    expect(scene.texts.single.underline, isTrue);
    expect(scene.texts.single.text, 'Note');
  });

  test('a vertical dimension label still rasterises when wrap is unset', () async {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(200, 200),
    );
    final scene = RenderScene.single(
      viewport: view,
      texts: const [
        TextItem(
          text: 'AL',
          origin: Offset(100, 100),
          pixelHeight: 20,
          rotation: -1.5707963267948966,
          color: Color(0xFFFFFF00),
          hAlign: 1,
          vAlign: 2,
          boxAnchor: true,
          fontFamily: 'Roboto',
        ),
      ],
      entityCount: 1,
      coverage: const Bounds2(-100, -100, 100, 100),
    );
    final picture = ScenePainter().record(scene);
    final image = await picture.toImage(200, 200);
    final bytes = await image.toByteData();
    var yellow = 0;
    for (var i = 0; i + 3 < (bytes?.lengthInBytes ?? 0); i += 4) {
      if (bytes!.getUint8(i) > 180 &&
          bytes.getUint8(i + 1) > 180 &&
          bytes.getUint8(i + 2) < 80) {
        yellow++;
      }
    }
    expect(yellow, greaterThan(10));
    image.dispose();
    picture.dispose();
  });
}
