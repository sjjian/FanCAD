import '../../geometry/bounds.dart';
import '../../presentation/contract/emit.dart';
import '../entity/entity.dart';
import '../style.dart';
import 'block_record.dart';
import 'layout.dart';

/// The part of a drawing that is written to DWG/DXF.
///
/// Caches, undo state, selection, active layout and current layer live on the
/// runtime [CadDocument] in the engine layer. Keeping those out of this class
/// means file readers and writers only need the model.
class DrawingData {
  DrawingData({
    String? modelSpaceBlockName,
    Map<String, LayerDef>? layers,
    Map<String, LineTypeDef>? lineTypes,
    Map<String, TextStyleDef>? textStyles,
    Map<String, DimStyleDef>? dimStyles,
  }) : modelSpaceBlockName = modelSpaceBlockName ?? defaultModelSpaceBlock {
    _layers.addAll(layers ?? {'0': const LayerDef(name: '0')});
    _lineTypes.addAll(lineTypes ?? {'Continuous': LineTypeDef.continuous});
    _textStyles.addAll(textStyles ?? {'Standard': TextStyleDef.standard});
    _dimStyles.addAll(dimStyles ?? {'Standard': DimStyleDef.standard});
    _blocks.putIfAbsent(
      this.modelSpaceBlockName,
      () => BlockRecord(name: this.modelSpaceBlockName, isLayoutBlock: true),
    );
    if (_layouts.isEmpty) {
      _layouts.add(
        Layout(
          name: 'Model',
          blockName: this.modelSpaceBlockName,
          isModelSpace: true,
        ),
      );
    }
  }

  static const String defaultModelSpaceBlock = '*Model_Space';

  final String modelSpaceBlockName;

  final Map<int, CadEntity> _entities = {};
  final Map<String, LayerDef> _layers = {};
  final Map<String, LineTypeDef> _lineTypes = {};
  final Map<String, TextStyleDef> _textStyles = {};
  final Map<String, DimStyleDef> _dimStyles = {};
  final Map<String, BlockRecord> _blocks = {};
  final List<Layout> _layouts = [];
  final Map<String, String> _headerVariables = {};

  int _nextId = 1;

  /// Current layer/style names, also written as `$CLAYER`, `$DIMSTYLE` and
  /// `$TEXTSTYLE` in the file header.
  String currentLayer = '0';
  String currentDimStyle = 'Standard';
  String currentTextStyle = 'Standard';

  Iterable<CadEntity> get entities => _entities.values;
  int get entityCount => _entities.length;
  bool get isEmpty => _entities.isEmpty;
  bool get isNotEmpty => _entities.isNotEmpty;
  Map<String, LayerDef> get layers => Map.unmodifiable(_layers);
  Map<String, LineTypeDef> get lineTypes => Map.unmodifiable(_lineTypes);
  Map<String, TextStyleDef> get textStyles => Map.unmodifiable(_textStyles);
  Map<String, DimStyleDef> get dimStyles => Map.unmodifiable(_dimStyles);
  Map<String, BlockRecord> get blocks => Map.unmodifiable(_blocks);
  List<Layout> get layouts => List.unmodifiable(_layouts);
  Map<String, String> get headerVariables => Map.unmodifiable(_headerVariables);

  /// Mutable views used by the runtime engine. File codecs use the methods.
  Map<int, CadEntity> get entityMap => _entities;
  Map<String, LayerDef> get layerMap => _layers;
  Map<String, LineTypeDef> get lineTypeMap => _lineTypes;
  Map<String, TextStyleDef> get textStyleMap => _textStyles;
  Map<String, DimStyleDef> get dimStyleMap => _dimStyles;
  Map<String, BlockRecord> get blockMap => _blocks;
  List<Layout> get layoutList => _layouts;
  Map<String, String> get headerMap => _headerVariables;

  /// Blocks that a user may insert: named, non-layout, non-anonymous.
  Iterable<BlockRecord> get insertableBlocks => _blocks.values.where(
    (block) => !block.isLayoutBlock && !block.isAnonymous,
  );

  // -------------------------------------------------------------------------
  // Identity
  // -------------------------------------------------------------------------

