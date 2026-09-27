import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

import '../../l10n/l10n.dart';
import '../file/dialog.dart';
import 'layout_helpers.dart';

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

Future<CommandResult> writePdf(
  CommandContext context,
  String path,
  Layout layout, {
  Bounds2? window,
}) async {
  final pdf = const Plotter().toPdf(
    context.document,
    layout: layout,
    window: window,
    shxFonts: context.services.shxFonts,
  );
  await File(path).writeAsBytes(pdf);
  return CommandResult.ok(
    message: exportedPlotMessage(context, path),
    data: {'path': path, 'bytes': pdf.length, 'layout': layout.name},
  );
}
