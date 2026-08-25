import 'package:fancad_core/fancad_core.dart';

import 'skills/skill.dart';

/// What the user is looking at and has picked, rebuilt every turn.
///
/// The statistical drawing summary is not enough: a model that cannot see the
/// current selection will silently operate on leftover ids, and one that cannot
/// see the viewport will query the whole file instead of the window on screen.
class SessionSnapshot {
  const SessionSnapshot({
    this.selectionCount = 0,
    this.selection = const [],
    this.viewport,
    this.snapEnabled = true,
    this.snapModes = const [],
    this.ortho = false,
    this.polar = false,
    this.showGrid = true,
  });

  /// How many selected objects may be listed in the prompt.
  static const int maxListed = 32;

  final int selectionCount;
  final List<SelectedObjectHint> selection;
  final ViewportHint? viewport;
  final bool snapEnabled;
  final List<String> snapModes;
  final bool ortho;
  final bool polar;
  final bool showGrid;

  /// Empty pick is written as `none` so the model cannot treat it as "use
  /// whatever was selected last time".
  String describe() {
    final buffer = StringBuffer();
    buffer.writeln('Session:');
    if (selectionCount == 0) {
      buffer.writeln('- selection: none');
    } else {
      final listed = selection.length;
      buffer.writeln(
        listed < selectionCount
            ? '- selection: $selectionCount objects (first $listed shown)'
            : '- selection: $selectionCount object${selectionCount == 1 ? '' : 's'}',
      );
      for (final item in selection) {
        buffer.writeln('  - ${item.describe()}');
      }
    }
    final view = viewport;
    if (view == null) {
      buffer.writeln('- viewport: unknown');
    } else {
      buffer.writeln('- viewport: ${view.describe()}');
    }
    final modes = snapModes.isEmpty ? 'none' : snapModes.join(', ');
    buffer.writeln(
      '- snap: ${snapEnabled ? 'on' : 'off'} ($modes)',
    );
    buffer.writeln('- ortho: ${ortho ? 'on' : 'off'}');
    buffer.writeln('- polar: ${polar ? 'on' : 'off'}');
    buffer.writeln('- grid: ${showGrid ? 'on' : 'off'}');
    return buffer.toString().trimRight();
  }
}

/// Compact selected-entity row for the prompt. Geometry stays on query tools.
class SelectedObjectHint {
  const SelectedObjectHint({
    required this.id,
    required this.kind,
    required this.layer,
    this.bounds,
  });

  final int id;
  final String kind;
  final String layer;
  final List<double>? bounds;

  String describe() {
    final box = bounds;
    final boxText = box == null || box.length < 4
        ? ''
        : ' bounds=[${box[0].toStringAsFixed(2)},${box[1].toStringAsFixed(2)},'
              '${box[2].toStringAsFixed(2)},${box[3].toStringAsFixed(2)}]';
    return '#$id $kind layer=$layer$boxText';
  }
}

/// Camera of the active tab, as numbers the model can reuse as a query window.
class ViewportHint {
  const ViewportHint({
    required this.centerX,
    required this.centerY,
    required this.scale,
    this.visible,
  });

  final double centerX;
  final double centerY;
  final double scale;
  final List<double>? visible;

  String describe() {
    final box = visible;
    final visibleText = box == null || box.length < 4
        ? 'visible unknown'
        : 'visible [${box[0].toStringAsFixed(2)}, ${box[1].toStringAsFixed(2)}, '
              '${box[2].toStringAsFixed(2)}, ${box[3].toStringAsFixed(2)}]';
    return 'center (${centerX.toStringAsFixed(2)}, ${centerY.toStringAsFixed(2)}), '
        'scale ${scale.toStringAsFixed(4)}, $visibleText';
  }
}

/// Builds the compact document context that goes into a system prompt.
///
/// A drawing with a hundred thousand entities cannot be serialised into a
/// context window. The model is given a statistical summary and a handful of
/// query tools, and it has to ask for the part it cares about. That is a
/// design constraint, not a limitation to paper over later.
class DocumentContextBuilder {
  const DocumentContextBuilder({this.maxLayers = 40, this.maxKinds = 16});

