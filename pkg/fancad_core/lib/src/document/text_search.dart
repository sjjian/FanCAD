import '../geometry/bounds.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import 'document.dart';
import 'entity.dart';

/// What a canvas text search hit is, so the UI can label it without
/// re-reading the entity.
enum TextSearchKind { text, mtext, attribute, mleader, dimension }

/// One piece of text that is actually drawn in the current space.
///
/// [selectId] is the object the user can select: the text itself, or the
/// insert that carries a block's text. [bounds] and [height] are in the same
/// coordinates as the canvas, after the block base point and insert transform.
class TextSearchHit {
  const TextSearchHit({
    required this.selectId,
    required this.kind,
    required this.text,
    required this.layer,
    required this.bounds,
    required this.height,
    required this.anchor,
    this.tag,
  });

  final int selectId;
  final TextSearchKind kind;
  final String text;
  final String layer;
  final String? tag;
  final Bounds2 bounds;
  final double height;

  /// Sort key. Y is up, so a larger Y is higher on the sheet.
  final Vec2 anchor;
}

class _TextSearchCache {
  int version = -1;
  String block = '';
  List<TextSearchHit> hits = const [];
}

final Expando<_TextSearchCache> _textSearchCache = Expando();

/// Visible text in [document]'s current layout, or in the block being edited.
///
/// The list is cached until the document version or the current block changes.
/// Keystrokes should filter it with [filterTextSearchHits] instead of walking
/// the drawing again. Other layouts are not included. Text inside an insert is
/// one hit per instance, selecting that insert. A dimension's `*D` glyphs are
/// folded onto the dimension so the same number is not listed twice.
List<TextSearchHit> textSearchHits(CadDocument document) {
  final cache = _textSearchCache[document] ??= _TextSearchCache();
  if (cache.version == document.version &&
      cache.block == document.currentBlockName) {
    return cache.hits;
  }
  final blocks = document.blocks;
  final hits = <TextSearchHit>[];
  final current = blocks[document.currentBlockName];
  _collect(
    document,
    blocks,
    document.currentBlockName,
    _shifted(const Mat3.identity(), current?.basePoint ?? const Vec2.zero()),
    null,
    null,
    0,
    <String>{},
    hits,
  );
  hits.sort((a, b) {
    final dy = b.anchor.y.compareTo(a.anchor.y);
    if (dy != 0) return dy;
    return a.anchor.x.compareTo(b.anchor.x);
  });
  cache
    ..version = document.version
    ..block = document.currentBlockName
    ..hits = List.unmodifiable(hits);
  return cache.hits;
}

/// Case-insensitive substring match. An empty query matches nothing, so
/// a blank field does not list the whole drawing.
List<TextSearchHit> filterTextSearchHits(
  List<TextSearchHit> hits,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return [
    for (final hit in hits)
      if (hit.text.toLowerCase().contains(needle)) hit,
  ];
}

const int _maxDepth = 32;

void _collect(
  CadDocument document,
  Map<String, BlockRecord> blocks,
  String blockName,
  Mat3 transform,
  int? selectId,
  Map<String, String>? attributeValues,
  int depth,
  Set<String> stack,
  List<TextSearchHit> hits,
) {
  if (depth > _maxDepth || !stack.add(blockName)) return;
  try {
    for (final entity in document.entitiesOf(blockName)) {
      if (!entity.props.visible ||
          !document.isLayerVisible(entity.props.layer)) {
        continue;
      }
      switch (entity) {
        case TextEntity():
          _addNote(
            hits,
            entity: entity,
            kind: TextSearchKind.text,
            plain: decodeDrawnText(entity.content),
            height: entity.height,
            local: entity.computeBounds(),
            anchor: entity.position,
            transform: transform,
            selectId: selectId,
          );
        case MTextEntity():
          _addNote(
            hits,
            entity: entity,
            kind: TextSearchKind.mtext,
            plain: decodeDrawnText(entity.content),
            height: entity.height,
            local: entity.computeBounds(),
            anchor: entity.position,
            transform: transform,
            selectId: selectId,
          );
        case MLeaderEntity():
          final note = MTextEntity(
            id: entity.id,
            props: entity.props,
            position: entity.textPosition,
            content: entity.content,
            height: entity.textHeight,
            rotation: entity.textRotation,
            styleName: entity.styleName,
            attachment: entity.attachment,
          );
          _addNote(
            hits,
            entity: entity,
            kind: TextSearchKind.mleader,
            plain: decodeDrawnText(entity.content),
            height: entity.textHeight,
            local: note.computeBounds(),
            anchor: entity.textPosition,
            transform: transform,
            selectId: selectId,
          );
        case AttribEntity():
          if (entity.invisible) continue;
          _addNote(
            hits,
            entity: entity,
            kind: TextSearchKind.attribute,
            plain: decodeDrawnText(entity.value),
            height: entity.height,
            local: entity.computeBounds(),
            anchor: entity.position,
            transform: transform,
            selectId: selectId,
            tag: entity.tag,
          );
        case AttdefEntity():
          if (entity.invisible) continue;
          final raw = attributeValues != null
              ? (attributeValues[entity.tag] ?? entity.defaultValue)
              : entity.displayText;
          _addNote(
            hits,
            entity: entity,
            kind: TextSearchKind.attribute,
            plain: decodeDrawnText(raw),
            height: entity.height,
            local: entity.computeBounds(),
            anchor: entity.position,
            transform: transform,
            selectId: selectId,
            tag: entity.tag,
          );
        case DimensionEntity():
          _addDimension(document, blocks, hits, entity, transform, selectId);
        case InsertEntity():
          final block = blocks[entity.blockName];
          // Anonymous blocks are dimension pictures and hatches. Their text
          // belongs to the dimension, which is indexed on its own.
          if (block == null ||
              block.isAnonymous ||
              block.isLayoutBlock ||
              entity.blockName.startsWith('*')) {
            continue;
          }
          final columns = entity.columnCount < 1 ? 1 : entity.columnCount;
          final rows = entity.rowCount < 1 ? 1 : entity.rowCount;
          for (var row = 0; row < rows; row++) {
            for (var column = 0; column < columns; column++) {
              final placed = _shifted(
                transform.multiplied(entity.transformFor(column, row)),
                block.basePoint,
              );
              _collect(
                document,
                blocks,
                entity.blockName,
                placed,
                selectId ?? entity.id,
                entity.attributes,
                depth + 1,
                stack,
                hits,
              );
            }
          }
        default:
          break;
      }
    }
  } finally {
    stack.remove(blockName);
  }
}

