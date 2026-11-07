import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../model/document/block_record.dart';
import '../model/document/drawing_data.dart';
import '../model/document/layout.dart';
import '../model/document/units.dart';
import '../model/entity/entity.dart';
import '../model/style.dart';
import '../presentation/contract/emit.dart';
import '../presentation/style/resolved_style.dart';
import '../presentation/text/shx_font_table.dart';
import 'spatial_index.dart';

/// The runtime view of one drawing.
///
/// [DrawingData] is the persisted document. This class adds the spatial index,
/// block bounds, current layout/block and the style/emit helpers that only make
/// sense while editing.
class CadDocument extends DrawingData
    implements BlockLookup, StyleResolver, ExplodeSource {
  CadDocument({
    super.modelSpaceBlockName,
    super.layers,
    super.lineTypes,
    super.textStyles,
    super.dimStyles,
  }) {
    _activeLayoutName = layoutList.first.name;
  }

  /// Wraps a drawing read by the IO layer and builds the runtime caches.
  factory CadDocument.fromData(DrawingData source) {
    final document = CadDocument(
      modelSpaceBlockName: source.modelSpaceBlockName,
      layers: source.layers,
      lineTypes: source.lineTypes,
      textStyles: source.textStyles,
      dimStyles: source.dimStyles,
    );
    document.entityMap
      ..clear()
      ..addAll(source.entityMap);
    document.blockMap
      ..clear()
      ..addAll(source.blockMap);
    document.layoutList
      ..clear()
      ..addAll(source.layoutList);
    document.headerMap
      ..clear()
      ..addAll(source.headerMap);
    document.currentLayer = source.currentLayer;
    document.currentDimStyle = source.currentDimStyle;
    document.currentTextStyle = source.currentTextStyle;
    document._activeLayoutName = document.layoutList.first.name;
    document.reindex();
    return document;
  }

  static const String defaultModelSpaceBlock =
      DrawingData.defaultModelSpaceBlock;

  /// Spatial index per block, built lazily. Only the blocks actually being
  /// drawn or picked pay for an index.
  final Map<String, SpatialIndex> _indexes = {};

  /// Cached bounds per block, in the block's own coordinate system.
  final Map<String, Bounds2> _blockBounds = {};

  /// Reverse map from entity id to the block that owns it.
  final Map<int, String> _ownerOf = {};

  late String _activeLayoutName;

  /// Block opened for editing. Not written to the file and not an undo step.
  /// Null means the active layout is the current space.
  String? _editedBlockName;

  int _version = 0;

  /// Cached extents and the state they were computed from.
  ///
  /// Extents walk every visible entity, so a renderer asking once per frame
  /// must not pay an O(n) recomputation when nothing changed. `version` covers
  /// entity and table edits; the tolerance is part of the key because callers
  /// may change it without touching the document.
  int _extentsVersion = -1;
  double _extentsTolerance = double.nan;
  Bounds2? _extentsCache;

  /// Cached unmodifiable table views. `DrawingData` builds a fresh
  /// `Map.unmodifiable` / `List.unmodifiable` on every read, which is fine for
  /// file IO but wasteful in a frame loop. Rebuild only when the relevant table
  /// changes, not on every entity edit.
  int _tableVersion = 0;
  int _tableViewVersion = -1;
  Map<String, LayerDef>? _layersView;
  Map<String, LineTypeDef>? _lineTypesView;
  Map<String, TextStyleDef>? _textStylesView;
  Map<String, DimStyleDef>? _dimStylesView;
  List<Layout>? _layoutsView;
  Map<String, String>? _headerVariablesView;

  /// Block records change when membership changes, so this cache follows
  /// [version], not [_tableVersion].
  int _blocksViewVersion = -1;
  Map<String, BlockRecord>? _blocksView;

  /// Bumped on every change. Widgets and caches compare it to decide whether
  /// their derived state is stale.
  int get version => _version;

  void _refreshTableViews() {
    if (_tableViewVersion == _tableVersion) return;
    _layersView = super.layers;
    _lineTypesView = super.lineTypes;
    _textStylesView = super.textStyles;
    _dimStylesView = super.dimStyles;
    _layoutsView = super.layouts;
    _headerVariablesView = super.headerVariables;
    _tableViewVersion = _tableVersion;
  }

  @override
  Map<String, LayerDef> get layers {
    _refreshTableViews();
    return _layersView!;
  }

  @override
  Map<String, LineTypeDef> get lineTypes {
    _refreshTableViews();
    return _lineTypesView!;
  }

  @override
  Map<String, TextStyleDef> get textStyles {
    _refreshTableViews();
    return _textStylesView!;
  }

  @override
  Map<String, DimStyleDef> get dimStyles {
    _refreshTableViews();
    return _dimStylesView!;
  }

  @override
  Map<String, BlockRecord> get blocks {
    if (_blocksViewVersion != _version) {
      _blocksView = super.blocks;
      _blocksViewVersion = _version;
    }
    return _blocksView!;
  }

  @override
  List<Layout> get layouts {
    _refreshTableViews();
    return _layoutsView!;
  }

  @override
  Map<String, String> get headerVariables {
    _refreshTableViews();
    return _headerVariablesView!;
  }

  String get activeLayoutName => _activeLayoutName;

  Layout get activeLayout => layoutList.firstWhere(
    (layout) => layout.name == _activeLayoutName,
    orElse: () => layoutList.first,
  );

  /// The block that new entities are added to.
  ///
  /// This is the active layout, unless [setEditedBlock] has opened a block
  /// definition. That target is not stored in the file.
  String get currentBlockName => _editedBlockName ?? activeLayout.blockName;

  /// The block definition open on the canvas, or null in normal layout editing.
  String? get editedBlockName => _editedBlockName;

  bool get isEditingBlock => _editedBlockName != null;

  /// Opens [name] for editing, or leaves block edit when [name] is null.
  ///
  /// Layout blocks, anonymous blocks and unknown names are refused. The choice
  /// is not an undo step.
  bool setEditedBlock(String? name) {
    if (name == null || name.isEmpty) {
      if (_editedBlockName == null) return true;
      _editedBlockName = null;
      _version++;
      return true;
    }
    final key = name.toUpperCase();
    BlockRecord? block;
    for (final candidate in blockMap.values) {
      if (candidate.name.toUpperCase() == key) {
        block = candidate;
        break;
      }
    }
    if (block == null || block.isLayoutBlock || block.isAnonymous) return false;
    if (_editedBlockName == block.name) return true;
    _editedBlockName = block.name;
    _version++;
    return true;
  }

  /// Tolerance used when the caller does not supply one, in model units.
  double defaultTolerance = 1e-3;

  /// Insertion units recorded in `$INSUNITS`. Missing or unknown codes are
  /// [InsUnits.unitless], the DXF default.
  InsUnits get insUnits => InsUnits.fromHeader(headerMap[r'$INSUNITS']);

  /// `$PDMODE` / `$PDSIZE`. Missing headers keep a visible POINT marker.
  PointDisplay get pointDisplay => PointDisplay.fromHeaders(headerMap);

  /// The block that owns [id], or null when the entity is not in the document.
  String? ownerOf(int id) => _ownerOf[id];

  // -------------------------------------------------------------------------
  // Entity mutation. Callers should go through Transaction rather than these.
  // -------------------------------------------------------------------------

  @override
  CadEntity addEntity(CadEntity entity, {String? blockName}) {
    final target = blockName ?? currentBlockName;
    final stored = super.addEntity(entity, blockName: target);
    _ownerOf[stored.id] = target;
    _indexInsert(target, stored.id, indexBoundsOf(stored));
    _blockBounds.remove(target);
    _reindexDimensionsUsingBlock(target);
    _version++;
    return stored;
  }

  @override
  CadEntity insertEntity(
    CadEntity entity, {
    required String blockName,
    int? index,
  }) {
    super.insertEntity(entity, blockName: blockName, index: index);
    _ownerOf[entity.id] = blockName;
    _indexInsert(blockName, entity.id, indexBoundsOf(entity));
    _blockBounds.remove(blockName);
    _reindexDimensionsUsingBlock(blockName);
    _version++;
    return entity;
  }

  /// The draw order position of [id] inside its owning block, or null.
  int? entityIndexOf(int id) {
    final owner = _ownerOf[id];
    if (owner == null) return null;
    final index = blockMap[owner]?.entityIds.indexOf(id) ?? -1;
    return index < 0 ? null : index;
  }

  @override
  CadEntity? removeEntity(int id) {
    final owner = _ownerOf.remove(id);
    final existing = super.removeEntity(id);
    if (existing == null) return null;
    if (owner != null) {
      _indexes[owner]?.remove(id);
      _blockBounds.remove(owner);
      _reindexDimensionsUsingBlock(owner);
    }
    _version++;
    return existing;
  }

  @override
  CadEntity? replaceEntity(CadEntity entity) {
    final previous = super.replaceEntity(entity);
    if (previous == null) return null;
    final owner = _ownerOf[entity.id];
    if (owner != null) {
      _indexUpdate(owner, entity.id, indexBoundsOf(entity));
      _blockBounds.remove(owner);
      _reindexDimensionsUsingBlock(owner);
    }
    _version++;
    return previous;
  }

  @override
  void putLayer(LayerDef layer) {
    super.putLayer(layer);
    // Insert bounds come from the block, so a freeze/thaw changes them.
    // Drop the spatial indexes too; they are rebuilt on the next query.
    _indexes.clear();
    _blockBounds.clear();
    _tableVersion++;
    _version++;
  }

  @override
  LayerDef? removeLayer(String name) {
    final removed = super.removeLayer(name);
    if (removed != null) {
      _indexes.clear();
      _blockBounds.clear();
      _tableVersion++;
      _version++;
    }
    return removed;
  }

  @override
  void putLineType(LineTypeDef lineType) {
    super.putLineType(lineType);
    _tableVersion++;
    _version++;
  }

  @override
  void putTextStyle(TextStyleDef style) {
    super.putTextStyle(style);
    _tableVersion++;
    _version++;
  }

  @override
  TextStyleDef? removeTextStyle(String name) {
    final removed = super.removeTextStyle(name);
    if (removed != null) {
      if (currentTextStyle.toLowerCase() == removed.name.toLowerCase()) {
        currentTextStyle = 'Standard';
      }
      _tableVersion++;
      _version++;
    }
    return removed;
  }

  @override
  void putDimStyle(DimStyleDef style) {
    super.putDimStyle(style);
    _tableVersion++;
    _version++;
  }

  @override
  DimStyleDef? removeDimStyle(String name) {
    final removed = super.removeDimStyle(name);
    if (removed != null) {
      if (currentDimStyle.toLowerCase() == removed.name.toLowerCase()) {
        currentDimStyle = 'Standard';
      }
      _tableVersion++;
      _version++;
    }
    return removed;
  }

  @override
  void putBlock(BlockRecord block) {
    super.putBlock(block);
    _blockBounds.remove(block.name);
    for (final id in block.entityIds) {
      _ownerOf[id] = block.name;
    }
    _tableVersion++;
    _version++;
  }

  /// Renames a block definition without moving or deleting its entities.
  ///
  /// Inserts still name the old block until a caller updates them. Layout
  /// blocks cannot be renamed; a colliding [to] is refused.
  @override
  bool renameBlock(String from, String to) {
    if (!super.renameBlock(from, to)) return false;
    if (_editedBlockName == from) _editedBlockName = to;
    final index = _indexes.remove(from);
    if (index != null) _indexes[to] = index;
    _blockBounds.remove(from);
    _blockBounds.remove(to);
    for (final id in blockMap[to]?.entityIds ?? const <int>[]) {
      _ownerOf[id] = to;
    }
    _tableVersion++;
    _version++;
    return true;
  }

  @override
  BlockRecord? removeBlock(String name) {
    final removed = super.removeBlock(name);
    if (removed == null) return null;
    for (final id in removed.entityIds) {
      _ownerOf.remove(id);
    }
    _indexes.remove(name);
    _blockBounds.remove(name);
    if (_editedBlockName == name) _editedBlockName = null;
    _tableVersion++;
    _version++;
    return removed;
  }

  /// Removes a block definition but keeps the entities it named.
  ///
  /// This is what undoing "create a block" needs: the entities exist
  /// independently of the definition, so only the definition and the
  /// membership are undone. Ownership falls back to whichever remaining block
  /// still lists the id, or clears when none does. Prefer [removeBlock] when
  /// the entities are supposed to die with the block.
  @override
  BlockRecord? dropBlock(String name) {
    final removed = super.dropBlock(name);
    if (removed == null) return null;
    for (final id in removed.entityIds) {
      if (_ownerOf[id] != name) continue;
      final fallback = blockContaining(id);
      if (fallback == null) {
        _ownerOf.remove(id);
      } else {
        _ownerOf[id] = fallback;
      }
    }
    _indexes.remove(name);
    _blockBounds.remove(name);
    if (_editedBlockName == name) _editedBlockName = null;
    _tableVersion++;
    _version++;
    return removed;
  }

  @override
  void addLayout(Layout layout) {
    super.addLayout(layout);
    _tableVersion++;
    _version++;
  }

  /// Drops a paper tab. Model space cannot be removed. An empty layout
  /// block that no remaining tab uses is discarded so a later new layout
  /// can reuse `*Paper_Space`.
  bool removeLayout(String name) {
    final index = layoutList.indexWhere((layout) => layout.name == name);
    if (index < 0) return false;
    final layout = layoutList[index];
    if (layout.isModelSpace) return false;
    if (_activeLayoutName == name) {
      _activeLayoutName = layoutList
          .firstWhere((item) => item.isModelSpace)
          .name;
    }
    layoutList.removeAt(index);
    final blockStillUsed = layoutList.any(
      (item) => item.blockName == layout.blockName,
    );
    if (!blockStillUsed) {
      final block = blockMap[layout.blockName];
      if (block != null && block.isLayoutBlock && block.entityIds.isEmpty) {
        blockMap.remove(layout.blockName);
        _indexes.remove(layout.blockName);
        _blockBounds.remove(layout.blockName);
      }
    }
    _tableVersion++;
    _version++;
    return true;
  }

  bool setActiveLayout(String name) {
    if (!layoutList.any((layout) => layout.name == name)) return false;
    _editedBlockName = null;
    _activeLayoutName = name;
    _version++;
    return true;
  }

  @override
  void setHeaderVariable(String key, String value) {
    super.setHeaderVariable(key, value);
    _tableVersion++;
    _version++;
  }

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  /// Mutates a live spatial cache. [putLayer] drops the indexes so freeze
  /// bounds can refresh; the next [indexFor] rebuilds from entity ids. A
  /// fresh empty tree here would hide every object that was already drawn.
  void _indexInsert(String blockName, int id, Bounds2 bounds) {
    _indexes[blockName]?.insert(id, bounds);
  }

  void _indexUpdate(String blockName, int id, Bounds2 bounds) {
    _indexes[blockName]?.update(id, bounds);
  }

  /// A dimension's pick box is the emitted `*D` strokes, not just the
  /// definition points. Moving those strokes without refreshing the
  /// dimension leaves it selectable only where it used to be.
  void _reindexDimensionsUsingBlock(String blockName) {
    if (!_isDimensionBlockName(blockName)) return;
    for (final entity in entityMap.values) {
      if (entity is! DimensionEntity || entity.blockName != blockName) {
        continue;
      }
      final owner = _ownerOf[entity.id];
      if (owner == null) continue;
      _indexUpdate(owner, entity.id, indexBoundsOf(entity));
      _blockBounds.remove(owner);
    }
  }

  static bool _isDimensionBlockName(String name) =>
      name.length >= 2 &&
      name.codeUnitAt(0) == 0x2A &&
      (name.codeUnitAt(1) == 0x44 || name.codeUnitAt(1) == 0x64);

  /// The spatial index of a block, building it on first use.
  SpatialIndex indexFor(String blockName) {
    final existing = _indexes[blockName];
    if (existing != null) return existing;
    final index = SpatialIndex();
    final block = blockMap[blockName];
    if (block != null) {
      final entries = <int, Bounds2>{};
      for (final id in block.entityIds) {
        final entity = entityMap[id];
        if (entity != null) entries[id] = indexBoundsOf(entity);
      }
      index.bulkLoad(entries);
    }
    _indexes[blockName] = index;
    return index;
  }

  /// Ids in the active layout whose bounds intersect [box].
  List<int> queryVisible(Bounds2 box) =>
      indexFor(currentBlockName).search(box).where((id) {
        final entity = entityMap[id];
        return entity != null &&
            entity.props.visible &&
            isLayerVisible(entity.props.layer);
      }).toList();

  /// Entities in the given block, in draw order.
  @override
  List<CadEntity> entitiesOf(String blockName) {
    final block = blockMap[blockName];
    if (block == null) return const [];
    return [for (final id in block.entityIds) ?entityMap[id]];
  }

  /// Entities of the active layout, in draw order.
  List<CadEntity> get activeEntities => entitiesOf(currentBlockName);

  /// ATTDEFs in [blockName], in draw order.
  @override
  List<AttdefEntity> attdefsOf(String blockName) => [
    for (final entity in entitiesOf(blockName))
      if (entity is AttdefEntity) entity,
  ];

  Bounds2 boundsOfEntity(CadEntity entity) =>
      entity.computeBounds(blocks: this, tolerance: defaultTolerance);

  /// Spatial-index box. Construction lines use a long reach so window
  /// selection can find them; Zoom Extents still reads [boundsOfEntity].
  Bounds2 indexBoundsOf(CadEntity entity) =>
      entity.indexBounds(blocks: this, tolerance: defaultTolerance);

  /// The extents of the active layout.
  ///
  /// Hidden and frozen geometry is left out, so Zoom Extents frames what is
  /// actually on screen. A paper tab is a sheet, so the camera frames the
  /// paper even when the layout block itself is empty. Viewports sit on that
  /// sheet and are already inside the paper rectangle.
  @override
  Bounds2 get extents {
    final cached = _extentsCache;
    if (cached != null &&
        _extentsVersion == _version &&
        _extentsTolerance == defaultTolerance) {
      return cached;
    }
    final box = _computeExtents();
    _extentsCache = box;
    _extentsVersion = _version;
    _extentsTolerance = defaultTolerance;
    return box;
  }

  Bounds2 _computeExtents() {
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
    if (isEditingBlock) {
      final block = blockMap[_editedBlockName];
      var box = drawn;
      if (block != null) {
        box = box.expandToInclude(block.basePoint.x, block.basePoint.y);
      }
      // A point-sized definition would clamp the camera to maximum zoom.
      if (box.isEmpty || (box.width < 1 && box.height < 1)) {
        final origin = block?.basePoint ?? Vec2.zero();
        return Bounds2(
          origin.x - 100,
          origin.y - 100,
          origin.x + 100,
          origin.y + 100,
        );
      }
      return box;
    }
    if (activeLayout.isModelSpace) return drawn;
    final sheet = Bounds2(
      0,
      0,
      activeLayout.paperWidth,
      activeLayout.paperHeight,
    );
    return drawn.isEmpty ? sheet : sheet.union(drawn);
  }

  // -------------------------------------------------------------------------
  // BlockLookup
  // -------------------------------------------------------------------------

  @override
  List<int>? entityIdsOf(String blockName) => blockMap[blockName]?.entityIds;

  @override
  void emitBlock(String blockName, EmitContext context, GeometrySink sink) {
    final block = blockMap[blockName];
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
    final minExtent = effective.minExtent;
    // The caller's query is in output coordinates; this block's entities are
    // in its own. Asking the block's index instead of walking every id is
    // what keeps a block that fans out into millions of leaves from costing
    // seconds when only a few of them are on screen.
    final query = _localQuery(effective);
    final index = minExtent > 0 || query != null ? indexFor(blockName) : null;
    final ids = query == null
        ? block.entityIds
        : [...index!.search(query), ...index.unplaced];
    for (final id in ids) {
      final entity = entityMap[id];
      if (entity == null || !entity.props.visible) continue;
      if (!isLayerVisible(entity.props.layer)) continue;
      final bounds = index?.boundsOf(id);
      if (emitTextPlaceholder(entity, effective, sink, bounds)) continue;
      // Each type decides whether this zoom makes it a pixel. The index
      // box is a hint so a spline does not tessellate just to collapse.
      entity.emit(
        bounds != null && bounds.isNotEmpty
            ? effective.withExtentHint(bounds)
            : effective,
        sink,
      );
    }
  }

  /// [EmitContext.query] in the coordinates of the block [context] is about
  /// to emit, or null when there is nothing to cull by.
  ///
  /// A block emitted through an INSERT is rotated, scaled and translated, so
  /// the visible box has to go through the inverse of that transform. A
  /// singular transform has no inverse; the caller then emits everything,
  /// which is what a degenerate block would draw anyway.
  static Bounds2? _localQuery(EmitContext context) {
    final query = context.query;
    if (query == null || query.isEmpty) return null;
    if (context.transform.isIdentity) return query;
    final inverse = context.transform.inverted();
    if (inverse == null) return null;
    return query.transformed(inverse);
  }

  @override
  Bounds2 boundsOf(String blockName) {
    final cached = _blockBounds[blockName];
    if (cached != null) return cached;
    final block = blockMap[blockName];
    if (block == null) return const Bounds2.empty();
    // Guard against a block that transitively references itself.
    _blockBounds[blockName] = const Bounds2.empty();
    var box = const Bounds2.empty();
    for (final id in block.entityIds) {
      final entity = entityMap[id];
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
    final layerDef = layerMap[props.layer];

    final color = switch (props.color.kind) {
      ColorKind.byLayer => layerDef?.color ?? const CadColor.indexed(7),
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
      layerMap[layer]?.isEffectivelyVisible ?? true;

  /// Whether [layer] should appear on a plot. Off and frozen layers are
  /// omitted, and so is a layer whose Plot flag is cleared — it still draws
  /// on screen.
  bool isLayerPlottable(String layer) {
    final def = layerMap[layer];
    if (def == null) return true;
    return def.plottable && def.isEffectivelyVisible;
  }

  /// Whether entities on [layer] can be edited.
  bool isLayerEditable(String layer) => layerMap[layer]?.isEditable ?? true;

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
    double minExtent = 0,
    double pixelsPerUnit = 0,
    Bounds2? query,
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
      pointDisplay: pointDisplay,
      minExtent: minExtent,
      pixelsPerUnit: pixelsPerUnit,
      query: query,
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
    for (final block in blockMap.values) {
      final entries = <int, Bounds2>{};
      for (final id in block.entityIds) {
        _ownerOf[id] = block.name;
        final entity = entityMap[id];
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
  @override
  void registerImportedEntity(CadEntity entity) {
    entityMap[entity.id] = entity;
    reserveId(entity.id);
  }

  @override
  String toString() =>
      'CadDocument(${entityMap.length} entities, ${blockMap.length} blocks, '
      '${layerMap.length} layers)';
}
