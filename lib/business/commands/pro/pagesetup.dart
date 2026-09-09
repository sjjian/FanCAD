import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class LayoutPagesetupCommand extends FanCadCommand {
  const LayoutPagesetupCommand();

  @override
  String get id => 'layout.pagesetup';
  @override
  String get title => 'Page Setup';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pagesetup'];
  @override
  String get description =>
      'Changes the paper size of a layout, in millimetres, the plot '
      'rotation (0, 90, 180 or 270), scale or fit-to-sheet, an offset, '
      'and an optional plot window. Omit the name to edit the current '
      'paper tab. Model has no sheet.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Layout to resize. Defaults to the current paper tab.',
      required: false,
    ),
    ParamSpec(
      name: 'width',
      type: ParamType.distance,
      description: 'Sheet width in millimetres',
    ),
    ParamSpec(
      name: 'height',
      type: ParamType.distance,
      description: 'Sheet height in millimetres',
    ),
    ParamSpec(
      name: 'rotation',
      type: ParamType.angle,
      description: 'Plot rotation in degrees: 0, 90, 180 or 270',
      required: false,
    ),
    ParamSpec(
      name: 'corner1',
      type: ParamType.point,
      description: 'First corner of the plot window',
      required: false,
    ),
    ParamSpec(
      name: 'corner2',
      type: ParamType.point,
      description: 'Opposite corner of the plot window',
      required: false,
    ),
    ParamSpec(
      name: 'window',
      type: ParamType.boolean,
      description: 'false clears a stored plot window',
      required: false,
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Plot scale. 1 is 1:1. Ignored when fit is true.',
      required: false,
    ),
    ParamSpec(
      name: 'fit',
      type: ParamType.boolean,
      description: 'Scale the window or extents to fill the sheet',
      required: false,
    ),
    ParamSpec(
      name: 'offset',
      type: ParamType.point,
      description: 'Plot origin on the sheet, in millimetres',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var requested = context.args.text('name')?.trim() ?? '';
    if (requested.isEmpty) {
      if (context.document.activeLayout.isModelSpace) {
        requested = await context.resolveText('name', 'Layout name:');
      } else {
        requested = context.document.activeLayoutName;
      }
    }
    final layout = layoutNamed(context.document, requested);
    if (layout == null) {
      return CommandResult.failed('No layout named $requested');
    }
    if (layout.isModelSpace) {
      return const CommandResult.failed('Model has no paper size.');
    }

    final width = await context.resolveNumber(
      'width',
      'Sheet width (mm):',
      defaultValue: layout.paperWidth,
    );
    final height = await context.resolveNumber(
      'height',
      'Sheet height (mm):',
      defaultValue: layout.paperHeight,
    );
    if (width <= 0 || height <= 0) {
      return const CommandResult.failed('The sheet needs a positive size.');
    }
    final rotationArg =
        context.args.number('rotation') ?? context.args.integer('rotation');
    final rotation = rotationArg == null
        ? layout.plotRotation
        : Layout.normalizePlotRotation(rotationArg);
    final windowChange = _pageSetupWindow(context, layout);
    if (windowChange.$1 != null) {
      return CommandResult.failed(windowChange.$1!);
    }
    final nextWindow = windowChange.$2;
    final clearWindow = context.args.boolean('window') == false;
    final fit = context.args.boolean('fit') ?? layout.plotFit;
    final scale = context.args.number('scale') ?? layout.plotScale;
    if (!fit && scale <= 0) {
      return const CommandResult.failed('Plot scale must be positive.');
    }
    final offset = context.args.point('offset');
    final offsetX = offset?.x ?? layout.plotOffsetX;
    final offsetY = offset?.y ?? layout.plotOffsetY;
    if (width == layout.paperWidth &&
        height == layout.paperHeight &&
        rotation == layout.plotRotation &&
        _samePlotBox(nextWindow, layout.plotWindow) &&
        fit == layout.plotFit &&
        (scale - layout.plotScale).abs() < 1e-12 &&
        (offsetX - layout.plotOffsetX).abs() < 1e-12 &&
        (offsetY - layout.plotOffsetY).abs() < 1e-12) {
      return CommandResult.ok(
        message:
            '${layout.name} is already $width × $height mm'
            '${rotation == 0 ? '' : ', rotated $rotation°'}.',
        data: {
          'name': layout.name,
          'paper': [width, height],
          'rotation': rotation,
        },
      );
    }

    var updated = layout.copyWith(
      paperWidth: width,
      paperHeight: height,
      plotRotation: rotation,
      plotScale: scale,
      plotFit: fit,
      plotOffsetX: offsetX,
      plotOffsetY: offsetY,
    );
    if (clearWindow) {
      updated = updated.copyWith(plotWindow: null);
    } else if (nextWindow != null) {
      updated = updated.copyWith(plotWindow: nextWindow);
    }
    final committed = context.edit('Page Setup', (transaction) {
      transaction.putLayout(updated);
      if (context.document.activeLayoutName != layout.name) {
        transaction.setActiveLayout(layout.name);
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The sheet size was not changed.');
    }
    context.services.invalidate();
    context.services.zoomTo(null);
    return CommandResult(
      status: CommandStatus.ok,
      message:
          '${layout.name} is now $width × $height mm'
          '${rotation == 0 ? '' : ', plot $rotation°'}'
          '${fit ? ', fit' : (scale == 1 ? '' : ', scale $scale')}.',
      data: {
        'name': layout.name,
        'paper': [width, height],
        'rotation': rotation,
        'scale': updated.plotScale,
        'fit': updated.plotFit,
        'offset': [updated.plotOffsetX, updated.plotOffsetY],
        if (updated.plotWindow case final box?)
          'plotWindow': [box.minX, box.minY, box.maxX, box.maxY],
      },
      transaction: committed,
    );
  }
}

(String?, Bounds2?) _pageSetupWindow(CommandContext context, Layout layout) {
  if (context.args.boolean('window') == false) {
    return (null, null);
  }
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

bool _samePlotBox(Bounds2? a, Bounds2? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return (a.minX - b.minX).abs() <= 1e-9 &&
      (a.minY - b.minY).abs() <= 1e-9 &&
      (a.maxX - b.maxX).abs() <= 1e-9 &&
      (a.maxY - b.maxY).abs() <= 1e-9;
}
