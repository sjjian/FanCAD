@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG hatch', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a hatch with a hole keeps both loops', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
              ),
              HatchLoop(
                vertices: Float64List.fromList([3, 3, 7, 3, 7, 7, 3, 7]),
                isOuter: false,
              ),
            ],
          ),
        ),
        name: 'hatchhole',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.loops, hasLength(2));
      expect(hatch.loops.first.vertices[2], closeTo(10, 1e-6));
      expect(hatch.loops.last.vertices[0], closeTo(3, 1e-6));
      expect(
        hatch.loops.last.isOuter,
        isTrue,
        reason: 'hatch path outermost bit is not reread from LibreDWG',
      );
    });

    test('a pattern hatch keeps its name and definition lines', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            solid: false,
            patternName: 'ANSI31',
            patternAngle: 0.2,
            patternScale: 2,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 20, 0, 20, 10, 0, 10]),
              ),
            ],
            patternLines: const [HatchPatternLine(angle: 0.785, deltaY: 3.175)],
          ),
        ),
        name: 'ansi31',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.solid, isFalse);
      expect(hatch.patternName.toUpperCase(), 'ANSI31');
      expect(hatch.loops.single.vertices[2], closeTo(20, 1e-6));
    });

    test('hatch pattern scale and angle survive', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            solid: false,
            patternName: 'ANSI31',
            patternAngle: 0.5,
            patternScale: 3,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 12, 0, 12, 8, 0, 8]),
              ),
            ],
            patternLines: const [HatchPatternLine(angle: 0.5, deltaY: 9.525)],
          ),
        ),
        name: 'hatchang',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.patternAngle, closeTo(0.5, 1e-6));
      expect(hatch.patternScale, closeTo(3, 1e-6));
      expect(hatch.patternLines, isNotEmpty);
      expect(hatch.patternLines.first.deltaY, closeTo(9.525, 1e-3));
    });

    test('two hatches keep separate loops', () async {
      final source = CadDocument()
        ..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 4, 0, 4, 4, 0, 4]),
              ),
            ],
          ),
        )
        ..addEntity(
          HatchEntity(
            id: 2,
            solid: false,
            patternName: 'ANSI31',
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([10, 0, 16, 0, 16, 4, 10, 4]),
              ),
            ],
          ),
        );
      final opened = await rt.dwg(source, name: 'twoh');
      expect(opened.entities.whereType<HatchEntity>(), hasLength(2));
      expect(
        opened.entities.whereType<HatchEntity>().where((e) => e.solid),
        hasLength(1),
      );
    });

    test('a hatch pattern line keeps dash lengths', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            solid: false,
            patternName: 'DASH',
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 20, 0, 20, 10, 0, 10]),
              ),
            ],
            patternLines: const [
              HatchPatternLine(angle: 0, deltaY: 4, dashes: [2, -1]),
            ],
          ),
        ),
        name: 'hdash',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.patternLines, isNotEmpty);
      expect(hatch.patternLines.first.dashes, hasLength(2));
      expect(hatch.patternLines.first.dashes[0], closeTo(2, 1e-3));
    });

    test('a hatch inside a named block stays in that block', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PAD'))
        ..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 4, 0, 4, 4, 0, 4]),
              ),
            ],
          ),
          blockName: 'PAD',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'PAD', position: Vec2(8, 8)),
        );
      final opened = await rt.dwg(source, name: 'blkhatch');
      expectMatchingSnapshots(source, opened, step: 'block hatch');
      expect(opened.entitiesOf('PAD').whereType<HatchEntity>(), hasLength(1));
    });

    test('a solid hatch keeps its outer loop', () async {
      final source = CadDocument()
        ..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 8, 0, 8, 6, 0, 6]),
              ),
            ],
          ),
        );
      final opened = await rt.dwg(source, name: 'hatch');
      expectMatchingSnapshots(source, opened, step: 'hatch');
    }, timeout: Roundtrip.timeout);
  });
}
