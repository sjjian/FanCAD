import 'package:freezed_annotation/freezed_annotation.dart';

import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../layout/paper_viewport.dart';
import 'entity.dart';
import 'geometry_sink.dart';
import 'spatial_index.dart';
import 'style.dart';
import 'units.dart';

part 'document.freezed.dart';

/// A block definition: a named, reusable collection of entities.
@freezed
abstract class BlockRecord with _$BlockRecord {
  const BlockRecord._();

  const factory BlockRecord({
    required String name,
    @Default(Vec2.zero()) Vec2 basePoint,
    @Default([]) List<int> entityIds,

    /// True for `*Model_Space` and `*Paper_Space*`, which are containers rather
    /// than insertable blocks.
    @Default(false) bool isLayoutBlock,

    /// True for generated blocks such as the `*D` dimension geometry blocks and
    /// `*U` hatch blocks, which are hidden from the block picker.
    @Default(false) bool isAnonymous,
    @Default('') String description,

    /// Non-empty when this block is an external reference.
    @Default('') String xrefPath,
  }) = _BlockRecord;

  bool get isXref => xrefPath.isNotEmpty;

  @override
  String toString() => 'BlockRecord($name, ${entityIds.length} entities)';
}

/// A model or paper space layout.
@freezed
abstract class Layout with _$Layout {
  const Layout._();

  const factory Layout({
    required String name,
    required String blockName,
    @Default(false) bool isModelSpace,
    @Default(0) int tabOrder,

    /// Paper size in millimetres.
    @Default(297) double paperWidth,
    @Default(210) double paperHeight,

    /// Plot twist in degrees: 0, 90, 180 or 270. The sheet on screen stays
    /// put; only SVG/PDF output rotates.
    @Default(0) int plotRotation,

    /// Optional plot window. Null means the full sheet, or model extents.
    Bounds2? plotWindow,

    /// Drawing units per plotted millimetre. Ignored when [plotFit] is set.
    @Default(1) double plotScale,

    /// Scale the plot window (or extents) to fill the sheet.
    @Default(false) bool plotFit,

    /// Shift of the scaled content on the sheet, in millimetres.
    @Default(0) double plotOffsetX,
    @Default(0) double plotOffsetY,

    /// Windows into model space. Empty on the model tab itself.
    @Default([]) List<PaperViewport> viewports,
  }) = _Layout;

  /// Snaps an angle to the four plot orientations AutoCAD offers.
  static int normalizePlotRotation(num degrees) {
    var quarter = (degrees / 90).round() % 4;
    if (quarter < 0) quarter += 4;
    return quarter * 90;
  }

  bool get hasCustomPlotPlacement =>
      plotFit ||
      (plotScale - 1).abs() > 1e-12 ||
      plotOffsetX.abs() > 1e-12 ||
      plotOffsetY.abs() > 1e-12;

  /// Topmost viewport whose paper rectangle contains [x],[y], or null.
  int? viewportIndexAt(double x, double y) {
    for (var i = viewports.length - 1; i >= 0; i--) {
      if (viewports[i].paperBounds.containsPoint(x, y)) return i;
    }
    return null;
  }

  @override
  String toString() => 'Layout($name -> $blockName)';
}

/// The result of applying a change to the document, describing exactly which
/// entities moved so that the renderer and the spatial index can update
/// incrementally instead of rebuilding.
@freezed
abstract class DocumentChange with _$DocumentChange {
  const DocumentChange._();

  const factory DocumentChange({
    @Default([]) List<int> added,
    @Default([]) List<int> removed,
    @Default([]) List<int> modified,

    /// A symbol table (layers, line types, styles) changed, so resolved styles
    /// must be recomputed even for untouched entities.
    @Default(false) bool tablesChanged,

    /// Blocks or layouts changed, so any cached block geometry is stale.
    @Default(false) bool structureChanged,
  }) = _DocumentChange;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      modified.isEmpty &&
      !tablesChanged &&
      !structureChanged;

  bool get isNotEmpty => !isEmpty;

  /// Whether a full regeneration is cheaper than a targeted update.
  bool get requiresFullRegeneration => tablesChanged || structureChanged;

  DocumentChange merge(DocumentChange other) => DocumentChange(
    added: [...added, ...other.added],
    removed: [...removed, ...other.removed],
    modified: [...modified, ...other.modified],
    tablesChanged: tablesChanged || other.tablesChanged,
    structureChanged: structureChanged || other.structureChanged,
  );

