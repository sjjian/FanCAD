import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../model/document.dart';
import '../model/entity.dart';
import '../model/style.dart';
import '../txn/transaction.dart';

/// A bag of geometry and the named objects it depends on, ready to paste into
/// another drawing (or the same one).
///
/// Entities keep their source coordinates. [basePoint] is only a placement
/// handle: PASTECLIP translates by `insertion - basePoint`, PASTEORIG passes
/// the base back as the insertion so the translation is zero.
class DrawingClip {
  const DrawingClip({
    required this.basePoint,
    required this.entities,
    this.blocks = const {},
    this.blockEntities = const {},
    this.layers = const {},
    this.lineTypes = const {},
    this.textStyles = const {},
    this.dimStyles = const {},
  });

  final Vec2 basePoint;

  /// Top-level objects that will land in the target space (or a new
  /// paste-as-block).
  final List<CadEntity> entities;

  /// Referenced block definitions, keyed by the source name.
  final Map<String, BlockRecord> blocks;

  /// Entities that live inside [blocks], keyed by their source id.
  final Map<int, CadEntity> blockEntities;

  final Map<String, LayerDef> layers;
  final Map<String, LineTypeDef> lineTypes;
  final Map<String, TextStyleDef> textStyles;
  final Map<String, DimStyleDef> dimStyles;

  bool get isEmpty => entities.isEmpty;

  /// Lower-left of the selection extents, which is what COPYCLIP uses as a
  /// base when the user did not pick one.
  static Vec2 lowerLeftOf(CadDocument document, Iterable<int> ids) {
    var box = const Bounds2.empty();
    for (final id in ids) {
      final entity = document.entity(id);
      if (entity == null) continue;
      final bounds = document.boundsOfEntity(entity);
      if (!bounds.isFinite || bounds.isEmpty) continue;
      box = box.union(bounds);
    }
    if (box.isEmpty) return const Vec2.zero();
    return box.min;
  }

  /// Captures [ids] and every named object they need to round-trip.
  ///
  /// Layout blocks stay behind: an INSERT of model space is not a portable
  /// definition. Missing ids are skipped rather than inventing geometry.
  static DrawingClip? extract(
    CadDocument document,
    Iterable<int> ids, {
    required Vec2 basePoint,
  }) {
    final topLevel = <CadEntity>[];
    for (final id in ids) {
      final entity = document.entity(id);
      if (entity == null) continue;
      topLevel.add(entity);
    }
    if (topLevel.isEmpty) return null;

    final blocks = <String, BlockRecord>{};
    final blockEntities = <int, CadEntity>{};
    final pending = <String>[];
    final seen = <String>{};

    void consider(String name) {
      if (name.isEmpty) return;
      final key = name.toUpperCase();
      if (!seen.add(key)) return;
      pending.add(name);
    }

    for (final entity in topLevel) {
      _referencedBlockNames(entity).forEach(consider);
    }

    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      final block = _namedBlock(document, name);
      if (block == null || block.isLayoutBlock) continue;
      blocks[block.name] = block;
      for (final id in block.entityIds) {
        final entity = document.entity(id);
        if (entity == null) continue;
        blockEntities[id] = entity;
        _referencedBlockNames(entity).forEach(consider);
      }
    }

    final layers = <String, LayerDef>{};
    final lineTypes = <String, LineTypeDef>{};
    final textStyles = <String, TextStyleDef>{};
    final dimStyles = <String, DimStyleDef>{};

    void collectFrom(CadEntity entity) {
      _takeLayer(document, layers, lineTypes, entity.props.layer);
      _takeLineType(document, lineTypes, entity.props.lineType);
      final style = _textStyleName(entity);
      if (style != null) _takeTextStyle(document, textStyles, style);
      if (entity is DimensionEntity) {
        _takeDimStyle(document, dimStyles, textStyles, entity.styleName);
      }
    }

    for (final entity in topLevel) {
      collectFrom(entity);
    }
    for (final entity in blockEntities.values) {
      collectFrom(entity);
    }

