import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'tessellation_cache.dart';

/// Flattens block definitions once and replays them for every insert.
///
/// A block definition is shared by every INSERT that names it. Walking its
/// entities, resolving their styles and laying out their text for each
/// instance is wasted work: the result differs only by the insert transform.
/// This cache stores the flattened primitives in the definition's own
/// coordinates and transforms them again when an instance is replayed.
///
/// The cache deliberately refuses animated cases:
/// - per-instance attribute values;
/// - a camera/query-clipped expansion;
/// - a paper-space clip.
/// Those results depend on more than the block definition and the inherited
/// style, so they keep the existing direct path.
class BlockDisplayCache implements BlockLookup {
  BlockDisplayCache(this.document, {this.maxWeight = 4000000});

  final CadDocument document;

  /// Approximate budget in doubles. One double is 8 bytes.
  final int maxWeight;

  final LinkedHashMap<BlockDisplayKey, List<CachedPrimitive>> _entries =
      LinkedHashMap();
  int _weight = 0;
  int _version = -1;
  int _tableSignature = 0;
  final Map<String, int> _signatures = {};
  final Set<String> _visiting = {};

  int _hits = 0;
  int _misses = 0;

  int get hits => _hits;
  int get misses => _misses;
  int get length => _entries.length;
  int get weight => _weight;

  /// Refreshes the per-build signatures.
  ///
  /// Unrelated entity edits leave a block's signature alone, so its cached
  /// display list survives. A changed block definition or symbol table gets a
  /// new signature and misses on the next lookup; the old entry is left to the
  /// LRU budget instead of clearing every block in the drawing.
  void bind() {
    if (_version == document.version) return;
    _version = document.version;
    _tableSignature = _hashTables();
    _signatures.clear();
    _visiting.clear();
  }

  void clear() {
    _entries.clear();
    _weight = 0;
    _version = -1;
    _tableSignature = 0;
    _signatures.clear();
    _visiting.clear();
  }

  @override
  List<int>? entityIdsOf(String blockName) => document.entityIdsOf(blockName);

  @override
  Bounds2 boundsOf(String blockName) => document.boundsOf(blockName);

  @override
  void emitBlock(String blockName, EmitContext context, GeometrySink sink) {
    bind();
    // Anonymous geometry blocks belong to one dimension or hatch; they are not
    // shared by other instances, so caching them only duplicates the
    // per-entity tessellation cache.
    if (blockName.isEmpty ||
        blockName.startsWith('*') ||
        !_cacheable(blockName, context)) {
      document.emitBlock(blockName, context, sink);
      return;
    }

    final key = BlockDisplayKey(
      blockSignature: _signatureFor(blockName),
      tableSignature: _tableSignature,
      blockName: blockName,
      toleranceBucket: TessellationCache.toleranceBucket(context.tolerance),
      extentBucket: TessellationCache.extentBucket(context.minExtent),
      pixelsKey: (context.pixelsPerUnit * 1000).round(),
      inheritedStyle: context.inheritedStyle,
      pointMode: context.pointDisplay.mode,
      pointSize: context.pointDisplay.size,
      pointFromHeader: context.pointDisplay.fromHeader,
      blockPathHash: Object.hashAllUnordered(context.blockPath),
      blockPathLength: context.blockPath.length,
      scale: context.transform.meanScale,
    );

    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      _hits++;
      _replay(cached, context.transform, sink);
      return;
    }