  @override
  String toString() =>
      'DocumentChange(+${added.length} -${removed.length} '
      '~${modified.length}${tablesChanged ? ' tables' : ''}'
      '${structureChanged ? ' structure' : ''})';
}

/// A 2D CAD drawing.
///
/// The document is deliberately *mutable*. A large drawing cannot be copied on
/// every edit, so undo is built from inverse patches (see `Transaction`) rather
/// than from snapshots. All mutation funnels through the patch application
/// methods so that no code path can change the drawing without producing a
/// [DocumentChange] and an undo record.
class CadDocument implements BlockLookup, StyleResolver {
  CadDocument({
    String? modelSpaceBlockName,
    Map<String, LayerDef>? layers,
    Map<String, LineTypeDef>? lineTypes,
    Map<String, TextStyleDef>? textStyles,
    Map<String, DimStyleDef>? dimStyles,
  }) : modelSpaceBlockName = modelSpaceBlockName ?? defaultModelSpaceBlock {
    _layers.addAll(layers ?? {'0': const LayerDef(name: '0')});
    _lineTypes.addAll(
      lineTypes ?? {'Continuous': LineTypeDef.continuous},
    );
    _textStyles.addAll(
      textStyles ?? {'Standard': TextStyleDef.standard},
    );
    _dimStyles.addAll(dimStyles ?? {'Standard': DimStyleDef.standard});
    _blocks.putIfAbsent(
      this.modelSpaceBlockName,
      () => BlockRecord(
        name: this.modelSpaceBlockName,
        isLayoutBlock: true,
      ),
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
    _activeLayoutName = _layouts.first.name;
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

  /// Spatial index per block, built lazily. Only the blocks actually being
  /// drawn or picked pay for an index.
  final Map<String, SpatialIndex> _indexes = {};

  /// Cached bounds per block, in the block's own coordinate system.
  final Map<String, Bounds2> _blockBounds = {};

  /// Reverse map from entity id to the block that owns it.
  final Map<int, String> _ownerOf = {};

  late String _activeLayoutName;
  int _nextId = 1;
  int _version = 0;

  /// Bumped on every change. Widgets and caches compare it to decide whether
  /// their derived state is stale.
  int get version => _version;

  String get activeLayoutName => _activeLayoutName;

  Layout get activeLayout => _layouts.firstWhere(
    (layout) => layout.name == _activeLayoutName,
    orElse: () => _layouts.first,
  );

  /// The block that new entities are added to.
  String get currentBlockName => activeLayout.blockName;

  /// Name of the layer that new entities are created on.
  String currentLayer = '0';

  /// Dimension style new dimensions are created with.
  String currentDimStyle = 'Standard';

  /// Tolerance used when the caller does not supply one, in model units.
  double defaultTolerance = 1e-3;

  /// Insertion units recorded in `$INSUNITS`. Missing or unknown codes are
  /// [InsUnits.unitless], the DXF default.
  InsUnits get insUnits =>
      InsUnits.fromHeader(_headerVariables[r'$INSUNITS']);

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
  Map<String, String> get headerVariables => Map.unmodifiable(
    _headerVariables,
  );

  /// Blocks that a user may insert: named, non-layout, non-anonymous.
  Iterable<BlockRecord> get insertableBlocks => _blocks.values.where(
    (block) => !block.isLayoutBlock && !block.isAnonymous,
  );

  // -------------------------------------------------------------------------
  // Identity
  // -------------------------------------------------------------------------

  /// Allocates an unused entity id.
  int allocateId() {
    while (_entities.containsKey(_nextId)) {
      _nextId++;
    }
    return _nextId++;
  }

  /// Ensures future allocations do not collide with an imported handle.
  void reserveId(int id) {
    if (id >= _nextId) _nextId = id + 1;
  }

  CadEntity? entity(int id) => _entities[id];

  /// The block that owns [id], or null when the entity is not in the document.
  String? ownerOf(int id) => _ownerOf[id];

  // -------------------------------------------------------------------------
  // Entity mutation. Callers should go through Transaction rather than these.
  // -------------------------------------------------------------------------

  /// Inserts [entity] into [blockName]. Returns the entity actually stored,
  /// which may carry a freshly allocated id.
  CadEntity addEntity(CadEntity entity, {String? blockName}) {
    final target = blockName ?? currentBlockName;
    final stored = _entities.containsKey(entity.id) || entity.id <= 0
        ? entity.withId(allocateId())
        : entity;
    reserveId(stored.id);
    _entities[stored.id] = stored;
    _ownerOf[stored.id] = target;

    final block = _blocks[target];
    if (block == null) {
      _blocks[target] = BlockRecord(name: target, entityIds: [stored.id]);
    } else {
      _blocks[target] = block.copyWith(
        entityIds: [...block.entityIds, stored.id],
      );
    }
    _indexOf(target).insert(stored.id, indexBoundsOf(stored));
    _blockBounds.remove(target);
    _version++;
    return stored;
  }

  /// Inserts [entity] preserving its exact id and draw order position.
  ///
  /// Undo relies on this: restoring an erased entity must put it back at the
  /// same index, because draw order decides what covers what.
  CadEntity insertEntity(
    CadEntity entity, {
    required String blockName,
    int? index,
  }) {
    _entities[entity.id] = entity;
    _ownerOf[entity.id] = blockName;
    reserveId(entity.id);

    final block = _blocks[blockName];
    if (block == null) {
      _blocks[blockName] = BlockRecord(
        name: blockName,
        entityIds: [entity.id],
      );
    } else {
      final ids = [...block.entityIds];
      final at = index == null ? ids.length : index.clamp(0, ids.length);
      ids.insert(at, entity.id);
      _blocks[blockName] = block.copyWith(entityIds: ids);
    }
    _indexOf(blockName).insert(entity.id, indexBoundsOf(entity));
    _blockBounds.remove(blockName);
    _version++;
    return entity;
  }

  /// The draw order position of [id] inside its owning block, or null.
  int? entityIndexOf(int id) {
    final owner = _ownerOf[id];
    if (owner == null) return null;
    final index = _blocks[owner]?.entityIds.indexOf(id) ?? -1;
    return index < 0 ? null : index;
  }

  /// Removes an entity. Returns the removed value, or null when absent.
  CadEntity? removeEntity(int id) {
    final existing = _entities.remove(id);
    if (existing == null) return null;
    final owner = _ownerOf.remove(id);
    if (owner != null) {
      final block = _blocks[owner];
      if (block != null) {
        _blocks[owner] = block.copyWith(
          entityIds: block.entityIds.where((each) => each != id).toList(),
        );
      }
      _indexes[owner]?.remove(id);
      _blockBounds.remove(owner);
    }
    _version++;
    return existing;
  }

  /// Replaces an entity in place, keeping its owning block and position.
  CadEntity? replaceEntity(CadEntity entity) {
    final previous = _entities[entity.id];
    if (previous == null) return null;
    _entities[entity.id] = entity;
    final owner = _ownerOf[entity.id];
    if (owner != null) {
      _indexOf(owner).update(entity.id, indexBoundsOf(entity));
      _blockBounds.remove(owner);
    }
    _version++;
    return previous;
  }

  // -------------------------------------------------------------------------
  // Symbol tables
  // -------------------------------------------------------------------------

  LayerDef? layer(String name) => _layers[name];

  void putLayer(LayerDef layer) {
    _layers[layer.name] = layer;
    // Insert bounds come from the block, so a freeze/thaw changes them.
    // Drop the spatial indexes too; they are rebuilt on the next query.
    _indexes.clear();
    _blockBounds.clear();
    _version++;
  }

  LayerDef? removeLayer(String name) {
    if (name == '0') return null;
    final removed = _layers.remove(name);
    if (removed != null) {
      _indexes.clear();
      _blockBounds.clear();
      _version++;
    }
    return removed;
  }

  void putLineType(LineTypeDef lineType) {
    _lineTypes[lineType.name] = lineType;
    _version++;
  }

  void putTextStyle(TextStyleDef style) {
    _textStyles[style.name] = style;
    _version++;
  }

  void putDimStyle(DimStyleDef style) {
    _dimStyles[style.name] = style;
    _version++;
  }

  /// The named style, or null when the table has no match.
  DimStyleDef? namedDimStyle(String name) {
    final direct = _dimStyles[name];
    if (direct != null) return direct;
    final needle = name.toLowerCase();
    for (final style in _dimStyles.values) {
      if (style.name.toLowerCase() == needle) return style;
    }
    return null;
  }

  @override
  DimStyleDef dimStyle(String name) {
    final found = namedDimStyle(name) ??
        namedDimStyle('Standard') ??
        DimStyleDef.standard;
    // DWG import writes $DIMSCALE on the header but not a DIMSTYLE table.
    // A style that still has the identity scale borrows that factor so a
    // regenerated or fallback measurement is not 2.5 units on a 35-unit drawing.
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

  @override
  TextStyleDef textStyle(String name) {
    final direct = _textStyles[name];
    if (direct != null) return direct;
    final needle = name.toLowerCase();
    for (final style in _textStyles.values) {
      if (style.name.toLowerCase() == needle) return style;
    }
    return _textStyles['Standard'] ?? TextStyleDef.standard;
  }

  /// Removes a dimension style. Refuses to drop Standard.
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
    if (removed != null) {
      if (currentDimStyle.toLowerCase() == removed.name.toLowerCase()) {
        currentDimStyle = 'Standard';
      }
      _version++;
    }
    return removed;
  }

  void putBlock(BlockRecord block) {
    _blocks[block.name] = block;
    _blockBounds.remove(block.name);
    for (final id in block.entityIds) {
      _ownerOf[id] = block.name;
    }
    _version++;
  }

  /// Renames a block definition without moving or deleting its entities.
  ///
  /// Inserts still name the old block until a caller updates them. Layout
  /// blocks cannot be renamed; a colliding [to] is refused.
  bool renameBlock(String from, String to) {
    if (from == to || to.isEmpty) return false;
    final block = _blocks[from];
    if (block == null || block.isLayoutBlock) return false;
    if (_blocks.containsKey(to)) return false;
    _blocks.remove(from);
    _blocks[to] = block.copyWith(name: to);
    final index = _indexes.remove(from);
    if (index != null) _indexes[to] = index;
    _blockBounds.remove(from);
    _blockBounds.remove(to);
    for (final id in block.entityIds) {
      _ownerOf[id] = to;
    }
    _version++;
    return true;
  }

  BlockRecord? removeBlock(String name) {
    final removed = _blocks.remove(name);
    if (removed == null) return null;
    for (final id in removed.entityIds) {
      _entities.remove(id);
      _ownerOf.remove(id);
    }
    _indexes.remove(name);
    _blockBounds.remove(name);
    _version++;
    return removed;
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
    _version++;
  }

  /// Drops a paper tab. Model space cannot be removed. An empty layout
  /// block that no remaining tab uses is discarded so a later new layout
  /// can reuse `*Paper_Space`.
  bool removeLayout(String name) {
    final index = _layouts.indexWhere((layout) => layout.name == name);
    if (index < 0) return false;
    final layout = _layouts[index];
    if (layout.isModelSpace) return false;
    if (_activeLayoutName == name) {
      _activeLayoutName = _layouts
          .firstWhere((item) => item.isModelSpace)
          .name;
    }
    _layouts.removeAt(index);
    final blockStillUsed = _layouts.any(
      (item) => item.blockName == layout.blockName,
    );
    if (!blockStillUsed) {
      final block = _blocks[layout.blockName];
      if (block != null &&
          block.isLayoutBlock &&
          block.entityIds.isEmpty) {
        _blocks.remove(layout.blockName);
        _indexes.remove(layout.blockName);
        _blockBounds.remove(layout.blockName);
      }
    }
    _version++;
    return true;
  }

  bool setActiveLayout(String name) {
    if (!_layouts.any((layout) => layout.name == name)) return false;
    _activeLayoutName = name;
    _version++;
    return true;
  }

  void setHeaderVariable(String key, String value) {
    _headerVariables[key] = value;
    _version++;
  }

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  SpatialIndex _indexOf(String blockName) =>
      _indexes.putIfAbsent(blockName, SpatialIndex.new);

  /// The spatial index of a block, building it on first use.
  SpatialIndex indexFor(String blockName) {
    final existing = _indexes[blockName];
    if (existing != null) return existing;
    final index = SpatialIndex();
    final block = _blocks[blockName];
    if (block != null) {
      final entries = <int, Bounds2>{};
      for (final id in block.entityIds) {
        final entity = _entities[id];
        if (entity != null) entries[id] = indexBoundsOf(entity);
      }
      index.bulkLoad(entries);
    }
    _indexes[blockName] = index;
    return index;
  }

  /// Ids in the active layout whose bounds intersect [box].
  List<int> queryVisible(Bounds2 box) => indexFor(currentBlockName)
      .search(box)
      .where((id) {
        final entity = _entities[id];
        return entity != null &&
            entity.props.visible &&
            isLayerVisible(entity.props.layer);
      })
      .toList();

  /// Entities in the given block, in draw order.
  List<CadEntity> entitiesOf(String blockName) {
    final block = _blocks[blockName];
    if (block == null) return const [];
    return [
      for (final id in block.entityIds) ?_entities[id],
    ];
  }

  /// Entities of the active layout, in draw order.
  List<CadEntity> get activeEntities => entitiesOf(currentBlockName);

  /// ATTDEFs in [blockName], in draw order.
  List<AttdefEntity> attdefsOf(String blockName) => [
    for (final entity in entitiesOf(blockName))
      if (entity is AttdefEntity) entity,
  ];

  Bounds2 boundsOfEntity(CadEntity entity) => entity.computeBounds(
    blocks: this,
    tolerance: defaultTolerance,
  );

  /// Spatial-index box. Construction lines use a long reach so window
  /// selection can find them; Zoom Extents still reads [boundsOfEntity].
  Bounds2 indexBoundsOf(CadEntity entity) => entity.indexBounds(
    blocks: this,
    tolerance: defaultTolerance,
  );

  /// The extents of the active layout.
  ///
  /// Hidden and frozen geometry is left out, so Zoom Extents frames what is
  /// actually on screen. A paper tab is a sheet, so the camera frames the
  /// paper even when the layout block itself is empty. Viewports sit on that
  /// sheet and are already inside the paper rectangle.
  Bounds2 get extents {
    final boxes = <Bounds2>[];
    for (final entity in activeEntities) {
      if (!entity.props.visible || !isLayerVisible(entity.props.layer)) {
        continue;
      }
      final box = boundsOfEntity(entity);
      if (!box.isFinite) continue;
      boxes.add(box);
    }
    final drawn = Bounds2.robustUnion(boxes);
    if (activeLayout.isModelSpace) return drawn;
    final sheet = Bounds2(0, 0, activeLayout.paperWidth, activeLayout.paperHeight);
    return drawn.isEmpty ? sheet : sheet.union(drawn);
  }

  // -------------------------------------------------------------------------
  // BlockLookup
  // -------------------------------------------------------------------------

  @override
  List<int>? entityIdsOf(String blockName) => _blocks[blockName]?.entityIds;

  @override
  void emitBlock(String blockName, EmitContext context, GeometrySink sink) {
    final block = _blocks[blockName];
    if (block == null) return;
    // The base point is the block's own origin, so entities are emitted
    // relative to it.
    final needsOffset = block.basePoint != const Vec2.zero();
    final effective = needsOffset
        ? context.descend(
            Mat3.translation(-block.basePoint.x, -block.basePoint.y),
            context.inheritedStyle,
          )
        : context;
    for (final id in block.entityIds) {
      final entity = _entities[id];
      if (entity == null || !entity.props.visible) continue;
      if (!isLayerVisible(entity.props.layer)) continue;
      entity.emit(effective, sink);
    }
  }

  @override
  Bounds2 boundsOf(String blockName) {
    final cached = _blockBounds[blockName];
    if (cached != null) return cached;
    final block = _blocks[blockName];
    if (block == null) return const Bounds2.empty();
    // Guard against a block that transitively references itself.
    _blockBounds[blockName] = const Bounds2.empty();
    var box = const Bounds2.empty();
    for (final id in block.entityIds) {
      final entity = _entities[id];
      if (entity == null) continue;
      if (!entity.props.visible || !isLayerVisible(entity.props.layer)) {
        continue;
      }
      final piece = entity.computeBounds(
        blocks: this,
        tolerance: defaultTolerance,
      );
      if (!piece.isFinite) continue;
      box = box.union(piece);
    }
    if (block.basePoint != const Vec2.zero() && box.isNotEmpty) {
      box = box.transformed(
        Mat3.translation(-block.basePoint.x, -block.basePoint.y),
      );
    }
    _blockBounds[blockName] = box;
    return box;
  }

  // -------------------------------------------------------------------------
  // StyleResolver
  // -------------------------------------------------------------------------

  @override
  ResolvedStyle resolve(EntityProps props, ResolvedStyle inherited) {
    final layerDef = _layers[props.layer];

    final color = switch (props.color.kind) {
      ColorKind.byLayer =>
        layerDef?.color ?? const CadColor.indexed(7),
      ColorKind.byBlock => inherited.color,
      _ => props.color,
    };

    final lineType = switch (props.lineType) {
      'ByLayer' => layerDef?.lineType ?? 'Continuous',
      'ByBlock' => inherited.lineType,
      _ => props.lineType,
    };

    var lineWeight = LineWeight.normalize(props.lineWeight);
    if (lineWeight == LineWeight.byLayer) {
      lineWeight = LineWeight.normalize(
        layerDef?.lineWeight ?? LineWeight.byDefault,
      );
    } else if (lineWeight == LineWeight.byBlock) {
      lineWeight = LineWeight.normalize(inherited.lineWeight);
    }
    if (lineWeight == LineWeight.byDefault) lineWeight = LineWeight.zero;

    final transparency = props.transparency >= 0
        ? props.transparency
        : layerDef?.transparency ?? 0;

    return ResolvedStyle(
      layer: props.layer,
      color: color.isInherited ? const CadColor.indexed(7) : color,
      lineType: lineType,
      lineWeight: lineWeight,
      lineTypeScale: props.lineTypeScale,
      transparency: transparency,
    );
  }

  @override
  bool isLayerVisible(String layer) =>
      _layers[layer]?.isEffectivelyVisible ?? true;

  /// Whether [layer] should appear on a plot. Off and frozen layers are
  /// omitted, and so is a layer whose Plot flag is cleared — it still draws
  /// on screen.
  bool isLayerPlottable(String layer) {
    final def = _layers[layer];
    if (def == null) return true;
    return def.plottable && def.isEffectivelyVisible;
  }

  /// Whether entities on [layer] can be edited.
  bool isLayerEditable(String layer) => _layers[layer]?.isEditable ?? true;

  /// Whether [entity] can be picked.
  ///
  /// Selectability and editability are deliberately different: an object on a
  /// locked layer can be selected and inspected, which is how you find out what
  /// it is, but a transaction will refuse to change it.
  bool isSelectable(CadEntity entity) =>
      entity.props.visible && isLayerVisible(entity.props.layer);

  /// An [EmitContext] configured for this document.
  EmitContext emitContext({
    required double tolerance,
    Bounds2? clip,
    Mat3 transform = const Mat3.identity(),
    double Function(String text, double height)? measureWidth,
    ShxFontTable shxFonts = const ShxFontTable(),
  }) {
    final style = textStyle('Standard');
    final shx = shxFonts.lookup(style.fontFamily);
    return EmitContext(
      tolerance: tolerance,
      transform: transform,
      blocks: this,
      styles: this,
      clip: clip,
      shxFonts: shxFonts,
      measureWidth: (shx != null)
          ? (text, height) => shx.measureWidth(
              text,
              height: height,
              widthFactor: style.widthFactor,
            )
          : measureWidth,
    );
  }

  /// Drops every cached index and bounds. Used after a bulk import.
  void invalidateCaches() {
    _indexes.clear();
    _blockBounds.clear();
    _version++;
  }

  /// Rebuilds the owner map and spatial indexes from the block table. Called
  /// once after an importer has populated the document directly.
  void reindex() {
    _ownerOf.clear();
    _indexes.clear();
    _blockBounds.clear();
    for (final block in _blocks.values) {
      final entries = <int, Bounds2>{};
      for (final id in block.entityIds) {
        _ownerOf[id] = block.name;
        final entity = _entities[id];
        if (entity != null) entries[id] = indexBoundsOf(entity);
      }
      final index = SpatialIndex();
      index.bulkLoad(entries);
      _indexes[block.name] = index;
    }
    _version++;
  }

  /// Registers an imported entity without touching the block's id list, for
  /// importers that build the block table themselves.
  void registerImportedEntity(CadEntity entity) {
    _entities[entity.id] = entity;
    reserveId(entity.id);
  }

  @override
  String toString() =>
      'CadDocument(${_entities.length} entities, ${_blocks.length} blocks, '
      '${_layers.length} layers)';
}
