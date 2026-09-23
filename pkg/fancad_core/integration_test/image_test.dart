@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG image', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('IMAGE keeps origin and axis vectors', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const ImageEntity(
            id: 1,
            reference: 'pic.png',
            origin: Vec2(2, 3),
            uVector: Vec2(8, 0),
            vVector: Vec2(0, 6),
          ),
        ),
        name: 'image',
      );
      final image = opened.entities.whereType<ImageEntity>().single;
      expect(image.origin.x, closeTo(2, 1e-6));
      expect(image.origin.y, closeTo(3, 1e-6));
      expect(image.uVector.x, closeTo(8, 1e-3));
      expect(image.vVector.y, closeTo(6, 1e-3));
    });

    test('IMAGE keeps its file path', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const ImageEntity(
            id: 1,
            reference: 'photos/part.png',
            origin: Vec2(0, 0),
            uVector: Vec2(10, 0),
            vVector: Vec2(0, 8),
          ),
        ),
        name: 'imgpath',
      );
      expect(
        opened.entities.whereType<ImageEntity>().single.reference,
        'photos/part.png',
      );
    });

    test('a rotated IMAGE keeps non-axis u and v', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const ImageEntity(
            id: 1,
            reference: 'rot.png',
            origin: Vec2(1, 1),
            uVector: Vec2(6, 2),
            vVector: Vec2(-1, 3),
          ),
        ),
        name: 'imgrot',
      );
      final image = opened.entities.whereType<ImageEntity>().single;
      expect(image.uVector.x, closeTo(6, 1e-3));
      expect(image.uVector.y, closeTo(2, 1e-3));
      expect(image.vVector.x, closeTo(-1, 1e-3));
      expect(image.vVector.y, closeTo(3, 1e-3));
    });
  });
}
