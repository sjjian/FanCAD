import 'package:fancad_core/fancad_core.dart';

/// A comparison of two drawings, used as a save-round-trip audit.
///
/// The numbers that matter are the ones a user can see: did anything
/// disappear, did extents jump, did a layer vanish. A perfect byte match is
/// not the goal — DWG and DXF will never be byte-identical to the original —
/// but a missing entity is a bug, not a rounding error.
class FidelityReport {
  const FidelityReport({
    required this.sourceEntities,
    required this.targetEntities,
    required this.missingByKind,
    required this.extraByKind,
    required this.sourceExtents,
    required this.targetExtents,
    required this.missingLayers,
    this.notes = const [],
  });

  final int sourceEntities;
  final int targetEntities;
  final Map<String, int> missingByKind;
  final Map<String, int> extraByKind;
  final Bounds2 sourceExtents;
  final Bounds2 targetExtents;
  final List<String> missingLayers;
  final List<String> notes;

  bool get isClean =>
      missingByKind.isEmpty && extraByKind.isEmpty && missingLayers.isEmpty;

  String get summary {
    if (isClean) {
      return 'Round trip kept all $sourceEntities entities.';
    }
    final parts = <String>[];
    if (missingByKind.isNotEmpty) {
      parts.add(
        'lost ${missingByKind.entries.map((e) => '${e.value} ${e.key}').join(', ')}',
      );
    }
    if (extraByKind.isNotEmpty) {
      parts.add(
        'gained ${extraByKind.entries.map((e) => '${e.value} ${e.key}').join(', ')}',
      );
    }
    if (missingLayers.isNotEmpty) {
      parts.add('missing layers ${missingLayers.join(', ')}');
    }
    return parts.join('; ');
  }

  Map<String, Object?> toJson() => {
    'sourceEntities': sourceEntities,
    'targetEntities': targetEntities,
    'missingByKind': missingByKind,
    'extraByKind': extraByKind,
    'missingLayers': missingLayers,
    'clean': isClean,
    'summary': summary,
    if (notes.isNotEmpty) 'notes': notes,
  };
}

/// Builds a [FidelityReport] from two documents.
class FidelityAuditor {
  const FidelityAuditor();

  FidelityReport compare(CadDocument source, CadDocument target) {
    final sourceKinds = _counts(source);
    final targetKinds = _counts(target);
    final kinds = {...sourceKinds.keys, ...targetKinds.keys};
    final missing = <String, int>{};
    final extra = <String, int>{};
    for (final kind in kinds) {
      final delta = (targetKinds[kind] ?? 0) - (sourceKinds[kind] ?? 0);
      if (delta < 0) missing[kind] = -delta;
      if (delta > 0) extra[kind] = delta;
    }
    final missingLayers = [
      for (final name in source.layers.keys)
        if (!target.layers.containsKey(name)) name,
    ];
    return FidelityReport(
      sourceEntities: source.entityCount,
      targetEntities: target.entityCount,
      missingByKind: missing,
      extraByKind: extra,
      sourceExtents: source.extents,
      targetExtents: target.extents,
      missingLayers: missingLayers,
    );
  }

  static Map<String, int> _counts(CadDocument document) {
    final counts = <String, int>{};
    for (final entity in document.entities) {
      counts.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
