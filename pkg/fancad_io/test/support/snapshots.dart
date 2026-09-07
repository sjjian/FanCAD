import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// DWG handles are not stable, so entities are aligned by kind, owner, and
/// geometry rather than by id. A failure names the step and the unmatched
/// snapshot.

/// Kinds the DWG encoder claims to write with `dwg_add_*`, plus the block
/// structure that exposed the 2026-09 ownership / attribute bugs.
CadDocument syntheticDrawing() {
  const notes = EntityProps(layer: 'NOTES');
  const dimLayer = EntityProps(layer: 'DIM');

  final document = CadDocument()
    ..putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(3)))
    ..putLayer(const LayerDef(name: 'DIM', color: CadColor.indexed(1)))
    ..putBlock(const BlockRecord(name: 'PART'))
    ..putBlock(const BlockRecord(name: 'TITLE'))
    ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true));

  var id = 1;
  document.addEntity(
    LineEntity(id: id++, start: const Vec2(100, 0), end: const Vec2(110, 0)),
  );
  document.addEntity(
    PolylineEntity.fromPoints(
      id: id++,
      points: const [Vec2(0, 20), Vec2(10, 20), Vec2(10, 30)],
      closed: false,
    ),
  );
  document.addEntity(
    CircleEntity(id: id++, center: const Vec2(40, 40), radius: 8),
  );
  document.addEntity(
    const ArcEntity(
      id: 0,
      center: Vec2(60, 40),
      radius: 6,
      startAngle: 0,
      endAngle: 1.5707963267948966,
    ).withId(id++),
  );
  document.addEntity(
    EllipseEntity(
      id: id++,
      center: const Vec2(80, 40),
      majorAxis: const Vec2(12, 0),
      ratio: 0.5,
    ),
  );
  document.addEntity(
    SplineEntity(
      id: id++,
      controlPoints: Float64List.fromList([0, 50, 4, 58, 8, 58, 12, 50]),
      degree: 3,
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
    ),
  );
  document.addEntity(
    const PointEntity(id: 0, position: Vec2(77, 88)).withId(id++),
  );
  document.addEntity(
    TextEntity(
      id: id++,
      position: const Vec2(1200, 800),
      content: 'centered',
      height: 2.5,
      hAlign: TextHAlign.center,
      vAlign: TextVAlign.middle,
    ),
  );
  document.addEntity(
    const MTextEntity(
      id: 0,
      position: Vec2(15, 70),
      content: 'multi',
      height: 2.5,
    ).withId(id++),
  );
  document.addEntity(
    HatchEntity(
      id: id++,
      loops: [
        HatchLoop(
          vertices: Float64List.fromList([200, 0, 210, 0, 210, 10, 200, 10]),
        ),
      ],
    ),
  );
  document.addEntity(
    const LineEntity(
      id: 0,
      start: Vec2(50, 50),
      end: Vec2(60, 50),
    ).withId(id++),
    blockName: '*D1',
  );
  document.addEntity(
    DimensionEntity(
      id: id++,
      props: dimLayer,
      blockName: '*D1',
      measurement: 10,
      definitionPoints: const [Vec2(50, 50), Vec2(60, 50), Vec2(55, 54)],
      textPosition: const Vec2(55, 54),
    ),
  );
  document.addEntity(
    LeaderEntity(
      id: id++,
      vertices: Float64List.fromList([0, 90, 8, 96, 16, 96]),
    ),
  );
  document.addEntity(
    const SolidEntity(
      id: 0,
      corners: [Vec2(0, 110), Vec2(4, 110), Vec2(4, 113), Vec2(0, 113)],
    ).withId(id++),
  );
  document.addEntity(
    const RayEntity(
      id: 0,
      origin: Vec2(1, 120),
      direction: Vec2(1, 0),
    ).withId(id++),
  );
  document.addEntity(
    const XLineEntity(
      id: 0,
      origin: Vec2(3, 130),
      direction: Vec2(0, 1),
    ).withId(id++),
  );

  for (var i = 0; i < 3; i++) {
    document.addEntity(
      LineEntity(
        id: id++,
        start: Vec2(i.toDouble(), 0),
        end: Vec2(i.toDouble(), 5),
      ),
      blockName: 'PART',
    );
  }
  document.addEntity(
    InsertEntity(
      id: id++,
      blockName: 'PART',
      position: const Vec2(300, 40),
      scale: const Vec2(1, 1),
    ),
  );

  document.addEntity(
    AttdefEntity(
      id: id++,
      position: const Vec2(0, 0),
      tag: 'Sheet no',
      prompt: 'Sheet',
      defaultValue: '01',
      height: 2.5,
    ),
    blockName: 'TITLE',
  );
  document.addEntity(
    InsertEntity(
      id: id++,
      props: notes,
      blockName: 'TITLE',
      position: const Vec2(400, 40),
      scale: const Vec2(1, 1),
      attributes: const {'Sheet no': '01'},
    ),
  );

  return document;
}

