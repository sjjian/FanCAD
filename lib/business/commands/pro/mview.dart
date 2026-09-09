import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Output';

class LayoutMviewCommand extends FanCadCommand {
  const LayoutMviewCommand();

  @override
  String get id => 'layout.mview';
  @override
  String get title => 'Make Viewport';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['mview', 'mv'];
  @override
  String get description =>
      'Cuts a window on the current paper layout that looks into model '
      'space. The model is framed in the rectangle unless a scale is '
      'supplied.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('corner1', description: 'First corner on the sheet'),
    ParamSpec.point('corner2', description: 'Opposite corner on the sheet'),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Model units per paper unit. Omit to fit the model.',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layout = context.document.activeLayout;
    if (layout.isModelSpace) {
      return const CommandResult.failed('MVIEW only works on a paper layout.');
    }

    final first = await context.resolvePoint(
      'corner1',
      'MVIEW  Specify first corner:',
    );
    context.input.setPreview((cursor) => [OverlayRect(first, cursor)]);
    final second = await context.resolvePoint(
      'corner2',
      'MVIEW  Specify opposite corner:',
      basePoint: first,
    );
    context.input.setPreview(null);

    final paper = Bounds2.fromCorners(first, second);
    if (paper.width <= 0 || paper.height <= 0) {
      return const CommandResult.failed('The viewport has no area.');
    }

    final model = context.document.boundsOf(
      context.document.modelSpaceBlockName,
    );
    final supplied = context.args.number('scale');
    var scale = 1.0;
    if (supplied != null && supplied > 0) {
      scale = supplied;
    } else if (model.isNotEmpty) {
      final candidates = <double>[
        if (model.width > 0) paper.width / model.width,
        if (model.height > 0) paper.height / model.height,
      ];
      if (candidates.isNotEmpty) {
        scale = candidates.reduce(math.min);
      }
    }

    final viewport = PaperViewport(
      paperBounds: paper,
      modelCenter: model.isEmpty ? const Vec2.zero() : model.center,
      scale: scale,
      layer: context.document.currentLayer,
    );
    final committed = context.edit('MVIEW', (transaction) {
      transaction.putLayout(
        layout.copyWith(viewports: [...layout.viewports, viewport]),
      );
    });
    if (committed == null) {
      return const CommandResult.failed('The viewport was not created.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Viewport added to ${layout.name}.',
      data: {
        'layout': layout.name,
        'viewports': context.document.activeLayout.viewports.length,
        'scale': scale,
      },
      transaction: committed,
    );
  }
}
