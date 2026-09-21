import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'viewport_helpers.dart';

const _category = 'Output';

class LayoutVplockCommand extends FanCadCommand {
  const LayoutVplockCommand();

  @override
  String get id => 'layout.vplock';
  @override
  String get title => 'Viewport Lock';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['vplock', 'mviewlock'];
  @override
  String get description =>
      'Locks or unlocks a paper viewport so VPSCALE cannot change the '
      'view. Omit locked to toggle. The window frame can still move.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'locked',
      type: ParamType.boolean,
      description: 'Omit to toggle',
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
      description: 'A point on the viewport to lock',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layout = context.document.activeLayout;
    if (layout.isModelSpace) {
      return const CommandResult.failed('VPLOCK only works on a paper layout.');
    }
    if (layout.viewports.isEmpty) {
      return const CommandResult.failed('This layout has no viewports.');
    }

    final index = await resolveViewportIndex(context, layout);
    if (index == null) {
      return const CommandResult.failed('No viewport was selected.');
    }
    final viewport = layout.viewports[index];
    final locked = context.args.boolean('locked') ?? !viewport.locked;
    if (locked == viewport.locked) {
      return CommandResult.ok(
        message: 'Viewport is already ${locked ? 'locked' : 'unlocked'}.',
        data: {'index': index, 'locked': locked},
      );
    }

    final committed = context.edit('Viewport lock', (transaction) {
      final next = [...layout.viewports];
      next[index] = viewport.copyWith(locked: locked);
      transaction.putLayout(layout.copyWith(viewports: next));
    });
    if (committed == null) {
      return const CommandResult.failed('The lock was not changed.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Viewport is now ${locked ? 'locked' : 'unlocked'}.',
      data: {'index': index, 'locked': locked},
      transaction: committed,
    );
  }
}