CadDocument applyEdits(CadDocument opened) {
  opened.putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(3)));

  final line = opened.entities.whereType<LineEntity>().firstWhere(
    (e) =>
        close(e.start, const Vec2(100, 0)) && close(e.end, const Vec2(110, 0)),
  );
  opened.replaceEntity(
    LineEntity(
      id: line.id,
      props: line.props,
      start: const Vec2(105, 3),
      end: const Vec2(115, 3),
    ),
  );

  final text = opened.entities.whereType<TextEntity>().firstWhere(
    (e) => e.content == 'centered',
  );
  opened.replaceEntity(
    TextEntity(
      id: text.id,
      props: text.props,
      position: text.position,
      content: 'edited',
      height: text.height,
      rotation: text.rotation,
      styleName: text.styleName,
      widthFactor: text.widthFactor,
      obliqueAngle: text.obliqueAngle,
      hAlign: text.hAlign,
      vAlign: text.vAlign,
    ),
  );

  final arc = opened.entities.whereType<ArcEntity>().single;
  opened.replaceEntity(arc.withProps(const EntityProps(layer: 'NOTES')));

  opened.addEntity(
    CircleEntity(id: 0, center: const Vec2(500, 500), radius: 12),
  );

  final point = opened.entities.whereType<PointEntity>().firstWhere(
    (e) => close(e.position, const Vec2(77, 88)),
  );
  opened.removeEntity(point.id);

  return opened;
}

void expectMatchingSnapshots(
  CadDocument source,
  CadDocument target, {
  required String step,
}) {
  final report = const FidelityAuditor().compare(source, target);
  expect(
    report.missingByKind,
    isEmpty,
    reason: '$step: lost ${report.summary}',
  );

  final sourceSnaps = snapshotsOf(source)..sort();
  final targetSnaps = snapshotsOf(target)..sort();
  final leftover = [...targetSnaps];
  final missing = <String>[];
  for (final snap in sourceSnaps) {
    final at = leftover.indexOf(snap);
    if (at < 0) {
      missing.add(snap);
    } else {
      leftover.removeAt(at);
    }
  }
  expect(
    missing,
    isEmpty,
    reason:
        '$step: source entities missing after DWG reopen:\n  ${missing.join('\n  ')}\n'
        'unmatched in reopen:\n  ${leftover.join('\n  ')}',
  );
  expect(
    leftover,
    isEmpty,
    reason:
        '$step: extra entities after DWG reopen:\n  ${leftover.join('\n  ')}',
  );
}

void expectFiniteModelExtents(CadDocument doc, {required String step}) {
  var box = const Bounds2.empty();
  for (final entity in doc.entities) {
    if (!sameOwner(doc.ownerOf(entity.id), doc.modelSpaceBlockName)) continue;
    if (entity is RayEntity || entity is XLineEntity) continue;
    final bounds = entity.computeBounds(blocks: doc);
    if (!bounds.isFinite || bounds.isEmpty) continue;
    box = box.union(bounds);
  }
  expect(box.isFinite, isTrue, reason: '$step: model extents $box');
  expect(
    math.max(box.minX.abs(), box.maxX.abs()),
    lessThan(1e6),
    reason: '$step: self-referencing INSERT explodes X ($box)',
  );
  expect(
    math.max(box.minY.abs(), box.maxY.abs()),
    lessThan(1e6),
    reason: '$step: self-referencing INSERT explodes Y ($box)',
  );
}

void expectNamedBlockIntact(
  CadDocument doc,
  String name, {
  int? lineCount,
  String? attdefTag,
}) {
  expect(doc.blocks.containsKey(name), isTrue, reason: 'block $name');
  if (lineCount != null) {
    expect(
      doc.entitiesOf(name).whereType<LineEntity>(),
      hasLength(lineCount),
      reason: 'block $name LINE members',
    );
  }
  if (attdefTag != null) {
    final tags = doc
        .entitiesOf(name)
        .whereType<AttdefEntity>()
        .map((e) => e.tag)
        .toList();
    expect(tags, contains(attdefTag), reason: 'block $name ATTDEF');
  }
}

List<String> snapshotsOf(CadDocument doc) {
  final out = <String>[];
  for (final entity in doc.entities) {
    out.add(
      jsonEncode(
        canonicalize({
          'kind': entity.kind.name,
          'owner': ownerKey(doc.ownerOf(entity.id)),
          'layer': entity.props.layer,
          'color': colorKey(entity.props.color),
          'weight': LineWeight.normalize(entity.props.lineWeight),
          'geom': geometryOf(entity),
        }),
      ),
    );
  }
  return out;
}

/// LibreDWG writes ByLayer as ACI 256 / linewt 29. Compare the meaning, not
/// the sentinels the in-memory document happened to use.
String colorKey(CadColor color) {
  if (color.kind == ColorKind.byLayer) return 'ByLayer';
  if (color.kind == ColorKind.indexed && color.value == 256) return 'ByLayer';
  return color.toString();
}