  int allocateId() {
    while (_entities.containsKey(_nextId)) {
      _nextId++;
    }
    return _nextId++;
  }

  void reserveId(int id) {
    if (id >= _nextId) _nextId = id + 1;
  }

  CadEntity? entity(int id) => _entities[id];

  // -------------------------------------------------------------------------
  // Entity data
  // -------------------------------------------------------------------------

  CadEntity addEntity(CadEntity entity, {String? blockName}) {
    final target = blockName ?? modelSpaceBlockName;
    final stored = _entities.containsKey(entity.id) || entity.id <= 0
        ? entity.withId(allocateId())
        : entity;
    reserveId(stored.id);
    _entities[stored.id] = stored;

    final block = _blocks[target];
    if (block == null) {
      _blocks[target] = BlockRecord(name: target, entityIds: [stored.id]);
    } else {
      _blocks[target] = block.copyWith(
        entityIds: [...block.entityIds, stored.id],
      );
    }
    return stored;
  }

  CadEntity insertEntity(
    CadEntity entity, {
    required String blockName,
    int? index,
  }) {
    _entities[entity.id] = entity;
    reserveId(entity.id);

    final block = _blocks[blockName];
    if (block == null) {
      _blocks[blockName] = BlockRecord(name: blockName, entityIds: [entity.id]);
    } else {
      final ids = [...block.entityIds];
      final at = index == null ? ids.length : index.clamp(0, ids.length);
      ids.insert(at, entity.id);
      _blocks[blockName] = block.copyWith(entityIds: ids);
    }
    return entity;
  }

  CadEntity? removeEntity(int id) {
    final existing = _entities.remove(id);
    if (existing == null) return null;
    for (final entry in _blocks.entries.toList()) {
      if (!entry.value.entityIds.contains(id)) continue;
      _blocks[entry.key] = entry.value.copyWith(
        entityIds: entry.value.entityIds.where((each) => each != id).toList(),
      );
    }
    return existing;
  }

  CadEntity? replaceEntity(CadEntity entity) {
    final previous = _entities[entity.id];
    if (previous == null) return null;
    _entities[entity.id] = entity;
    return previous;
  }

  void registerImportedEntity(CadEntity entity) {
    _entities[entity.id] = entity;
    reserveId(entity.id);
  }

  // -------------------------------------------------------------------------
  // Symbol tables
  // -------------------------------------------------------------------------

  LayerDef? layer(String name) => _layers[name];

  void putLayer(LayerDef layer) {
    _layers[layer.name] = layer;
  }

  LayerDef? removeLayer(String name) {
    if (name == '0') return null;
    return _layers.remove(name);
  }

  void putLineType(LineTypeDef lineType) {
    _lineTypes[lineType.name] = lineType;
  }

  void putTextStyle(TextStyleDef style) {
    _textStyles[style.name] = style;
  }

  TextStyleDef? namedTextStyle(String name) {
    final direct = _textStyles[name];
    if (direct != null) return direct;
    final needle = name.toLowerCase();
    for (final style in _textStyles.values) {
      if (style.name.toLowerCase() == needle) return style;
    }
    return null;
  }

  TextStyleDef? removeTextStyle(String name) {
    if (name.toLowerCase() == 'standard') return null;
    TextStyleDef? removed = _textStyles.remove(name);
    if (removed == null) {
      final match = namedTextStyle(name);
      if (match == null || match.name.toLowerCase() == 'standard') {
        return null;
      }
      removed = _textStyles.remove(match.name);
    }
    return removed;
  }

  void putDimStyle(DimStyleDef style) {
    _dimStyles[style.name] = style;
  }

  DimStyleDef? namedDimStyle(String name) {
    final direct = _dimStyles[name];
    if (direct != null) return direct;
    final needle = name.toLowerCase();
    for (final style in _dimStyles.values) {
      if (style.name.toLowerCase() == needle) return style;
    }
    return null;
  }

  DimStyleDef dimStyle(String name) {
    final found =
        namedDimStyle(name) ??
        namedDimStyle('Standard') ??
        DimStyleDef.standard;
    if ((found.scale - 1).abs() > 1e-12) return found;
    final raw = _headerVariables[r'$DIMSCALE'];
    if (raw == null || raw.isEmpty) return found;
    final headerScale = double.tryParse(raw);
    if (headerScale == null ||
        headerScale <= 0 ||
        !headerScale.isFinite ||
        (headerScale - 1).abs() < 1e-12) {
      return found;
    }
    return found.copyWith(scale: headerScale);
  }