    return DrawingClip(
      basePoint: basePoint,
      entities: topLevel,
      blocks: blocks,
      blockEntities: blockEntities,
      layers: layers,
      lineTypes: lineTypes,
      textStyles: textStyles,
      dimStyles: dimStyles,
    );
  }

  /// Writes this clip into [transaction]'s document.
  ///
  /// Named objects that already exist in the target are left alone, matching
  /// AutoCAD / 浩辰 / 中望. Anonymous `*D` / `*U` blocks get a fresh name on
  /// every paste so two pastes cannot share a dimension geometry block.
  List<int> paste(
    Transaction transaction, {
    required Vec2 insertion,
    bool asBlock = false,
  }) {
    final document = transaction.document;
    _importTables(transaction);

    final nameMap = <String, String>{};
    final toImport = <String>[];
    final reserved = <String>{};
    for (final block in blocks.values) {
      if (block.isAnonymous || block.name.startsWith('*')) {
        final next = _uniqueBlockName(
          document,
          _anonymousPrefix(block.name),
          reserved,
        );
        reserved.add(next.toUpperCase());
        nameMap[block.name] = next;
        toImport.add(block.name);
        continue;
      }
      final existing = _namedBlock(document, block.name);
      if (existing != null) {
        nameMap[block.name] = existing.name;
        continue;
      }
      nameMap[block.name] = block.name;
      toImport.add(block.name);
    }

    for (final sourceName in toImport) {
      final block = blocks[sourceName]!;
      final destName = nameMap[sourceName]!;
      transaction.putBlock(block.copyWith(name: destName, entityIds: const []));
    }

    // Ids are reserved up front so remappedIds can run before add. A
    // post-add modify would refuse entities that landed on a locked layer.
    final remap = <int, int>{};
    final staged = <({CadEntity entity, String owner, bool placed})>[];

    void stage(
      CadEntity source,
      String owner, {
      required bool transform,
      bool placed = true,
    }) {
      final newId = document.allocateId();
      remap[source.id] = newId;
      var copy = _withBlockRefs(source.withId(newId), nameMap);
      if (transform) {
        final delta = insertion - basePoint;
        if (delta.x != 0 || delta.y != 0) {
          copy = copy.transformed(Mat3.translation(delta.x, delta.y));
        }
      }
      staged.add((entity: copy, owner: owner, placed: placed));
    }

    for (final sourceName in toImport) {
      final block = blocks[sourceName]!;
      final destName = nameMap[sourceName]!;
      for (final id in block.entityIds) {
        final entity = blockEntities[id];
        if (entity == null) continue;
        stage(entity, destName, transform: false, placed: false);
      }
    }

    final List<int> placed;
    if (asBlock) {
      final pasteName = _uniqueBlockName(document, r'A$C', reserved);
      transaction.putBlock(
        BlockRecord(
          name: pasteName,
          basePoint: basePoint,
          isAnonymous: true,
          entityIds: const [],
        ),
      );
      for (final entity in entities) {
        stage(entity, pasteName, transform: false, placed: false);
      }
      final insert = InsertEntity(
        id: 0,
        props: EntityProps(layer: document.currentLayer),
        blockName: pasteName,
        position: insertion,
      );
      final insertId = transaction.add(insert);
      placed = [insertId];
    } else {
      final space = document.currentBlockName;
      for (final entity in entities) {
        stage(entity, space, transform: true);
      }
      placed = [
        for (final item in staged)
          if (item.placed) item.entity.id,
      ];
    }

    for (final item in staged) {
      transaction.add(item.entity.remappedIds(remap), blockName: item.owner);
    }

    return placed;
  }

  void _importTables(Transaction transaction) {
    final document = transaction.document;
    for (final layer in layers.values) {
      if (_namedLayer(document, layer.name) != null) continue;
      transaction.putLayer(layer);
    }
    for (final lineType in lineTypes.values) {
      if (_namedLineType(document, lineType.name) != null) continue;
      transaction.putLineType(lineType);
    }
    for (final style in textStyles.values) {
      if (_namedTextStyle(document, style.name) != null) continue;
      transaction.putTextStyle(style);
    }
    for (final style in dimStyles.values) {
      if (document.namedDimStyle(style.name) != null) continue;
      transaction.putDimStyle(style);
    }
  }
}

/// Process-wide CAD clipboard. One clip is shared across document tabs.
class DrawingClipboard {
  DrawingClip? clip;

  bool get isEmpty => clip == null || clip!.isEmpty;
}

Iterable<String> _referencedBlockNames(CadEntity entity) sync* {
  if (entity is InsertEntity && entity.blockName.isNotEmpty) {
    yield entity.blockName;
  }
  if (entity is DimensionEntity && entity.blockName.isNotEmpty) {
    yield entity.blockName;
  }
}

String? _textStyleName(CadEntity entity) {
  if (entity is TextEntity) return entity.styleName;
  if (entity is MTextEntity) return entity.styleName;
  if (entity is DimensionEntity) return entity.styleName;
  return null;
}

