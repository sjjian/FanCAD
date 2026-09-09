import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerToggleLockCommand extends FanCadCommand {
  const LayerToggleLockCommand();

  @override
  String get id => 'layer.toggleLock';
  @override
  String get title => 'Toggle Layer Lock';
  @override
  String get category => _layers;
  @override
  String get description =>
      'Locks or unlocks a layer. Objects on a locked layer stay visible but '
      'cannot be modified.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.layer),
    ParamSpec(
      name: 'locked',
      type: ParamType.boolean,
      description: 'Omit to toggle',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText('name', 'Enter layer name:');
    final layer = context.document.layer(name);
    if (layer == null) {
      return CommandResult.failed('There is no layer named "$name".');
    }
    final locked = context.args.boolean('locked') ?? !layer.locked;
    final committed = context.edit('Layer Lock', (transaction) {
      transaction.putLayer(layer.copyWith(locked: locked));
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Layer "$name" is now ${locked ? 'locked' : 'unlocked'}.',
      transaction: committed,
    );
  }
}
