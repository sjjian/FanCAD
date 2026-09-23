@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG polyline', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a closed polyline keeps bulge', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          PolylineEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 0.5, 10, 0, 0, 10, 10, 0]),
            closed: true,
          ),
        ),
        name: 'bulge',
      );
      final pline = opened.entities.whereType<PolylineEntity>().single;
      expect(pline.closed, isTrue);
      expect(pline.vertices.length, 9);
      expect(pline.vertices[2], closeTo(0.5, 1e-6));
    });

    test('polyline constant width survives a DWG round trip', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          PolylineEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 0, 10, 0, 0]),
            constantWidth: 0.5,
          ),
        ),
        name: 'plwidth',
      );
      final pline = opened.entities.whereType<PolylineEntity>().single;
      expect(pline.vertexAt(1).x, closeTo(10, 1e-6));
      expect(pline.constantWidth, closeTo(0.5, 1e-6));
    });

    test('an open four-vertex polyline keeps order', () async {
      final source = CadDocument()
        ..addEntity(
          PolylineEntity.fromPoints(
            id: 1,
            points: const [Vec2(0, 0), Vec2(2, 0), Vec2(2, 3), Vec2(5, 3)],
          ),
        );
      final opened = await rt.dwg(source, name: 'pl4');
      expectMatchingSnapshots(source, opened, step: 'open polyline');
    });

    test('a polyline keeps a bulge on the second vertex', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          PolylineEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 0, 8, 0, 0.4, 8, 6, 0]),
          ),
        ),
        name: 'bulge2',
      );
      final pline = opened.entities.whereType<PolylineEntity>().single;
      expect(pline.vertices[5], closeTo(0.4, 1e-6));
      expect(pline.vertexAt(2).x, closeTo(8, 1e-6));
    });
  });
}