    _misses++;
    final recorder = RecordingSink();
    final scale = context.transform.meanScale;
    final local = context
        .withTransform(const Mat3.identity())
        .withMinExtent(context.minExtent / scale)
        .withPixelsPerUnit(context.pixelsPerUnit * scale)
        .withQuery(null)
        .withoutClip()
        .withBlocks(this);
    document.emitBlock(blockName, local, recorder);
    _remember(key, recorder.primitives);
    _replay(recorder.primitives, context.transform, sink);
  }

  int _hashTables() => Object.hash(
    Object.hashAll([
      for (final entry in document.layers.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAll([
      for (final entry in document.textStyles.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAll([
      for (final entry in document.lineTypes.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAll([
      for (final entry in document.dimStyles.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  /// A cheap identity of the block definition and everything it references.
  ///
  /// Entities are immutable values: editing one replaces it in the map, so its
  /// identity changes. Nested inserts contribute the signature of their own
  /// definition, which makes a change deep inside a tree invalidate every
  /// cached ancestor that contains it.
  int _signatureFor(String blockName) {
    final cached = _signatures[blockName];
    if (cached != null) return cached;
    if (!_visiting.add(blockName)) return 0;
    final block = document.blocks[blockName];
    if (block == null) {
      _visiting.remove(blockName);
      return 0;
    }
    var hash = 17;
    hash = 31 * hash + Object.hashAll(block.entityIds);
    hash = 31 * hash + Object.hash(block.basePoint.x, block.basePoint.y);
    hash = 31 * hash + block.xrefPath.hashCode;
    for (final id in block.entityIds) {
      final entity = document.entityMap[id];
      if (entity == null) continue;
      hash = 31 * hash + identityHashCode(entity);
      if (entity is InsertEntity) {
        hash = 31 * hash + _signatureFor(entity.blockName);
      }
    }
    _visiting.remove(blockName);
    _signatures[blockName] = hash;
    return hash;
  }

  bool _cacheable(String blockName, EmitContext context) {
    final attributes = context.attributeValues;
    if (attributes != null && attributes.isNotEmpty) return false;
    final transform = context.transform;
    final scale = transform.meanScale;
    if (!scale.isFinite || scale <= 0) return false;
    if (!transform.isConformal || transform.determinant <= 0) return false;
    final quarter = math.pi / 2;
    final turns = transform.rotation / quarter;
    if ((turns - turns.round()).abs() > 1e-6) return false;
    final local = document.boundsOf(blockName);
    if (local.isEmpty || !local.isFinite) return false;
    final world = context.transform.isIdentity
        ? local
        : local.transformed(context.transform);
    for (final box in [context.query, context.clip]) {
      if (box != null && !box.containsBox(world)) return false;
    }
    return true;
  }

  void _remember(BlockDisplayKey key, List<CachedPrimitive> primitives) {
    var weight = 0;
    for (final primitive in primitives) {
      weight += primitive.weight;
    }
    if (weight <= 0 || weight > maxWeight) return;
    _entries[key] = primitives;
    _weight += weight;
    while (_weight > maxWeight && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      final removed = _entries.remove(oldest);
      if (removed == null) continue;
      for (final primitive in removed) {
        _weight -= primitive.weight;
      }
    }
  }

  void _replay(
    List<CachedPrimitive> primitives,
    Mat3 transform,
    GeometrySink sink,
  ) {
    if (transform.isIdentity) {
      replayCachedPrimitives(sink, primitives);
      return;
    }
    for (final primitive in primitives) {
      switch (primitive.kind) {
        case PrimitiveKind.polyline:
          sink.polyline(
            _transformBuffer(transform, primitive.xy),
            primitive.style,
            closed: primitive.closed,
          );
        case PrimitiveKind.fill:
          sink.fill(
            _transformBuffer(transform, primitive.xy),
            primitive.style,
            holes: [
              for (final hole in primitive.holes)
                _transformBuffer(transform, hole),
            ],
          );
        case PrimitiveKind.point:
          final point = transform.transform(
            Vec2(primitive.xy[0], primitive.xy[1]),
          );
          sink.point(point.x, point.y, primitive.style);
        case PrimitiveKind.text:
          sink.text(
            _transformText(primitive.text!, transform),
            primitive.style,
          );
        case PrimitiveKind.image:
          sink.image(
            _transformImage(primitive.image!, transform),
            primitive.style,
          );
      }
    }
  }

  static Float64List _transformBuffer(Mat3 transform, Float64List xy) {
    final out = Float64List(xy.length);
    for (var i = 0; i + 1 < xy.length; i += 2) {
      final p = transform.transform(Vec2(xy[i], xy[i + 1]));
      out[i] = p.x;
      out[i + 1] = p.y;
    }
    return out;
  }

  static TextGeometry _transformText(TextGeometry text, Mat3 transform) =>
      TextGeometry(
        text: text.text,
        origin: transform.transform(text.origin),
        height: text.height * transform.meanScale,
        rotation: transform.transformAngle(text.rotation),
        styleName: text.styleName,
        fontFamily: text.fontFamily,
        bigFontFamily: text.bigFontFamily,
        widthFactor: text.widthFactor,
        obliqueAngle: text.obliqueAngle,
        tracking: text.tracking,
        hAlign: text.hAlign,
        vAlign: text.vAlign,
        anchor: text.anchor,
        backwards: text.backwards,
        upsideDown: text.upsideDown,
        underline: text.underline,
        overline: text.overline,
        strike: text.strike,
        rectangleWidth: text.rectangleWidth,
        isMultiline: text.isMultiline,
      );

  static ImageGeometry _transformImage(ImageGeometry image, Mat3 transform) =>
      ImageGeometry(
        reference: image.reference,
        origin: transform.transform(image.origin),
        uVector: transform.transformDirection(image.uVector),
        vVector: transform.transformDirection(image.vVector),
        brightness: image.brightness,
        contrast: image.contrast,
        fade: image.fade,
      );
}

class BlockDisplayKey {
  const BlockDisplayKey({
    required this.blockSignature,
    required this.tableSignature,
    required this.blockName,
    required this.toleranceBucket,
    required this.extentBucket,
    required this.pixelsKey,
    required this.inheritedStyle,
    required this.pointMode,
    required this.pointSize,
    required this.pointFromHeader,
    required this.blockPathHash,
    required this.blockPathLength,
    required this.scale,
  });

  final int blockSignature;
  final int tableSignature;
  final String blockName;
  final int toleranceBucket;
  final int extentBucket;
  final int pixelsKey;
  final ResolvedStyle inheritedStyle;
  final int pointMode;
  final double pointSize;
  final bool pointFromHeader;
  final int blockPathHash;
  final int blockPathLength;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is BlockDisplayKey &&
      other.blockSignature == blockSignature &&
      other.tableSignature == tableSignature &&
      other.blockName == blockName &&
      other.toleranceBucket == toleranceBucket &&
      other.extentBucket == extentBucket &&
      other.pixelsKey == pixelsKey &&
      other.inheritedStyle == inheritedStyle &&
      other.pointMode == pointMode &&
      other.pointSize == pointSize &&
      other.pointFromHeader == pointFromHeader &&
      other.blockPathHash == blockPathHash &&
      other.blockPathLength == blockPathLength &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    blockSignature,
    tableSignature,
    blockName,
    toleranceBucket,
    extentBucket,
    pixelsKey,
    inheritedStyle,
    pointMode,
    pointSize,
    pointFromHeader,
    blockPathHash,
    blockPathLength,
    scale,
  );
}