  final int maxLayers;
  final int maxKinds;

  /// A short system preamble: what the assistant is, what it can do, and a
  /// snapshot of the active drawing.
  String systemPrompt({
    required CadDocument document,
    required Iterable<CommandDescriptor> tools,
    String? pluginTypings,
    SessionSnapshot? session,
    Iterable<SkillSummary> skills = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_role);
    buffer.writeln();
    buffer.writeln(summarize(document));
    buffer.writeln();
    buffer.writeln((session ?? const SessionSnapshot()).describe());
    final skillList = skills.toList();
    if (skillList.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Available skills (call read_skill to load one):');
      for (final skill in skillList) {
        buffer.writeln('- ${skill.name}: ${skill.description}');
      }
    }
    buffer.writeln();
    buffer.writeln(_toolAdvice);
    if (pluginTypings != null && pluginTypings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'When writing or repairing a plugin, the `fancad` API is:',
      );
      buffer.writeln(pluginTypings);
    }
    return buffer.toString();
  }

  /// A compact statistical summary. Cheap enough to rebuild every turn.
  String summarize(CadDocument document) {
    final byKind = <String, int>{};
    final byLayer = <String, int>{};
    for (final entity in document.activeEntities) {
      byKind.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
      byLayer.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
    }
    final extents = document.extents;
    final kinds = byKind.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final layers = byLayer.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer();
    buffer.writeln('Active drawing:');
    buffer.writeln('- entities: ${document.entityCount}');
    buffer.writeln('- layout: ${document.activeLayoutName}');
    buffer.writeln('- current layer: ${document.currentLayer}');
    if (extents.isNotEmpty) {
      buffer.writeln(
        '- extents: ${extents.minX.toStringAsFixed(2)}, '
        '${extents.minY.toStringAsFixed(2)} to '
        '${extents.maxX.toStringAsFixed(2)}, '
        '${extents.maxY.toStringAsFixed(2)}',
      );
    }
    if (kinds.isNotEmpty) {
      buffer.writeln(
        '- by type: ${kinds.take(maxKinds).map((e) => '${e.key}×${e.value}').join(', ')}',
      );
    }
    if (layers.isNotEmpty) {
      buffer.writeln(
        '- by layer: ${layers.take(maxLayers).map((e) => '${e.key}×${e.value}').join(', ')}',
      );
    }
    final blocks = [
      for (final block in document.insertableBlocks) block.name,
    ];
    if (blocks.isNotEmpty) {
      buffer.writeln('- blocks: ${blocks.take(20).join(', ')}');
    }
    return buffer.toString();
  }

  /// The same numbers as [summarize], as a structured payload.
  Map<String, Object?> summaryJson(CadDocument document) {
    final byKind = <String, int>{};
    final byLayer = <String, int>{};
    for (final entity in document.activeEntities) {
      byKind.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
      byLayer.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
    }
    final extents = document.extents;
    return {
      'entityCount': document.entityCount,
      'activeLayout': document.activeLayoutName,
      'currentLayer': document.currentLayer,
      'extents': extents.isEmpty
          ? null
          : [extents.minX, extents.minY, extents.maxX, extents.maxY],
      'byKind': byKind,
      'byLayer': byLayer,
    };
  }

  static const String _role =
      'You are FanCAD\'s drafting assistant. You act only through the tools '
      'you have been given, which are the same commands a person can run from '
      'the command line plus host tools such as read_skill. Prefer the session '
      'snapshot, query.summary and query.entities over guessing what is in the '
      'drawing. Never invent entity ids. An empty selection is none — do not '
      'treat it as a hidden target. One user message is one unit of work: '
      'batch related edits so they undo together.';

  static const String _toolAdvice =
      'Read the session snapshot before guessing. When a listed skill matches '
      'the request, call read_skill first and follow it. For the current pick '
      'call query_selection; for the camera call query_viewport; then '
      'query_entities with a layer, kind or window filter. To change the '
      'drawing, call the matching draw_* or edit_* tool and pass ids '
      'explicitly.';
}
