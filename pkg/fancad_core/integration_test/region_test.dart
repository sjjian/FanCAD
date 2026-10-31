@Tags(['native'])
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG REGION', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test(
      'a first-class REGION writes as REGION and comes back as REGION',
      () async {
        final source = drawingOf(
          RegionEntity(
            id: 1,
            components: [
              RegionComponent(
                outer: RegionLoop(const [
                  RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
                  RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
                  RegionLine(start: Vec2(10, 10), end: Vec2(0, 10)),
                  RegionLine(start: Vec2(0, 10), end: Vec2(0, 0)),
                ]),
              ),
            ],
          ),
        );
        final opened = await rt.dwg(source, name: 'region-first-class');
        final region = opened.entities.whereType<RegionEntity>().single;
        expect(region.signedArea, closeTo(100, 1e-3));
        expect(region.components, hasLength(1));
      },
      timeout: Roundtrip.timeout,
    );

    test('an ACIS source and its transform survive DWG', () async {
      const points = [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10), Vec2(0, 10)];
      final source = drawingOf(
        RegionEntity(
          id: 1,
          components: [
            RegionComponent(
              outer: RegionLoop(const [
                RegionLine(start: Vec2(100, 20), end: Vec2(110, 20)),
                RegionLine(start: Vec2(110, 20), end: Vec2(110, 30)),
                RegionLine(start: Vec2(110, 30), end: Vec2(100, 30)),
                RegionLine(start: Vec2(100, 30), end: Vec2(100, 20)),
              ]),
            ),
          ],
          source: AcisPayload(
            format: 'sat',
            bytes: Uint8List.fromList(utf8.encode(_satSquare(points))),
            transform: Mat3.translation(100, 20),
          ),
        ),
      );
      final opened = await rt.dwg(source, name: 'region-source');
      final region = opened.entities.whereType<RegionEntity>().single;
      expect(region.signedArea, closeTo(100, 1e-3));
      expect(region.computeBounds().minX, closeTo(100, 1e-3));
      expect(region.computeBounds().minY, closeTo(20, 1e-3));
      expect(region.source, isNotNull);
    }, timeout: Roundtrip.timeout);

    test(
      'a REGION with a hole keeps its hole through DWG',
      () async {
        const hole = RegionConicArc(
          center: Vec2(50, 50),
          u: Vec2(10, 0),
          v: Vec2(0, 10),
          startParameter: 0,
          sweep: math.pi * 2,
        );
        final source = drawingOf(
          RegionEntity(
            id: 1,
            components: [
              RegionComponent(
                outer: RegionLoop(const [
                  RegionLine(start: Vec2(0, 0), end: Vec2(100, 0)),
                  RegionLine(start: Vec2(100, 0), end: Vec2(100, 100)),
                  RegionLine(start: Vec2(100, 100), end: Vec2(0, 100)),
                  RegionLine(start: Vec2(0, 100), end: Vec2(0, 0)),
                ]),
                holes: [
                  RegionLoop([hole]),
                ],
              ),
            ],
          ),
        );
        final opened = await rt.dwg(source, name: 'region-hole');
        final region = opened.entities.whereType<RegionEntity>().single;
        expect(region.components, hasLength(1));
        expect(region.components.single.holes, hasLength(1));
        expect(region.signedArea, closeTo(10000 - math.pi * 100, 0.5));
      },
      timeout: Roundtrip.timeout,
    );

    test(
      'a filleted REGION keeps its corner arcs through DWG',
      () async {
        final square = RegionGeometry.fromLoops([
          RegionLoop(const [
            RegionLine(start: Vec2(0, 0), end: Vec2(100, 0)),
            RegionLine(start: Vec2(100, 0), end: Vec2(100, 100)),
            RegionLine(start: Vec2(100, 100), end: Vec2(0, 100)),
            RegionLine(start: Vec2(0, 100), end: Vec2(0, 0)),
          ]),
        ]);
        final filleted = const RegionFillet().all(square, 10);
        expect(filleted, isNotNull);
        final source = drawingOf(
          RegionEntity(id: 1, components: filleted!.components),
        );
        final opened = await rt.dwg(source, name: 'region-fillet');
        final region = opened.entities.whereType<RegionEntity>().single;
        expect(region.signedArea, closeTo(10000 - (4 - math.pi) * 100, 0.5));
        expect(
          region.components.single.outer.curves
              .whereType<RegionConicArc>()
              .length,
          4,
        );
      },
      timeout: Roundtrip.timeout,
    );

    test(
      'a flattened spline keeps its approximate marker through DWG',
      () async {
        final spline = RegionSpline(
          controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
          knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          weights: const [],
          degree: 3,
          closed: false,
        );
        final source = drawingOf(
          RegionEntity(
            id: 1,
            components: [
              RegionComponent(
                outer: RegionLoop([
                  spline,
                  const RegionLine(start: Vec2(10, 2), end: Vec2(0, 2)),
                  const RegionLine(start: Vec2(0, 2), end: Vec2(0, 0)),
                  const RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
                ]),
              ),
            ],
          ),
        );
        final opened = await rt.dwg(source, name: 'region-spline-approx');
        final region = opened.entities.whereType<RegionEntity>().single;
        expect(region.approximated, isTrue);
      },
      timeout: Roundtrip.timeout,
    );

    test(
      'a moved REGION keeps its new position through DWG',
      () async {
        final source = drawingOf(
          RegionEntity(
            id: 1,
            components: [
              RegionComponent(
                outer: RegionLoop(const [
                  RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
                  RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
                  RegionLine(start: Vec2(10, 10), end: Vec2(0, 10)),
                  RegionLine(start: Vec2(0, 10), end: Vec2(0, 0)),
                ]),
              ),
            ],
          ).transformed(Mat3.translation(100, 20)),
        );
        final opened = await rt.dwg(source, name: 'region-moved');
        final region = opened.entities.whereType<RegionEntity>().single;
        expect(region.signedArea, closeTo(100, 1e-3));
        expect(region.computeBounds().minX, closeTo(100, 1e-3));
        expect(region.computeBounds().minY, closeTo(20, 1e-3));
      },
      timeout: Roundtrip.timeout,
    );
  });
}

