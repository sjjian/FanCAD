import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerPurgeCommand extends FanCadCommand {
  const LayerPurgeCommand();

  @override
  String get id => 'layer.purge';
  @override
  String get title => 'Purge Unused Layers';
  @override
  String get category => _layers;
  @override
  List<String> get aliases => const ['purge', 'pu'];
  @override
  String get description =>
      'Deletes layers that no object uses. Layer 0 is kept, and if the '
      'current layer is empty it is switched back to 0 before the purge.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final used = {
      for (final entity in context.document.entities) entity.props.layer,
    };
    final unused = [
      for (final name in context.document.layers.keys)
        if (name != '0' && !used.contains(name)) name,
    ]..sort();
    if (unused.isEmpty) {
      return const CommandResult.ok(message: 'No unused layers to purge.');
    }

    final committed = context.edit('Purge Layers', (transaction) {
      if (unused.contains(context.document.currentLayer)) {
        transaction.setCurrentLayer('0');
      }
      for (final name in unused) {
        transaction.removeLayer(name);
      }
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was purged.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Purged ${unused.length} unused layer(s).',
      data: {'layers': unused},
      transaction: committed,
    );
  }
}
