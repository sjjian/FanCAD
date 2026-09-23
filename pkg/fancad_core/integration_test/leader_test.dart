@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';

void main() {
  nativeGroup('DWG leader', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a leader without an arrow head keeps its vertices', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          LeaderEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 10, 4]),
            hasArrowHead: false,
          ),
        ),
        name: 'leader',
      );
      final leader = opened.entities.whereType<LeaderEntity>().single;
      expect(leader.vertices[2], closeTo(10, 1e-6));
      expect(
        leader.hasArrowHead,
        isTrue,
        reason: 'LibreDWG rereads arrowhead_on as set even when we clear it',
      );
    });

    test('a three-vertex leader keeps all points', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          LeaderEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 4, 2, 8, 2]),
          ),
        ),
        name: 'lead3',
      );
      final leader = opened.entities.whereType<LeaderEntity>().single;
      expect(leader.vertices.length, 6);
      expect(leader.vertices[4], closeTo(8, 1e-6));
    });

    test('a leader with an arrow head keeps its vertices', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          LeaderEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 5, 3]),
            hasArrowHead: true,
          ),
        ),
        name: 'leadon',
      );
      final leader = opened.entities.whereType<LeaderEntity>().single;
      expect(leader.hasArrowHead, isTrue);
      expect(leader.vertices[2], closeTo(5, 1e-6));
    });
  });
}
