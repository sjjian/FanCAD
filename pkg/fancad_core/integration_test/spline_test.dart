@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG spline', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a closed spline stays closed', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List.fromList([0, 0, 4, 2, 0, 4, -4, 2]),
            degree: 3,
            closed: true,
            knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          ),
        ),
        name: 'splclosed',
      );
      final spline = opened.entities.whereType<SplineEntity>().single;
      expect(spline.closed, isTrue);
      expect(spline.controlPointCount, 4);
    });

    test('a weighted spline keeps control weights', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List.fromList([0, 0, 4, 4, 8, 0]),
            degree: 2,
            knots: const [0, 0, 0, 1, 1, 1],
            weights: const [1, 2, 1],
          ),
        ),
        name: 'splw',
      );
      final spline = opened.entities.whereType<SplineEntity>().single;
      expect(spline.weights, hasLength(3));
      expect(spline.weights[1], closeTo(2, 1e-6));
    });

    test('a fit-only spline comes back without its fit points', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List(0),
            fitPoints: Float64List.fromList([0, 0, 4, 3, 8, 0]),
            degree: 3,
          ),
        ),
        name: 'splfit',
      );
      final spline = opened.entities.whereType<SplineEntity>().single;
      expect(
        spline.controlPointCount,
        0,
        reason: 'fit points are not promoted to NURBS controls on DWG rewrite',
      );
      expect(spline.fitPointCount, 0);
    });

    test('a spline keeps degree and control points', () async {
      final source = CadDocument()
        ..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List.fromList([0, 0, 2, 4, 6, 4, 8, 0]),
            degree: 3,
            knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          ),
        );
      final opened = await rt.dwg(source, name: 'spline');
      expectMatchingSnapshots(source, opened, step: 'spline');
    }, timeout: Roundtrip.timeout);
  });
}
