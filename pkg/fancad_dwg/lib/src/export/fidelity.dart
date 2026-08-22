import 'package:fancad_core/fancad_core.dart';

/// A comparison of two drawings, used as a save-round-trip audit.
///
/// The numbers that matter are the ones a user can see: did anything
/// disappear, did a sheet vanish, did a layer drop. A perfect byte match is
/// not the goal — DWG and DXF will never be byte-identical to the original —
/// but a missing entity or a missing paper tab is a bug, not a rounding error.
class FidelityReport {
  const FidelityReport({
    required this.sourceEntities,
    required this.targetEntities,
    required this.missingByKind,
    required this.extraByKind,
    required this.sourceExtents,
    required this.targetExtents,
    required this.missingLayers,
    this.missingBySpace = const {},
    this.extraBySpace = const {},
    this.missingLayouts = const [],
    this.extraLayouts = const [],
    this.layoutMismatches = const [],
    this.missingXrefs = const [],
    this.extraXrefs = const [],
    this.xrefMismatches = const [],
    this.notes = const [],
  });

  final int sourceEntities;
  final int targetEntities;
  final Map<String, int> missingByKind;
  final Map<String, int> extraByKind;
  final Bounds2 sourceExtents;
  final Bounds2 targetExtents;
  final List<String> missingLayers;

  /// Entity-count deltas keyed by layout block (`*Model_Space`, `*Paper_Space`).
  final Map<String, int> missingBySpace;
  final Map<String, int> extraBySpace;

  final List<String> missingLayouts;
  final List<String> extraLayouts;

  /// Named tabs that survived but changed paper size or viewports.
  final List<String> layoutMismatches;

  /// External-reference blocks that disappeared, appeared, or changed path.
  final List<String> missingXrefs;
  final List<String> extraXrefs;
  final List<String> xrefMismatches;
  final List<String> notes;

