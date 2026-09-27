import 'dart:io';

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'plot_helpers.dart';

const _category = 'Output';

class PrintExportSvgCommand extends FanCadCommand {
  const PrintExportSvgCommand();

  @override
  String get id => 'print.exportSvg';
  @override
  String get title => 'Export SVG';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['plot'];
  @override
  String get description =>
      'Plots a layout to an SVG file. Omit the layout name to plot the '
      'current tab. A .pdf path writes a vector PDF instead. '
      'Pass corner1 and corner2 to plot a window; otherwise the '
      'layout\'s stored plot window or the full sheet is used.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description:
          'Destination .svg path. Omit it in the app to choose a file.',
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
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final destination = await resolvePlotPath(
      context,
      extension: 'svg',
      typeLabel: 'SVG',
      uniformTypeIdentifiers: const ['public.svg-image'],
    );
    if (destination.stop != null) return destination.stop!;
    final path = destination.path!;
    final layout = plotLayout(context);
    if (layout == null) {
      return CommandResult.failed(
        'No layout named ${context.args.text('layout')}',
      );
    }
    final window = resolvePlotWindow(context, layout);
    if (window.$1 != null) {
      return CommandResult.failed(window.$1!);
    }
    if (path.toLowerCase().endsWith('.pdf')) {
      return writePdf(context, path, layout, window: window.$2);
    }
    final svg = const Plotter().toSvg(
      context.document,
      layout: layout,
      window: window.$2,
      shxFonts: context.services.shxFonts,
    );
    await File(path).writeAsString(svg);
    return CommandResult.ok(
      message: exportedPlotMessage(context, path),
      data: {'path': path, 'bytes': svg.length, 'layout': layout.name},
    );
  }
}
