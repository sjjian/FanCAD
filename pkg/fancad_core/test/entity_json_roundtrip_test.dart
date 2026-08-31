import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('every entity kind survives a JSON round trip', () {
    final entities = <CadEntity>[
      const ArcEntity(
        id: 1,
        center: Vec2(2, 3),
        radius: 5,
        startAngle: 0.2,
        endAngle: 1.4,
      ),
      const EllipseEntity(
        id: 2,
        center: Vec2.zero(),
        majorAxis: Vec2(10, 0),
        ratio: 0.5,
        startParam: 0.1,
        endParam: math.pi,
      ),
      SplineEntity(
        id: 3,
        controlPoints: Float64List.fromList([0, 0, 4, 4, 8, 0]),
        knots: const [0, 0, 0, 1, 1, 1],
        weights: const [1, 1, 1],
        degree: 2,
        closed: true,
        fitPoints: Float64List.fromList([0, 0, 8, 0]),
      ),
      const PointEntity(id: 4, position: Vec2(7, 8)),
      const TextEntity(
        id: 5,
        position: Vec2(1, 2),
        content: 'NOTE',
        height: 3,
        rotation: 0.4,
        widthFactor: 1.2,
        obliqueAngle: 0.1,
        hAlign: TextHAlign.center,
        vAlign: TextVAlign.top,
      ),
      const MTextEntity(
        id: 6,
        position: Vec2(3, 4),
        content: r'A\PB',
        height: 4,
        rotation: 0.2,
        rectangleWidth: 12,
        attachment: 5,
      ),
      const InsertEntity(
        id: 7,
        blockName: 'CELL',
        position: Vec2(1, 1),
        scale: Vec2(2, 3),
        rotation: 0.5,
        columnCount: 2,
        rowCount: 3,
        columnSpacing: 8,
        rowSpacing: 6,
        attributes: {'NO': 'A-01'},
      ),
      const AttdefEntity(
        id: 16,
        position: Vec2(2, 3),
        tag: 'NO',
        prompt: 'Drawing number',
        defaultValue: 'A-00',
        height: 3.5,
        invisible: true,
      ),
      const AttribEntity(
        id: 17,
        position: Vec2(4, 5),
        tag: 'NO',
        value: 'A-01',
        height: 3.5,
      ),
      HatchEntity(
        id: 8,
        solid: false,
        patternName: 'ANSI31',
        patternAngle: 0.3,
        patternScale: 2,
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
          ),
          HatchLoop(
            vertices: Float64List.fromList([2, 2, 4, 2, 4, 4, 2, 4]),
            isOuter: false,
          ),
        ],
      ),
      const DimensionEntity(
        id: 9,
        blockName: '*D1',
        definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 4)],
        textPosition: Vec2(5, 4),
        measurement: 10,
        overrideText: '10',
        dimensionType: 1,
        sourceIds: [3],
      ),
      LeaderEntity(
        id: 10,
        vertices: Float64List.fromList([0, 0, 4, 4, 8, 4]),
        hasArrowHead: false,
      ),
      MLeaderEntity(
        id: 21,
        vertices: Float64List.fromList([0, 0, 6, 6, 12, 6]),
        content: 'ML',
        textPosition: const Vec2(12, 6),
        textHeight: 2.5,
      ),
      const SolidEntity(
        id: 11,
        corners: [Vec2.zero(), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
      ),
      const RayEntity(
        id: 12,
        origin: Vec2(1, 2),
        direction: Vec2(0, 1),
      ),
      const XLineEntity(
        id: 13,
        origin: Vec2(2, 3),
        direction: Vec2(1, 1),
      ),
      const ImageEntity(
        id: 14,
        reference: 'photo.png',
        origin: Vec2.zero(),
        uVector: Vec2(10, 0),
        vVector: Vec2(0, 8),
      ),
      UnknownEntity(
        id: 15,
        originalType: 'ACAD_PROXY',
        proxyBounds: const Bounds2(1, 2, 3, 4),
      ),
    ];

    for (final entity in entities) {
      final restored = CadEntity.fromJson(entity.toJson());
      expect(restored.kind, entity.kind, reason: entity.kind.name);
      expect(restored.id, entity.id);
      expect(restored.toJson(), entity.toJson());
    }
  });

  test('map points and numeric alignments still parse', () {
    final point = CadEntity.fromJson(const {
      'type': 'point',
      'position': {'x': 3, 'y': 4},
    }) as PointEntity;
    expect(point.position, const Vec2(3, 4));

    final text = CadEntity.fromJson(const {
      'type': 'text',
      'position': [0, 0],
      'text': 'A',
      'hAlign': 1,
      'vAlign': 3,
    }) as TextEntity;
    expect(text.hAlign, TextHAlign.center);
    expect(text.vAlign, TextVAlign.top);

    final hatch = CadEntity.fromJson(const {
      'type': 'hatch',
      'loops': [
        'nope',
        {'outer': false, 'points': [[1, 2], [3, 4]]},
      ],
    }) as HatchEntity;
    expect(hatch.loops, hasLength(1));
    expect(hatch.loops.single.isOuter, isFalse);
    expect(hatch.loops.single.pointCount, 2);
  });
}
