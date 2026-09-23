@Tags(['native'])
library;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG ellipse', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('an elliptical arc keeps start and end params', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const EllipseEntity(
            id: 1,
            center: Vec2(5, 5),
            majorAxis: Vec2(0, 10),
            ratio: 0.4,
            startParam: 0.3,
            endParam: 2.2,
          ),
        ),
        name: 'elliparc',
      );
      final ellipse = opened.entities.whereType<EllipseEntity>().single;
      expect(ellipse.majorAxis.y, closeTo(10, 1e-6));
      expect(ellipse.startParam, closeTo(0.3, 1e-6));
      expect(ellipse.endParam, closeTo(2.2, 1e-6));
    });

    test('an ellipse with ratio 1 keeps a circular major axis', () async {
      final source = CadDocument()
        ..addEntity(
          const EllipseEntity(
            id: 1,
            center: Vec2(5, 5),
            majorAxis: Vec2(4, 0),
            ratio: 1,
          ),
        );
      final opened = await rt.dwg(source, name: 'ell1');
      expectMatchingSnapshots(source, opened, step: 'circle ellipse');
    });

    test('a full ellipse keeps major axis and ratio', () async {
      final source = CadDocument()
        ..addEntity(
          const EllipseEntity(
            id: 1,
            center: Vec2(1, 2),
            majorAxis: Vec2(6, 2),
            ratio: 0.35,
          ),
        );
      final opened = await rt.dwg(source, name: 'ellipse');
      expectMatchingSnapshots(source, opened, step: 'full ellipse');
    }, timeout: Roundtrip.timeout);
  });
}
