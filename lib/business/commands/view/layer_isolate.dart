import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerIsolateCommand extends FanCadCommand {
  const LayerIsolateCommand();

  @override
  String get id => 'layer.isolate';
  @override
  String get title => 'Isolate Layer';
  @override
  String get category => _layers;
  @override
  List<String> get aliases => const ['layiso'];
  @override
  String get description => 'Turns off every layer except the named one.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.layer),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText('name', 'Enter layer to isolate:');
    if (context.document.layer(name) == null) {
      return CommandResult.failed('There is no layer named "$name".');
    }
    final committed = context.edit('Isolate Layer', (transaction) {
      for (final layer in context.document.layers.values) {
        transaction.putLayer(layer.copyWith(visible: layer.name == name));
      }
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Isolated layer "$name".',
      transaction: committed,
    );
  }
}