void _takeLayer(
  CadDocument document,
  Map<String, LayerDef> layers,
  Map<String, LineTypeDef> lineTypes,
  String name,
) {
  if (name.isEmpty) return;
  final layer = _namedLayer(document, name);
  if (layer == null) return;
  layers[layer.name] = layer;
  _takeLineType(document, lineTypes, layer.lineType);
}

void _takeLineType(
  CadDocument document,
  Map<String, LineTypeDef> lineTypes,
  String name,
) {
  if (name.isEmpty || name == 'ByLayer' || name == 'ByBlock') return;
  final def = _namedLineType(document, name);
  if (def == null) return;
  lineTypes[def.name] = def;
}

void _takeTextStyle(
  CadDocument document,
  Map<String, TextStyleDef> styles,
  String name,
) {
  if (name.isEmpty) return;
  final style = _namedTextStyle(document, name);
  if (style == null) return;
  styles[style.name] = style;
}

void _takeDimStyle(
  CadDocument document,
  Map<String, DimStyleDef> dimStyles,
  Map<String, TextStyleDef> textStyles,
  String name,
) {
  if (name.isEmpty) return;
  final style = document.namedDimStyle(name);
  if (style == null) return;
  dimStyles[style.name] = style;
  _takeTextStyle(document, textStyles, style.textStyle);
}

BlockRecord? _namedBlock(CadDocument document, String name) {
  final direct = document.blocks[name];
  if (direct != null) return direct;
  final needle = name.toUpperCase();
  for (final block in document.blocks.values) {
    if (block.name.toUpperCase() == needle) return block;
  }
  return null;
}

LayerDef? _namedLayer(CadDocument document, String name) {
  final direct = document.layer(name);
  if (direct != null) return direct;
  final needle = name.toLowerCase();
  for (final layer in document.layers.values) {
    if (layer.name.toLowerCase() == needle) return layer;
  }
  return null;
}

LineTypeDef? _namedLineType(CadDocument document, String name) {
  final direct = document.lineTypes[name];
  if (direct != null) return direct;
  final needle = name.toLowerCase();
  for (final def in document.lineTypes.values) {
    if (def.name.toLowerCase() == needle) return def;
  }
  return null;
}

TextStyleDef? _namedTextStyle(CadDocument document, String name) {
  final direct = document.textStyles[name];
  if (direct != null) return direct;
  final needle = name.toLowerCase();
  for (final style in document.textStyles.values) {
    if (style.name.toLowerCase() == needle) return style;
  }
  return null;
}

bool _hasBlock(CadDocument document, String name) =>
    _namedBlock(document, name) != null;

String _anonymousPrefix(String name) {
  if (name.length >= 2 && name.startsWith('*')) {
    final letter = name[1].toUpperCase();
    if (letter.compareTo('A') >= 0 && letter.compareTo('Z') <= 0) {
      return '*$letter';
    }
  }
  return '*U';
}

String _uniqueBlockName(
  CadDocument document,
  String prefix,
  Set<String> reserved,
) {
  var index = 1;
  while (true) {
    final name = '$prefix$index';
    if (!_hasBlock(document, name) && !reserved.contains(name.toUpperCase())) {
      return name;
    }
    index++;
  }
}

CadEntity _withBlockRefs(CadEntity entity, Map<String, String> names) {
  if (entity is InsertEntity) {
    final mapped = _mappedName(names, entity.blockName);
    if (mapped == entity.blockName) return entity;
    return InsertEntity(
      id: entity.id,
      props: entity.props,
      blockName: mapped,
      position: entity.position,
      scale: entity.scale,
      rotation: entity.rotation,
      columnCount: entity.columnCount,
      rowCount: entity.rowCount,
      columnSpacing: entity.columnSpacing,
      rowSpacing: entity.rowSpacing,
      attributes: entity.attributes,
    );
  }
  if (entity is DimensionEntity) {
    final mapped = _mappedName(names, entity.blockName);
    if (mapped == entity.blockName) return entity;
    return entity.copyWith(blockName: mapped);
  }
  return entity;
}

String _mappedName(Map<String, String> names, String original) {
  if (original.isEmpty) return original;
  final direct = names[original];
  if (direct != null) return direct;
  final needle = original.toUpperCase();
  for (final entry in names.entries) {
    if (entry.key.toUpperCase() == needle) return entry.value;
  }
  return original;
}
