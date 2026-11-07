/// A snapshot of the renderer's retained-scene and cache state.
///
/// This is diagnostic data, not part of a frame's hot path. The canvas asks
/// for it only when a status tooltip or a query needs it.
class RenderDiagnostics {
  const RenderDiagnostics({
    required this.retained,
    required this.sceneBuildTime,
    required this.entityCount,
    required this.segmentCount,
    required this.drawnSegments,
    required this.lineDrawCalls,
    required this.blockCacheHits,
    required this.blockCacheMisses,
    required this.blockCacheEntries,
    required this.blockCacheWeight,
    required this.textAtlasPages,
    required this.textAtlasRuns,
  });

  /// Whether model space currently has a retained world scene.
  final bool retained;

  /// Time spent flattening the retained scene on the CPU.
  final Duration sceneBuildTime;

  final int entityCount;
  final int segmentCount;

  /// Segments submitted by the last paint, after cell culling.
  final int drawnSegments;

  /// Line `drawRawPoints` calls made by the last paint.
  final int lineDrawCalls;

  final int blockCacheHits;
  final int blockCacheMisses;
  final int blockCacheEntries;

  /// Approximate block-cache weight in doubles.
  final int blockCacheWeight;

  final int textAtlasPages;
  final int textAtlasRuns;

  Map<String, Object?> toJson() => {
    'retained': retained,
    'sceneBuildMs': sceneBuildTime.inMicroseconds / 1000,
    'entities': entityCount,
    'segments': segmentCount,
    'drawnSegments': drawnSegments,
    'lineDrawCalls': lineDrawCalls,
    'blockCache': {
      'hits': blockCacheHits,
      'misses': blockCacheMisses,
      'entries': blockCacheEntries,
      'weight': blockCacheWeight,
      'bytes': blockCacheWeight * 8,
    },
    'textAtlas': {'pages': textAtlasPages, 'runs': textAtlasRuns},
  };
}
