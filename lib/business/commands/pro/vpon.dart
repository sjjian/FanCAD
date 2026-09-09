import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'viewport_helpers.dart';

const _category = 'Output';

class LayoutVponCommand extends FanCadCommand {
  const LayoutVponCommand();

  @override
  String get id => 'layout.vpon';
  @override
  String get title => 'Viewport On';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['vpon', 'vpoff', 'mviewon', 'mviewoff'];
  @override
  String get description =>
      'Turns a paper viewport on or off. An off window keeps its frame '
      'but hides the model and is skipped when plotting. Omit on to toggle.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'on',
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
      description: 'A point on the viewport to switch',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layout = context.document.activeLayout;
    if (layout.isModelSpace) {
      return const CommandResult.failed('VPON only works on a paper layout.');
    }
    if (layout.viewports.isEmpty) {
      return const CommandResult.failed('This layout has no viewports.');
    }

    final index = await resolveViewportIndex(context, layout);
    if (index == null) {
      return const CommandResult.failed('No viewport was selected.');
    }
    final viewport = layout.viewports[index];
    final on = context.args.boolean('on') ?? !viewport.isOn;
    if (on == viewport.isOn) {
      return CommandResult.ok(
        message: 'Viewport is already ${on ? 'on' : 'off'}.',
        data: {'index': index, 'on': on},
      );
    }

    final committed = context.edit('Viewport on', (transaction) {
      final next = [...layout.viewports];
      next[index] = viewport.copyWith(isOn: on);
      transaction.putLayout(layout.copyWith(viewports: next));
    });
    if (committed == null) {
      return const CommandResult.failed('The viewport was not changed.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Viewport is now ${on ? 'on' : 'off'}.',
      data: {'index': index, 'on': on},
      transaction: committed,
    );
  }
}
