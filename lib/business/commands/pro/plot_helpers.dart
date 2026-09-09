import 'dart:io';

import 'package:fancad_core/fancad_core.dart';

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
  );
  await File(path).writeAsBytes(pdf);
  return CommandResult.ok(
    message: 'Wrote ${pdf.length} bytes to $path',
    data: {'path': path, 'bytes': pdf.length, 'layout': layout.name},
  );
}