  TextStyleDef textStyle(String name) =>
      namedTextStyle(name) ??
      namedTextStyle('Standard') ??
      TextStyleDef.standard;

  DimStyleDef? removeDimStyle(String name) {
    if (name.toLowerCase() == 'standard') return null;
    DimStyleDef? removed = _dimStyles.remove(name);
    if (removed == null) {
      final match = namedDimStyle(name);
      if (match == null || match.name.toLowerCase() == 'standard') {
        return null;
      }
      removed = _dimStyles.remove(match.name);
    }
    return removed;
  }

  void putBlock(BlockRecord block) {
    _blocks[block.name] = block;
  }

  bool renameBlock(String from, String to) {
    if (from == to || to.isEmpty) return false;
    final block = _blocks[from];
    if (block == null || block.isLayoutBlock) return false;
    if (_blocks.containsKey(to)) return false;
    _blocks.remove(from);
    _blocks[to] = block.copyWith(name: to);
    return true;
  }

  BlockRecord? removeBlock(String name) {
    final removed = _blocks.remove(name);
    if (removed == null) return null;
    for (final id in removed.entityIds) {
      _entities.remove(id);
    }
    return removed;
  }

  BlockRecord? dropBlock(String name) => _blocks.remove(name);

  String? blockContaining(int id) {
    for (final entry in _blocks.entries) {
      if (entry.value.entityIds.contains(id)) return entry.key;
    }
    return null;
  }

  void addLayout(Layout layout) {
    _layouts
      ..removeWhere((existing) => existing.name == layout.name)
      ..add(layout);
    _layouts.sort((a, b) => a.tabOrder.compareTo(b.tabOrder));
    _blocks.putIfAbsent(
      layout.blockName,
      () => BlockRecord(name: layout.blockName, isLayoutBlock: true),
    );
  }

  void setHeaderVariable(String key, String value) {
    _headerVariables[key] = value;
  }

  List<int>? entityIdsOf(String blockName) => _blocks[blockName]?.entityIds;

  List<CadEntity> entitiesOf(String blockName) {
    final block = _blocks[blockName];
    if (block == null) return const [];
    return [for (final id in block.entityIds) ?_entities[id]];
  }

  List<AttdefEntity> attdefsOf(String blockName) => [
    for (final entity in entitiesOf(blockName))
      if (entity is AttdefEntity) entity,
  ];

  /// Model-space extents without the runtime spatial index.
  ///
  /// File audit and import report only need a box, not the editing caches, so
  /// this stays on the persisted side.
  Bounds2 get extents {
    final lookup = _DataBlockLookup(this);
    var box = const Bounds2.empty();
    for (final entity in entitiesOf(modelSpaceBlockName)) {
      if (!entity.props.visible) continue;
      final piece = entity.computeBounds(blocks: lookup);
      if (!piece.isFinite) continue;
      box = box.union(piece);
    }
    return box;
  }

  @override
  String toString() =>
      'DrawingData(${_entities.length} entities, ${_blocks.length} blocks, '
      '${_layers.length} layers)';
}

class _DataBlockLookup implements BlockLookup {
  _DataBlockLookup(this.data);

  final DrawingData data;
  final Set<String> _visiting = {};

  @override
  List<int>? entityIdsOf(String blockName) => data.entityIdsOf(blockName);

  @override
  Bounds2 boundsOf(String blockName) {
    if (!_visiting.add(blockName)) return const Bounds2.empty();
    try {
      final block = data.blockMap[blockName];
      if (block == null) return const Bounds2.empty();
      var box = const Bounds2.empty();
      for (final id in block.entityIds) {
        final entity = data.entity(id);
        if (entity == null || !entity.props.visible) continue;
        box = box.union(entity.computeBounds(blocks: this));
      }
      return box;
    } finally {
      _visiting.remove(blockName);
    }
  }

  @override
  void emitBlock(String blockName, EmitContext context, GeometrySink sink) {}
}
