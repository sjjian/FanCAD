import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerShowAllCommand extends FanCadCommand {
  const LayerShowAllCommand();

  @override
  String get id => 'layer.showAll';
  @override
  String get title => 'Show All Layers';
  @override
  String get category => _layers;
  @override
  List<String> get aliases => const ['layuniso'];
  @override
  String get description => 'Turns every layer back on.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final hidden = [
      for (final layer in context.document.layers.values)
        if (!layer.visible) layer,
    ];
    if (hidden.isEmpty) {
      return const CommandResult.ok(message: 'All layers are already on.');
    }
    final committed = context.edit('Show All Layers', (transaction) {
      for (final layer in hidden) {
        transaction.putLayer(layer.copyWith(visible: true));
      }
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Turned on ${hidden.length} layer(s).',
      transaction: committed,
    );
  }
}
