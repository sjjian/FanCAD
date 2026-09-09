import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'viewport_helpers.dart';

const _category = 'Output';

class LayoutVplayerCommand extends FanCadCommand {
  const LayoutVplayerCommand();

  @override
  String get id => 'layout.vplayer';
  @override
  String get title => 'Viewport Layer Freeze';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['vplayer', 'vpfreeze', 'vpthaw'];
  @override
  String get description =>
      'Freezes or thaws layers in one paper viewport. Other windows and '
      'model space keep their own visibility. Omit freeze to freeze.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'layers',
      type: ParamType.text,
      description: 'Layer name, or a comma-separated list',
    ),
    ParamSpec(
      name: 'freeze',
      type: ParamType.boolean,
      description: 'true freezes, false thaws. Defaults to freeze',
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
      description: 'A point on the viewport to edit',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layout = context.document.activeLayout;
    if (layout.isModelSpace) {
      return const CommandResult.failed(
        'VPLAYER only works on a paper layout.',
      );
    }
    if (layout.viewports.isEmpty) {
      return const CommandResult.failed('This layout has no viewports.');
    }

    final index = await resolveViewportIndex(context, layout);
    if (index == null) {
      return const CommandResult.failed('No viewport was selected.');
    }

    final raw = await context.resolveText(
      'layers',
      'VPLAYER  Enter layer name(s):',
    );
    final requested = [
      for (final part in raw.split(RegExp(r'[,;]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    if (requested.isEmpty) {
      return const CommandResult.failed('Supply at least one layer name.');
    }

    final resolved = <String>[];
    for (final name in requested) {
      final layer = layerNamed(context.document, name);
      if (layer == null) {
        return CommandResult.failed('There is no layer named "$name".');
      }
      resolved.add(layer.name);
    }

    final viewport = layout.viewports[index];
    final freeze = context.args.boolean('freeze') ?? true;
    final nextFrozen = <String>[
      for (final name in viewport.frozenLayers)
        if (freeze ||
            !resolved.any((item) => item.toLowerCase() == name.toLowerCase()))
          name,
    ];
    if (freeze) {
      for (final name in resolved) {
        if (!nextFrozen.any(
          (item) => item.toLowerCase() == name.toLowerCase(),
        )) {
          nextFrozen.add(name);
        }
      }
    }
    if (sameLayerNames(nextFrozen, viewport.frozenLayers)) {
      return CommandResult.ok(
        message: freeze
            ? 'Those layers are already frozen in the viewport.'
            : 'Those layers are already thawed in the viewport.',
        data: {'index': index, 'frozen': viewport.frozenLayers},
      );
    }

    final committed = context.edit('Viewport layer', (transaction) {
      final next = [...layout.viewports];
      next[index] = viewport.copyWith(frozenLayers: nextFrozen);
      transaction.putLayout(layout.copyWith(viewports: next));
    });
    if (committed == null) {
      return const CommandResult.failed(
        'The viewport layers were not changed.',
      );
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: freeze
          ? 'Froze ${resolved.length} layer(s) in viewport $index.'
          : 'Thawed ${resolved.length} layer(s) in viewport $index.',
      data: {'index': index, 'frozen': nextFrozen, 'changed': resolved},
      transaction: committed,
    );
  }
}
