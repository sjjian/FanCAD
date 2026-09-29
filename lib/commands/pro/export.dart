import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../models/workspace.dart';
import '../command_base.dart';
import '../file/dialog.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class PrintExportCommand extends FanCadCommand {
  const PrintExportCommand();

  @override
  String get id => 'print.export';
  @override
  String get title => 'Export';
  @override
  String get category => _category;
  @override
  String get description =>
      'Opens the export pane. Pass path to write the file now. '
      'Optional format (svg, pdf, png, jpg), scope (extents, view, window, or selection), '
      'and layers. The file extension picks the format when format is omitted. '
      'corner1 and corner2 set a one-shot window and override scope.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description:
          'Destination path. Omit it in the app to open the export pane.',
      required: false,
    ),
    ParamSpec(
      name: 'layout',
      type: ParamType.text,
      description: 'Tab to plot. Defaults to the current layout.',
      required: false,
    ),
    ParamSpec(
      name: 'corner1',
      type: ParamType.point,
      description: 'First corner of a one-shot plot window',
      required: false,
    ),
    ParamSpec(
      name: 'corner2',
      type: ParamType.point,
      description: 'Opposite corner of a one-shot plot window',
      required: false,
    ),
    ...plotFilterParams,
  ];

  @override
  Future<CommandResult> run(CommandContext context) => runExport(context);
}

Layout? plotLayout(CommandContext context) {
  final requested = context.args.text('layout')?.trim() ?? '';
  if (requested.isEmpty) return context.document.activeLayout;
  return layoutNamed(context.document, requested);
}

(String?, Bounds2?) resolvePlotWindow(CommandContext context, Layout layout) {
  final first = context.args.point('corner1');
  final second = context.args.point('corner2');
  if (first == null && second == null) return (null, layout.plotWindow);
  if (first == null || second == null) {
    return ('Plot window needs both corners.', null);
  }
  final box = Bounds2.fromCorners(first, second);
  if (box.width <= 1e-9 || box.height <= 1e-9) {
    return ('Plot window must have a positive size.', null);
  }
  return (null, box);
}

/// Drawing title with [extension], stripping a known drawing suffix first.
String plotSuggestedName(String title, String extension) {
  var stem = title.trim();
  if (stem.isEmpty) stem = 'Drawing';
  final lower = stem.toLowerCase();
  for (final known in ['dwg', 'dxf', 'fcb', 'svg', 'pdf']) {
    final suffix = '.$known';
    if (lower.endsWith(suffix)) {
      stem = stem.substring(0, stem.length - suffix.length);
      break;
    }
  }
  return '$stem.$extension';
}

/// A scripted [path] is used as-is. An interactive run with no path opens the
/// save dialog. A headless run with no path stops the command.
Future<({String? path, CommandResult? stop})> resolvePlotPath(
  CommandContext context, {
  required String extension,
  required String typeLabel,
  required List<String> uniformTypeIdentifiers,
}) async {
  final given = context.args.text('path')?.trim() ?? '';
  if (given.isNotEmpty) return (path: given, stop: null);
  if (!context.input.isInteractive) {
    return (
      path: null,
      stop: const CommandResult.failed('A destination path is required.'),
    );
  }
  try {
    final chosen = await saveFileDialog(
      suggestedName: plotSuggestedName(context.session.title, extension),
      extensions: [extension],
      typeLabel: typeLabel,
      uniformTypeIdentifiers: uniformTypeIdentifiers,
    );
    if (chosen == null) {
      return (path: null, stop: const CommandResult.cancelled());
    }
    return (path: chosen, stop: null);
  } catch (error) {
    return (
      path: null,
      stop: CommandResult.failed('The file dialog failed: $error'),
    );
  }
}

String exportedPlotMessage(CommandContext context, String path) =>
    context.l10n.exported_file(p.basename(path));

/// Optional filters shared by every export command.
const List<ParamSpec> plotFilterParams = [
  ParamSpec(
    name: 'format',
    type: ParamType.choice,
    description:
        'svg, pdf, png, or jpg. When omitted, a path uses its extension, '
        'otherwise svg. Opening the pane keeps the drawing\'s last choice.',
    required: false,
    options: ['svg', 'pdf', 'png', 'jpg'],
  ),
  ParamSpec(
    name: 'scope',
    type: ParamType.choice,
    description:
        'extents, view, window, or selection. corner1 and corner2 override this. '
        'view is the area visible between the side panes. '
        'window uses corner1 and corner2, or the full drawing when they are omitted. '
        'Selection does not change the layout plot window.',
    required: false,
    options: ['extents', 'view', 'window', 'selection'],
  ),
  ParamSpec(
    name: 'layers',
    type: ParamType.text,
    description:
        'Layer names to include, comma-separated or a list. '
        'Omit to plot every printable layer.',
    required: false,
  ),
];

/// Names from a list or a comma-separated string. Null when the argument
/// was omitted, which means every printable layer.
Set<String>? exportLayerFilter(CommandArgs args) {
  if (!args.has('layers')) return null;
  final value = args['layers'];
  if (value is List) {
    return {
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    };
  }
  final text = args.text('layers')?.trim() ?? '';
  if (text.isEmpty) return {};
  return text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
}

