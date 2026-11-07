import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../model/document/block_record.dart';
import '../model/document/layout.dart';
import '../model/entity/entity.dart';
import '../model/entity/text_alignment.dart' show TextHAlign, TextVAlign;
import '../model/style.dart' show CadColor, LayerDef, LineWeight;
import 'operations/edit.dart';

/// Shared appearance for a new entity.
///
/// The three inheritance sentinels are the same ones the drawing format uses:
/// [CadColor.byLayer], [LineWeight.byLayer] and the `ByLayer` line type.
class EntityStyle {
  const EntityStyle({
    this.layer = '0',
    this.color = const CadColor.byLayer(),
    this.lineType = 'ByLayer',
    this.lineWeight = LineWeight.byLayer,
    this.lineTypeScale = 1,
    this.transparency = -1,
    this.visible = true,
  });

  final String layer;
  final CadColor color;
  final String lineType;
  final int lineWeight;
  final double lineTypeScale;
  final int transparency;
  final bool visible;
}

/// A format-neutral description of an entity to create.
sealed class EntitySpec {
  const EntitySpec({this.style = const EntityStyle()});

  final EntityStyle style;
}

final class LineSpec extends EntitySpec {
  const LineSpec({required this.start, required this.end, super.style});

  final Vec2 start;
  final Vec2 end;
}

final class PolylineSpec extends EntitySpec {
  const PolylineSpec({required this.points, this.closed = false, super.style});

  final List<Vec2> points;
  final bool closed;
}

final class CircleSpec extends EntitySpec {
  const CircleSpec({required this.center, required this.radius, super.style});

  final Vec2 center;
  final double radius;
}

final class ArcSpec extends EntitySpec {
  const ArcSpec({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
    super.style,
  });

  final Vec2 center;
  final double radius;

  /// Radians, counter-clockwise from +X.
  final double startAngle;
  final double endAngle;
}

final class PointSpec extends EntitySpec {
  const PointSpec({required this.position, super.style});

  final Vec2 position;
}

final class TextSpec extends EntitySpec {
  const TextSpec({
    required this.position,
    required this.content,
    this.height = 2.5,
    this.rotation = 0,
    this.styleName = 'Standard',
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
    super.style,
  });

  final Vec2 position;
  final String content;
  final double height;
  final double rotation;
  final String styleName;
  final double widthFactor;
  final double obliqueAngle;
  final TextHAlign hAlign;
  final TextVAlign vAlign;
}

final class InsertSpec extends EntitySpec {
  const InsertSpec({
    required this.blockName,
    required this.position,
    this.scale = const Vec2(1, 1),
    this.rotation = 0,
    this.attributes = const {},
    super.style,
  });

  final String blockName;
  final Vec2 position;
  final Vec2 scale;
  final double rotation;
  final Map<String, String> attributes;
}

/// A read-only filter for [CadEngine.query].
class EntityQuery {
  const EntityQuery({
    this.window,
    this.layers,
    this.kinds,
    this.visibleOnly = true,
  });

  final Bounds2? window;
  final Set<String>? layers;
  final Set<EntityKind>? kinds;
  final bool visibleOnly;
}

class EntityQueryResult {
  const EntityQueryResult({required this.entities, required this.extents});

  final List<Entity> entities;
  final Bounds2 extents;
}

/// The change set produced by one [CadEngine.edit] call.
class EditResult {
  const EditResult({
    this.label = 'Edit',
    this.added = const [],
    this.removed = const [],
    this.modified = const [],
    this.tablesChanged = false,
    this.structureChanged = false,
  });

  final String label;
  final List<int> added;
  final List<int> removed;
  final List<int> modified;
  final bool tablesChanged;
  final bool structureChanged;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      modified.isEmpty &&
      !tablesChanged &&
      !structureChanged;
}

class SaveResult {
  const SaveResult({
    required this.path,
    this.usedFallback = false,
    this.reason = '',
  });

  final String path;
  final bool usedFallback;
  final String reason;
}

