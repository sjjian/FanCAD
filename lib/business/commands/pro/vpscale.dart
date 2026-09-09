import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'viewport_helpers.dart';

const _category = 'Output';

class LayoutVpscaleCommand extends FanCadCommand {
  const LayoutVpscaleCommand();

  @override
  String get id => 'layout.vpscale';
  @override
  String get title => 'Viewport Scale';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['vpscale', 'zoomvp'];
  @override
  String get description =>
      'Sets the scale of a paper viewport (model units per paper unit). '
      'Pass fit=true to frame the model again. A locked viewport is refused.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Model units per paper unit',
      required: false,
    ),
    ParamSpec(
      name: 'fit',
      type: ParamType.boolean,
      description: 'Frame the model in the window',
      required: false,
    ),
    ParamSpec(
      name: 'index',
      type: ParamType.integer,
      description: 'Viewport index on the current layout, from 0',
      required: false,
    ),
    ParamSpec(
      name: 'point',
      type: ParamType.point,
      description: 'A point on the viewport to scale',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layout = context.document.activeLayout;
    if (layout.isModelSpace) {
      return const CommandResult.failed(
        'VPSCALE only works on a paper layout.',
      );
    }
    if (layout.viewports.isEmpty) {
      return const CommandResult.failed('This layout has no viewports.');
    }

    final index = await resolveViewportIndex(context, layout);
    if (index == null) {
      return const CommandResult.failed('No viewport was selected.');
    }
    final viewport = layout.viewports[index];
    if (viewport.locked) {
      return const CommandResult.failed('The viewport is locked.');
    }

    final fit = context.args.boolean('fit') ?? false;
    late final double scale;
    var center = viewport.modelCenter;
    if (fit) {
      final model = context.document.boundsOf(
        context.document.modelSpaceBlockName,
      );
      final paper = viewport.paperBounds;
      var next = 1.0;
      if (model.isNotEmpty) {
        final candidates = <double>[
          if (model.width > 0) paper.width / model.width,
          if (model.height > 0) paper.height / model.height,
        ];
        if (candidates.isNotEmpty) next = candidates.reduce(math.min);
        center = model.center;
      }
      scale = next;
    } else {
      scale =
          context.args.number('scale') ??
          await context.resolveNumber(
            'scale',
            'Viewport scale (model / paper):',
            defaultValue: viewport.scale,
          );
    }
    if (scale <= 0) {
      return const CommandResult.failed('Scale must be positive.');
    }
    if (scale == viewport.scale && center == viewport.modelCenter) {
      return CommandResult.ok(
        message: 'Viewport scale is already $scale.',
        data: {'index': index, 'scale': scale},
      );
    }

    final committed = context.edit('Viewport scale', (transaction) {
      final next = [...layout.viewports];
      next[index] = viewport.copyWith(scale: scale, modelCenter: center);
      transaction.putLayout(layout.copyWith(viewports: next));
    });
    if (committed == null) {
      return const CommandResult.failed('The scale was not changed.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Viewport scale is $scale.',
      data: {'index': index, 'scale': scale},
      transaction: committed,
    );
  }
}
