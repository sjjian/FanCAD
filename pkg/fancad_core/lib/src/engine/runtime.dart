import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../model/document/layout.dart';
import '../model/entity/entity.dart';
import '../model/style.dart';
import '../presentation/contract/emit.dart';
import '../presentation/style/resolved_style.dart';
import 'api.dart';
import 'document.dart';
import 'history.dart';
import 'session.dart';

/// The [EditContext] implementation exposed by [CadEngine].
///
/// Kept out of `cad_engine.dart` so the public facade only orchestrates and the
/// spec-to-entity mapping has one home.
final class EngineEditContext extends EditContext {
  EngineEditContext(this._transaction);

  final Transaction _transaction;

  @override
  int add(Entity entity) => _transaction.add(entity as CadEntity);

  @override
  bool replace(Entity entity) => _transaction.modify(entity as CadEntity);

  @override
  int addEntity(EntitySpec spec) {
    final entity = switch (spec) {
      final LineSpec value => LineEntity(
        id: 0,
        props: _props(value.style),
        start: value.start,
        end: value.end,
      ),
      final PolylineSpec value => PolylineEntity.fromPoints(
        id: 0,
        props: _props(value.style),
        points: value.points,
        closed: value.closed,
      ),
      final CircleSpec value => CircleEntity(
        id: 0,
        props: _props(value.style),
        center: value.center,
        radius: value.radius,
      ),
      final ArcSpec value => ArcEntity(
        id: 0,
        props: _props(value.style),
        center: value.center,
        radius: value.radius,
        startAngle: value.startAngle,
        endAngle: value.endAngle,
      ),
      final PointSpec value => PointEntity(
        id: 0,
        props: _props(value.style),
        position: value.position,
      ),
      final TextSpec value => TextEntity(
        id: 0,
        props: _props(value.style),
        position: value.position,
        content: value.content,
        height: value.height,
        rotation: value.rotation,
        styleName: value.styleName,
        widthFactor: value.widthFactor,
        obliqueAngle: value.obliqueAngle,
        hAlign: value.hAlign,
        vAlign: value.vAlign,
      ),
      final InsertSpec value => InsertEntity(
        id: 0,
        props: _props(value.style),
        blockName: value.blockName,
        position: value.position,
        scale: value.scale,
        rotation: value.rotation,
        attributes: value.attributes,
      ),
    };
    return _transaction.add(entity);
  }

  @override
  void remove(Iterable<int> ids) => _transaction.eraseAll(ids);

  @override
  void transform(Iterable<int> ids, Mat3 matrix) =>
      _transaction.transformAll(ids, matrix);

  @override
  void setLayer(Iterable<int> ids, String layer) =>
      _transaction.setLayerOf(ids, layer);

  @override
  void setColor(Iterable<int> ids, CadColor color) =>
      _transaction.setColorOf(ids, color);

  @override
  void setVisible(Iterable<int> ids, bool visible) =>
      _transaction.setVisibleOf(ids, visible);

  @override
  void putLayer(
    String name, {
    CadColor color = const CadColor.indexed(7),
    bool visible = true,
    bool locked = false,
  }) => _transaction.putLayer(
    LayerDef(name: name, color: color, visible: visible, locked: locked),
  );

  static EntityProps _props(EntityStyle style) => EntityProps(
    layer: style.layer,
    color: style.color,
    lineType: style.lineType,
    lineWeight: style.lineWeight,
    lineTypeScale: style.lineTypeScale,
    transparency: style.transparency,
    visible: style.visible,
  );
}

/// Executes an [EntityQuery] against one drawing.
///
/// The facade delegates here so query filtering is not mixed into lifecycle
/// code. A later shared query service can use the same implementation from the
/// render and command layers.
final class EngineQueryRunner {
  const EngineQueryRunner._();

  static EntityQueryResult run(DocumentSession session, EntityQuery query) {
    final document = session.document;
    final ids = query.window != null
        ? document.queryVisible(query.window!)
        : [
            for (final entity in document.entitiesOf(document.currentBlockName))
              entity.id,
          ];
    final entities = <Entity>[];
    for (final id in ids) {
      final entity = document.entity(id);
      if (entity == null) continue;
      if (query.visibleOnly &&
          (!entity.props.visible ||
              !document.isLayerVisible(entity.props.layer))) {
        continue;
      }
      if (query.layers != null && !query.layers!.contains(entity.props.layer)) {
        continue;
      }
      if (query.kinds != null && !query.kinds!.contains(entity.kind)) {
        continue;
      }
      entities.add(entity);
    }
    return EntityQueryResult(
      entities: List.unmodifiable(entities),
      extents: document.extents,
    );
  }
}

/// Emits one layout of a drawing into a sink.
///
/// The public facade delegates here so lifecycle code and layout traversal stay
/// separate. Plot and scene rendering should eventually share this walker.
final class EngineEmitter {
  const EngineEmitter._();

  static void emit(
    DocumentSession session,
    GeometrySink sink,
    EmitRequest request,
  ) {
    final document = session.document;
    final layout = request.layout == null
        ? document.activeLayout
        : document.layouts.firstWhere(
            (candidate) => candidate.name == request.layout,
            orElse: () => throw ArgumentError.value(
              request.layout,
              'request.layout',
              'Unknown layout',
            ),
          );
    final context = document.emitContext(
      tolerance: request.tolerance,
      clip: request.window,
    );

    bool visible(CadEntity entity) {
      if (!entity.props.visible) return false;
      if (!document.isLayerVisible(entity.props.layer)) return false;
      if (request.layers != null &&
          !request.layers!.contains(entity.props.layer)) {
        return false;
      }
      return true;
    }

    for (final entity in document.entitiesOf(layout.blockName)) {
      if (visible(entity)) entity.emit(context, sink);
    }

    if (layout.isModelSpace) return;
    for (final viewport in layout.viewports) {
      if (!viewport.isOn) continue;
      final view = context.descend(
        viewport.modelToPaper(),
        ResolvedStyle.fallback,
      );
      for (final id
          in document
              .indexFor(document.modelSpaceBlockName)
              .search(viewport.modelWindow)) {
        final entity = document.entity(id);
        if (entity == null || !visible(entity)) continue;
        if (viewport.hidesLayer(entity.props.layer)) continue;
        entity.emit(view, sink);
      }
    }
  }
}

final class EngineDrawingView implements DrawingView {
  EngineDrawingView(this._session);

  final DocumentSession _session;

  CadDocument get _document => _session.document;

  @override
  Iterable<Entity> get entities => _document.entities;

  @override
  Entity? entity(EntityId id) => _document.entity(id);

  @override
  Iterable<Entity> entitiesIn(Bounds2 window) => [
    for (final id in _document.queryVisible(window)) ?_document.entity(id),
  ];

  @override
  Iterable<Entity> entitiesOfBlock(String blockName) =>
      _document.entitiesOf(blockName);

  @override
  Layout get activeLayout => _document.activeLayout;

  @override
  List<Layout> get layouts => _document.layouts;

  @override
  Iterable<Layer> get layers => _document.layers.values;

  @override
  Iterable<Block> get blocks => _document.blocks.values;

  @override
  Layer? layer(String name) => _document.layer(name);

  @override
  Block? block(String name) => _document.blocks[name];

  @override
  Bounds2 get extents => _document.extents;

  @override
  int get version => _document.version;
}
