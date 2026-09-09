import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerToggleVisibleCommand extends FanCadCommand {
  const LayerToggleVisibleCommand();

  @override
  String get id => 'layer.toggleVisible';
  @override
  String get title => 'Toggle Layer Visibility';
  @override
  String get category => _layers;
  @override
  String get description => 'Turns a layer on or off.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.layer),
    ParamSpec(
      name: 'visible',
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
    final visible = context.args.boolean('visible') ?? !layer.visible;
    final committed = context.edit('Layer Visibility', (transaction) {
      transaction.putLayer(layer.copyWith(visible: visible));
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Layer "$name" is now ${visible ? 'on' : 'off'}.',
      transaction: committed,
    );
  }
}