void _addDimension(
  CadDocument document,
  Map<String, BlockRecord> blocks,
  List<TextSearchHit> hits,
  DimensionEntity entity,
  Mat3 transform,
  int? selectId,
) {
  if (entity.overrideText == ' ') return;
  final label = _dimensionLabel(document, entity);
  final plain = label == null
      ? ''
      : decodeDrawnText(switch (label) {
          TextLike(:final content) => content,
          _ => '',
        });
  final text = plain.trim().isNotEmpty
      ? plain
      : entity.displayTextFor(document.dimStyle(entity.styleName));
  if (text.trim().isEmpty) return;
  final place = label == null
      ? transform
      : _shifted(
          transform.multiplied(entity.blockTransform),
          blocks[entity.blockName]?.basePoint ?? const Vec2.zero(),
        );
  final local = label?.computeBounds() ?? const Bounds2.empty();
  final height = label is TextLike
      ? label.height
      : document.dimStyle(entity.styleName).scaledTextHeight;
  _addNote(
    hits,
    entity: entity,
    kind: TextSearchKind.dimension,
    plain: text,
    height: height,
    local: local,
    anchor: label is TextLike ? label.position : entity.textPosition,
    transform: place,
    selectId: selectId,
  );
}

/// The TEXT or MTEXT in a dimension's `*D` block that paints the number.
CadEntity? _dimensionLabel(CadDocument document, DimensionEntity dim) {
  if (dim.blockName.isEmpty) return null;
  CadEntity? best;
  var bestDist = double.infinity;
  for (final entity in document.entitiesOf(dim.blockName)) {
    final plain = switch (entity) {
      TextEntity(:final content) => decodeDrawnText(content),
      MTextEntity(:final content) => decodeDrawnText(content),
      _ => '',
    };
    if (plain.trim().isEmpty) continue;
    final pos = switch (entity) {
      TextEntity(:final position) => position,
      MTextEntity(:final position) => position,
      _ => dim.textPosition,
    };
    final dist = pos.distanceTo(dim.textPosition);
    if (best == null || dist < bestDist) {
      best = entity;
      bestDist = dist;
    }
  }
  return best;
}

void _addNote(
  List<TextSearchHit> hits, {
  required CadEntity entity,
  required TextSearchKind kind,
  required String plain,
  required double height,
  required Bounds2 local,
  required Vec2 anchor,
  required Mat3 transform,
  required int? selectId,
  String? tag,
}) {
  final text = plain.trim();
  if (text.isEmpty) return;
  final worldHeight = height.abs() * transform.meanScale;
  final worldAnchor = transform.transform(anchor);
  final world = local.isEmpty
      ? const Bounds2.empty()
      : local.transformed(transform);
  final bounds = world.isEmpty || !world.isFinite
      ? _fallbackBox(worldAnchor, worldHeight)
      : world;
  hits.add(
    TextSearchHit(
      selectId: selectId ?? entity.id,
      kind: kind,
      text: text,
      layer: entity.props.layer,
      tag: tag,
      bounds: bounds,
      height: worldHeight > 0 ? worldHeight : height.abs(),
      anchor: bounds.isEmpty ? worldAnchor : bounds.center,
    ),
  );
}

/// Applies a block base-point shift before [transform]. A zero base point
/// leaves [transform] unchanged.
Mat3 _shifted(Mat3 transform, Vec2 basePoint) {
  if (basePoint == const Vec2.zero()) return transform;
  return transform.multiplied(Mat3.translation(-basePoint.x, -basePoint.y));
}

Bounds2 _fallbackBox(Vec2 anchor, double height) {
  final h = height > 0 ? height : 1.0;
  return Bounds2(anchor.x, anchor.y, anchor.x + h, anchor.y + h);
}