Object? geometryOf(CadEntity entity) {
  switch (entity) {
    case LineEntity(:final start, :final end):
      return {
        'start': [start.x, start.y],
        'end': [end.x, end.y],
      };
    case PolylineEntity(:final vertices, :final closed):
      return {'closed': closed, 'vertices': vertices};
    case CircleEntity(:final center, :final radius):
      return {
        'center': [center.x, center.y],
        'radius': radius,
      };
    case ArcEntity(
      :final center,
      :final radius,
      :final startAngle,
      :final endAngle,
    ):
      return {
        'center': [center.x, center.y],
        'radius': radius,
        'start': startAngle,
        'end': endAngle,
      };
    case EllipseEntity(
      :final center,
      :final majorAxis,
      :final ratio,
      :final startParam,
      :final endParam,
    ):
      return {
        'center': [center.x, center.y],
        'major': [majorAxis.x, majorAxis.y],
        'ratio': ratio,
        'start': startParam,
        'end': endParam,
      };
    case SplineEntity(:final controlPoints, :final degree):
      return {'degree': degree, 'ctrl': controlPoints};
    case PointEntity(:final position):
      return [position.x, position.y];
    case TextEntity(
      :final position,
      :final content,
      :final height,
      :final hAlign,
      :final vAlign,
    ):
      return {
        'at': [position.x, position.y],
        'text': content,
        'height': height,
        'h': hAlign.name,
        'v': vAlign.name,
      };
    case MTextEntity(:final position, :final content, :final height):
      return {
        'at': [position.x, position.y],
        'text': content,
        'height': height,
      };
    case InsertEntity(
      :final blockName,
      :final position,
      :final scale,
      :final rotation,
      :final attributes,
      :final columnCount,
      :final rowCount,
      :final columnSpacing,
      :final rowSpacing,
    ):
      return {
        'block': blockName,
        'at': [position.x, position.y],
        'scale': [scale.x, scale.y],
        'rot': rotation,
        'cols': columnCount,
        'rows': rowCount,
        'colSp': columnSpacing,
        'rowSp': rowSpacing,
        'attribs': attributes,
      };
    case ImageEntity(
      :final origin,
      :final uVector,
      :final vVector,
      :final reference,
    ):
      return {
        'ref': reference,
        'origin': [origin.x, origin.y],
        'u': [uVector.x, uVector.y],
        'v': [vVector.x, vVector.y],
      };
    case HatchEntity(:final loops):
      return [
        for (final loop in loops) {'outer': loop.isOuter, 'xy': loop.vertices},
      ];
    case DimensionEntity(
      :final blockName,
      :final definitionPoints,
      :final textPosition,
      :final measurement,
      :final overrideText,
    ):
      return {
        'block': blockName,
        'pts': [
          for (final p in definitionPoints) [p.x, p.y],
        ],
        'textAt': [textPosition.x, textPosition.y],
        'meas': measurement,
        'text': overrideText,
      };
    case LeaderEntity(:final vertices, :final hasArrowHead):
      return {'arrow': hasArrowHead, 'xy': vertices};
    case SolidEntity(:final corners):
      final pts =
          [
            for (final p in corners) [p.x, p.y],
          ]..sort(
            (a, b) =>
                (a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1])),
          );
      return pts;
    case RayEntity(:final origin, :final direction):
      return {
        'origin': [origin.x, origin.y],
        'dir': [direction.x, direction.y],
      };
    case XLineEntity(:final origin, :final direction):
      return {
        'origin': [origin.x, origin.y],
        'dir': [direction.x, direction.y],
      };
    case AttdefEntity(
      :final position,
      :final tag,
      :final prompt,
      :final defaultValue,
      :final height,
    ):
      return {
        'at': [position.x, position.y],
        'tag': tag,
        'prompt': prompt,
        'text': defaultValue,
        'height': height,
      };
    default:
      return entity.geometryToJson();
  }
}

String ownerKey(String? name) {
  final value = name ?? '';
  if (value.toUpperCase() == '*MODEL_SPACE') return '*MODEL_SPACE';
  if (value.toUpperCase() == '*PAPER_SPACE') return '*PAPER_SPACE';
  return value;
}

bool sameOwner(String? a, String? b) => ownerKey(a) == ownerKey(b);

bool close(Vec2 a, Vec2 b) =>
    (a.x - b.x).abs() < 1e-6 && (a.y - b.y).abs() < 1e-6;

Object? canonicalize(Object? value) {
  if (value is double) {
    if (value.abs() < 1e-12) return 0.0;
    return (value * 1e6).round() / 1e6;
  }
  if (value is int) return value;
  if (value is List) return [for (final item in value) canonicalize(item)];
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: canonicalize(value[key])};
  }
  return value;
}