/// What [CadEngine.emit] should draw.
class EmitRequest {
  const EmitRequest({
    this.layout,
    this.layers,
    this.window,
    this.tolerance = 0.01,
  });

  /// Layout tab name. Null uses the active layout.
  final String? layout;
  final Set<String>? layers;
  final Bounds2? window;
  final double tolerance;
}

/// The mutation surface exposed by [CadEngine.edit].
abstract class EditContext {
  /// Adds an already-built entity. A zero id asks the engine to allocate one.
  int add(Entity entity);

  /// Replaces an existing entity, matched by [Entity.id].
  bool replace(Entity entity);

  int addEntity(EntitySpec spec);

  List<int> addEntities(Iterable<EntitySpec> specs) => [
    for (final spec in specs) addEntity(spec),
  ];

  void remove(Iterable<int> ids);

  void transform(Iterable<int> ids, Mat3 matrix);

  void setLayer(Iterable<int> ids, String layer);

  void setColor(Iterable<int> ids, CadColor color);

  void setVisible(Iterable<int> ids, bool visible);

  void putLayer(
    String name, {
    CadColor color = const CadColor.indexed(7),
    bool visible = true,
    bool locked = false,
  });
}

/// A public description of one committed change.
///
/// This is the only change type renderers and hosts need; transactions and
/// patches remain internal.
class EngineChange {
  const EngineChange({
    this.added = const [],
    this.removed = const [],
    this.modified = const [],
    this.tablesChanged = false,
    this.structureChanged = false,
  });

  final List<EntityId> added;
  final List<EntityId> removed;
  final List<EntityId> modified;
  final bool tablesChanged;
  final bool structureChanged;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      modified.isEmpty &&
      !tablesChanged &&
      !structureChanged;

  bool get isNotEmpty => !isEmpty;
}

/// Public name for a layer definition.
typedef Layer = LayerDef;

/// Public name for a block definition.
typedef Block = BlockRecord;

/// Read-only access to one drawing.
///
/// The mutable document, spatial index and transaction machinery stay inside
/// the engine. Renderers and commands read through this view and mutate through
/// `CadEngine.edit`.
abstract interface class DrawingView {
  /// Every entity in the drawing, across all blocks.
  Iterable<Entity> get entities;

  /// One entity by id, or null when it does not exist.
  Entity? entity(EntityId id);

  /// Entities whose spatial index intersects [window].
  Iterable<Entity> entitiesIn(Bounds2 window);

  /// Entities owned by one block or layout block.
  Iterable<Entity> entitiesOfBlock(String blockName);

  Layout get activeLayout;
  List<Layout> get layouts;

  Iterable<Layer> get layers;
  Iterable<Block> get blocks;

  Layer? layer(String name);
  Block? block(String name);

  Bounds2 get extents;
  int get version;
}

/// Standard geometry operations on immutable entities.
///
/// These are pure computations: callers submit the result through
/// `EditContext.replace`/`add`; the engine owns transactions and undo.
abstract final class EntityOperations {
  /// Offsets [entity] by [distance] toward [towards], or null when the type
  /// has no parallel curve.
  static Entity? offset(Entity entity, double distance, Vec2 towards) =>
      EditOperations.offset(entity as CadEntity, distance, towards);

  /// Reverses the direction of a line, polyline or spline.
  static Entity? reverse(Entity entity) =>
      EditOperations.reverse(entity as CadEntity);

  /// Rounds the intersection of two lines.
  static FilletResult? filletLines(
    LineEntity first,
    LineEntity second,
    double radius,
    Vec2 pick1,
    Vec2 pick2,
  ) => EditOperations.filletLines(first, second, radius, pick1, pick2);

  /// Cuts a chamfer at the intersection of two lines.
  static ChamferResult? chamferLines(
    LineEntity first,
    LineEntity second,
    double distance1,
    double distance2,
    Vec2 pick1,
    Vec2 pick2,
  ) => EditOperations.chamferLines(
    first,
    second,
    distance1,
    distance2,
    pick1,
    pick2,
  );
}
