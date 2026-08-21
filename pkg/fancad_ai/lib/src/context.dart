import 'package:fancad_core/fancad_core.dart';

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
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_role);
    buffer.writeln();
    buffer.writeln(summarize(document));
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
      'the command line. Prefer query.summary and query.entities over guessing '
      'what is in the drawing. Never invent entity ids. One user message is '
      'one unit of work: batch related edits so they undo together.';

  static const String _toolAdvice =
      'To inspect the drawing, call query_summary first, then query_entities '
      'with a layer, kind or window filter. To change it, call the matching '
      'draw_* or edit_* tool. To write a plugin, call plugins_scaffold, then '
      'plugins_write, then plugins_reload; if activation fails, read the error '
      'and rewrite the file.';
}