String _satSquare(List<Vec2> points) {
  final n = points.length;
  final out = StringBuffer(
    '700 0 1 0 \n'
    '8 FanCAD 8 ACIS 1.7.0 24 Thu Jan 01 00:00:00 1998 \n'
    '18 1e-6 1e-10 \n',
  );
  const body = 0;
  const lump = 1;
  const shell = 2;
  const face = 3;
  const loop = 4;
  const co0 = 5;
  final ed0 = co0 + n;
  final v0 = ed0 + n;
  final p0 = v0 + n;
  out.writeln('body \$-1 \$$lump \$-1 \$-1 #');
  out.writeln('lump \$-1 \$-1 \$$shell \$$body #');
  out.writeln('shell \$-1 \$-1 \$-1 \$$face \$-1 \$$lump #');
  out.writeln(
    'face \$-1 \$-1 \$$loop \$-1 \$$shell \$-1 \$-1 forward single #',
  );
  out.writeln('loop \$-1 \$-1 \$-1 \$$co0 \$$face #');
  for (var i = 0; i < n; i++) {
    final next = co0 + ((i + 1) % n);
    out.writeln(
      'coedge \$-1 \$-1 \$-1 \$$next \$-1 \$-1 \$${ed0 + i} forward #',
    );
  }
  for (var i = 0; i < n; i++) {
    final start = v0 + i;
    final end = v0 + ((i + 1) % n);
    out.writeln(
      'edge \$-1 \$-1 \$${co0 + i} \$$start \$$end \$-1 \$-1 \$${co0 + i} 0 1 #',
    );
  }
  for (var i = 0; i < n; i++) {
    out.writeln('vertex \$-1 \$-1 \$-1 \$${p0 + i} #');
  }
  for (var i = 0; i < n; i++) {
    out.writeln('point \$-1 \$-1 ${points[i].x} ${points[i].y} 0 #');
  }
  out.writeln('transform \$-1 \$-1 #');
  out.writeln('End-of-ACIS-data ');
  return out.toString();
}