Set<String> defaultPlotLayers(CadDocument document) {
  final names = <String>{
    for (final layer in document.layers.values)
      if (document.isLayerPlottable(layer.name)) layer.name,
  };
  for (final entity in document.entities) {
    final layer = entity.props.layer;
    if (document.isLayerPlottable(layer)) names.add(layer);
  }
  return names;
}

/// Interactive runs with no path open the export pane. A path writes now.
Future<CommandResult> runExport(CommandContext context) async {
  final given = context.args.text('path')?.trim() ?? '';
  if (given.isEmpty) {
    if (!context.input.isInteractive) {
      return const CommandResult.failed('A destination path is required.');
    }
    final requestedFormat = context.args.text('format')?.trim() ?? '';
    final requestedScope = context.args.text('scope')?.trim() ?? '';
    context.services.openExport(
      format: requestedFormat.isEmpty ? null : requestedFormat,
      scope: requestedScope.isEmpty ? null : requestedScope,
    );
    return const CommandResult.ok();
  }

  final format = _exportFormat(context, given);
  if (format == null) {
    return const CommandResult.failed('Unknown export format.');
  }
  final layout = plotLayout(context);
  if (layout == null) {
    return CommandResult.failed(
      'No layout named ${context.args.text('layout')}',
    );
  }
  final window = _exportWindow(context, layout);
  if (window.$1 != null) return CommandResult.failed(window.$1!);
  return writePlot(
    context,
    given,
    layout,
    window: window.$2,
    layers: exportLayerFilter(context.args),
    format: format,
  );
}

String? _exportFormat(CommandContext context, String path) {
  final requested = context.args.text('format')?.trim() ?? '';
  if (requested.isNotEmpty) {
    return ExportFormat.tryParse(requested)?.extension;
  }
  final ext = p.extension(path);
  final fromName = ext.startsWith('.') ? ext.substring(1) : ext;
  return ExportFormat.tryParse(fromName)?.extension ?? 'svg';
}

(String?, Bounds2?) _exportWindow(CommandContext context, Layout layout) {
  final hasCorners =
      context.args.point('corner1') != null ||
      context.args.point('corner2') != null;
  if (hasCorners) return resolvePlotWindow(context, layout);
  final requested = context.args.text('scope')?.trim() ?? '';
  if (requested.isEmpty) return (null, null);
  final scope = ExportScope.tryParse(requested);
  if (scope == null) return ('Unknown export scope.', null);
  return switch (scope) {
    ExportScope.extents || ExportScope.window => (null, null),
    ExportScope.view => _visiblePlotWindow(context),
    ExportScope.selection => _selectionPlotWindow(context),
  };
}

(String?, Bounds2?) _visiblePlotWindow(CommandContext context) {
  final visible = context.services.describeView()['visible'];
  if (visible is! List || visible.length < 4) {
    return ('A visible window is not available.', null);
  }
  final coords = <double>[];
  for (final item in visible.take(4)) {
    if (item is! num) return ('A visible window is not available.', null);
    coords.add(item.toDouble());
  }
  final box = Bounds2(coords[0], coords[1], coords[2], coords[3]);
  if (box.width <= 1e-9 || box.height <= 1e-9) {
    return ('A visible window is not available.', null);
  }
  return (null, box);
}

(String?, Bounds2?) _selectionPlotWindow(CommandContext context) {
  final box = selectionPlotWindow(
    context.document,
    context.session.selection.ids,
  );
  if (box == null) return ('Nothing is selected.', null);
  return (null, box);
}

Future<CommandResult> writePlot(
  CommandContext context,
  String path,
  Layout layout, {
  Bounds2? window,
  Set<String>? layers,
  required String format,
}) async {
  final document = context.document;
  switch (format) {
    case 'svg':
      final svg = const Plotter().toSvg(
        document,
        layout: layout,
        window: window,
        layers: layers,
        shxFonts: context.services.shxFonts,
      );
      await File(path).writeAsString(svg);
      return CommandResult.ok(
        message: exportedPlotMessage(context, path),
        data: {'path': path, 'bytes': svg.length, 'layout': layout.name},
      );
    case 'pdf':
      final pdf = const Plotter().toPdf(
        document,
        layout: layout,
        window: window,
        layers: layers,
        shxFonts: context.services.shxFonts,
      );
      await File(path).writeAsBytes(pdf);
      return CommandResult.ok(
        message: exportedPlotMessage(context, path),
        data: {'path': path, 'bytes': pdf.length, 'layout': layout.name},
      );
    case 'png':
    case 'jpg':
      final frame = Plotter.frame(document, layout: layout, window: window);
      final png = await renderPlotPng(
        document: document,
        frame: frame,
        layers: layers ?? defaultPlotLayers(document),
        shxFonts: context.services.shxFonts,
      );
      final bytes = format == 'jpg' ? _encodeJpg(png) : png;
      await File(path).writeAsBytes(bytes);
      return CommandResult.ok(
        message: exportedPlotMessage(context, path),
        data: {'path': path, 'bytes': bytes.length, 'layout': layout.name},
      );
    default:
      return const CommandResult.failed('Unknown export format.');
  }
}

Uint8List _encodeJpg(Uint8List png) {
  final decoded = img.decodePng(png);
  if (decoded == null) {
    throw StateError('The plot image could not be encoded.');
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
}
