import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerSetCurrentCommand extends FanCadCommand {
  const LayerSetCurrentCommand();

  @override
  String get id => 'layer.setCurrent';
  @override
  String get title => 'Set Current Layer';
  @override
  String get category => _layers;
  @override
  List<String> get aliases => const ['clayer'];
  @override
  String get description => 'Chooses the layer new objects are created on.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.layer),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText('name', 'Enter layer name:');
    if (context.document.layer(name) == null) {
      return CommandResult.failed('There is no layer named "$name".');
    }
    final committed = context.edit('Current Layer', (transaction) {
      transaction.setCurrentLayer(name);
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Current layer is now "$name".',
      transaction: committed,
    );
  }
}
