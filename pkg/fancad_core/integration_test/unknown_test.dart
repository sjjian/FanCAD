@Tags(['native'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG unknown', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test(
      'a REGION keeps SAT loops instead of one scribble',
      () async {
        final outer = _ring(126, 96.5, 126, 96.5);
        final inner = _ring(126, 96.5, 40, 30);
        final source = drawingOf(
          UnknownEntity(
            id: 1,
            originalType: 'REGION',
            strokes: Float64List.fromList([...outer, ...inner]),
            strokeCounts: [outer.length ~/ 2, inner.length ~/ 2],
          ),
        );

        final opened = await rt.dwg(source, name: 'region');
        final region = opened.entities.whereType<UnknownEntity>().single;
        expect(region.originalType, 'REGION');
        expect(region.strokeCounts, hasLength(2));
        expect(region.strokeCounts.every((count) => count >= 8), isTrue);
        expect(region.strokeCounts, isNot(equals([56])));
      },
      timeout: Roundtrip.timeout,
    );
  });
}

Float64List _ring(double cx, double cy, double rx, double ry) {
  const n = 8;
  final xy = <double>[];
  for (var i = 0; i < n; i++) {
    final angle = i / n * math.pi * 2;
    xy
      ..add(cx + rx * math.cos(angle))
      ..add(cy + ry * math.sin(angle));
  }
  xy
    ..add(xy[0])
    ..add(xy[1]);
  return Float64List.fromList(xy);
}
