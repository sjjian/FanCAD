import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'plot_helpers.dart';

const _category = 'Output';

class PrintExportPdfCommand extends FanCadCommand {
  const PrintExportPdfCommand();

  @override
  String get id => 'print.exportPdf';
  @override
  String get title => 'Export PDF';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['plotpdf'];
  @override
  String get description =>
      'Plots a layout to a vector PDF. Omit the layout name to plot the '
      'current tab. Paper size becomes the page MediaBox; viewports '
      'are clipped. Pass corner1 and corner2 to plot a window.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Destination .pdf path',
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
    final path = await context.resolveText('path', 'PDF path:');
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
    return writePdf(context, path, layout, window: window.$2);
  }
}