  bool get isClean =>
      missingByKind.isEmpty &&
      extraByKind.isEmpty &&
      missingLayers.isEmpty &&
      missingBySpace.isEmpty &&
      extraBySpace.isEmpty &&
      missingLayouts.isEmpty &&
      extraLayouts.isEmpty &&
      layoutMismatches.isEmpty &&
      missingXrefs.isEmpty &&
      extraXrefs.isEmpty &&
      xrefMismatches.isEmpty;

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
    if (missingBySpace.isNotEmpty) {
      parts.add(
        'lost ${missingBySpace.entries.map((e) => '${e.value} on ${e.key}').join(', ')}',
      );
    }
    if (extraBySpace.isNotEmpty) {
      parts.add(
        'gained ${extraBySpace.entries.map((e) => '${e.value} on ${e.key}').join(', ')}',
      );
    }
    if (missingLayers.isNotEmpty) {
      parts.add('missing layers ${missingLayers.join(', ')}');
    }
    if (missingLayouts.isNotEmpty) {
      parts.add('missing layouts ${missingLayouts.join(', ')}');
    }
    if (extraLayouts.isNotEmpty) {
      parts.add('extra layouts ${extraLayouts.join(', ')}');
    }
    if (layoutMismatches.isNotEmpty) {
      parts.add(layoutMismatches.join('; '));
    }
    if (missingXrefs.isNotEmpty) {
      parts.add('missing xrefs ${missingXrefs.join(', ')}');
    }
    if (extraXrefs.isNotEmpty) {
      parts.add('extra xrefs ${extraXrefs.join(', ')}');
    }
    if (xrefMismatches.isNotEmpty) {
      parts.add(xrefMismatches.join('; '));
    }
    return parts.join('; ');
  }

  Map<String, Object?> toJson() => {
    'sourceEntities': sourceEntities,
    'targetEntities': targetEntities,
    'missingByKind': missingByKind,
    'extraByKind': extraByKind,
    'missingLayers': missingLayers,
    'missingBySpace': missingBySpace,
    'extraBySpace': extraBySpace,
    'missingLayouts': missingLayouts,
    'extraLayouts': extraLayouts,
    'layoutMismatches': layoutMismatches,
    'missingXrefs': missingXrefs,
    'extraXrefs': extraXrefs,
    'xrefMismatches': xrefMismatches,
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

    final sourceSpaces = _spaceCounts(source);
    final targetSpaces = _spaceCounts(target);
    final missingBySpace = <String, int>{};
    final extraBySpace = <String, int>{};
    for (final name in {...sourceSpaces.keys, ...targetSpaces.keys}) {
      final delta = (targetSpaces[name] ?? 0) - (sourceSpaces[name] ?? 0);
      if (delta < 0) missingBySpace[name] = -delta;
      if (delta > 0) extraBySpace[name] = delta;
    }

    final sourceNames = {for (final layout in source.layouts) layout.name};
    final targetNames = {for (final layout in target.layouts) layout.name};
    final missingLayouts = [
      for (final name in sourceNames)
        if (!targetNames.contains(name)) name,
    ];
    final extraLayouts = [
      for (final name in targetNames)
        if (!sourceNames.contains(name)) name,
    ];
    final layoutMismatches = <String>[];
    for (final sourceLayout in source.layouts) {
      Layout? match;
      for (final item in target.layouts) {
        if (item.name == sourceLayout.name) {
          match = item;
          break;
        }
      }
      if (match == null) continue;
      final diff = _layoutDiff(sourceLayout, match);
      if (diff != null) layoutMismatches.add(diff);
    }

    final sourceXrefs = _xrefs(source);
    final targetXrefs = _xrefs(target);
    final missingXrefs = [
      for (final key in sourceXrefs.keys)
        if (!targetXrefs.containsKey(key)) sourceXrefs[key]!.name,
    ];
    final extraXrefs = [
      for (final key in targetXrefs.keys)
        if (!sourceXrefs.containsKey(key)) targetXrefs[key]!.name,
    ];
    final xrefMismatches = <String>[];
    for (final key in sourceXrefs.keys) {
      final other = targetXrefs[key];
      if (other == null) continue;
      final path = sourceXrefs[key]!.xrefPath;
      if (path != other.xrefPath) {
        xrefMismatches.add(
          '${sourceXrefs[key]!.name}: $path vs ${other.xrefPath}',
        );
      }
    }

    return FidelityReport(
      sourceEntities: source.entityCount,
      targetEntities: target.entityCount,
      missingByKind: missing,
      extraByKind: extra,
      sourceExtents: source.extents,
      targetExtents: target.extents,
      missingLayers: missingLayers,
      missingBySpace: missingBySpace,
      extraBySpace: extraBySpace,
      missingLayouts: missingLayouts,
      extraLayouts: extraLayouts,
      layoutMismatches: layoutMismatches,
      missingXrefs: missingXrefs,
      extraXrefs: extraXrefs,
      xrefMismatches: xrefMismatches,
    );
  }

  static Map<String, BlockRecord> _xrefs(CadDocument document) {
    final result = <String, BlockRecord>{};
    for (final block in document.blocks.values) {
      if (block.isXref) result[block.name.toUpperCase()] = block;
    }
    return result;
  }

  static Map<String, int> _counts(CadDocument document) {
    final counts = <String, int>{};
    for (final entity in document.entities) {
      counts.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static Map<String, int> _spaceCounts(CadDocument document) {
    final counts = <String, int>{};
    final seen = <String>{};
    for (final layout in document.layouts) {
      if (!seen.add(layout.blockName)) continue;
      counts[layout.blockName] = document.entitiesOf(layout.blockName).length;
    }
    return counts;
  }

  static String? _layoutDiff(Layout source, Layout target) {
    final issues = <String>[];
    if ((source.paperWidth - target.paperWidth).abs() > 1e-4 ||
        (source.paperHeight - target.paperHeight).abs() > 1e-4) {
      issues.add(
        'paper ${source.paperWidth}×${source.paperHeight} vs '
        '${target.paperWidth}×${target.paperHeight}',
      );
    }
    if (source.viewports.length != target.viewports.length) {
      issues.add(
        '${source.viewports.length} viewport(s) vs ${target.viewports.length}',
      );
    } else {
      for (var i = 0; i < source.viewports.length; i++) {
        if (!_sameViewport(source.viewports[i], target.viewports[i])) {
          issues.add('viewport ${i + 1} changed');
        }
      }
    }
    if (issues.isEmpty) return null;
    return '${source.name}: ${issues.join(', ')}';
  }

  static bool _sameViewport(PaperViewport a, PaperViewport b) {
    bool close(double x, double y) => (x - y).abs() <= 1e-6;
    final pa = a.paperBounds;
    final pb = b.paperBounds;
    return close(pa.minX, pb.minX) &&
        close(pa.minY, pb.minY) &&
        close(pa.maxX, pb.maxX) &&
        close(pa.maxY, pb.maxY) &&
        close(a.modelCenter.x, b.modelCenter.x) &&
        close(a.modelCenter.y, b.modelCenter.y) &&
        close(a.scale, b.scale) &&
        close(a.rotation, b.rotation) &&
        a.locked == b.locked &&
        a.isOn == b.isOn &&
        _sameFrozen(a.frozenLayers, b.frozenLayers);
  }

  static bool _sameFrozen(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final left = {for (final name in a) name.toLowerCase()};
    final right = {for (final name in b) name.toLowerCase()};
    return left.length == right.length && left.containsAll(right);
  }
}
