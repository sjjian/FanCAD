import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _layers = 'Layers';

class LayerDeleteCommand extends FanCadCommand {
  const LayerDeleteCommand();

  @override
  String get id => 'layer.delete';
  @override
  String get title => 'Delete Layer';
  @override
  String get category => _layers;
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  String get description =>
      'Deletes a layer and everything on it. The layer named 0 cannot be '
      'deleted.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.layer),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText('name', 'Enter layer to delete:');
    if (name == '0') {
      return const CommandResult.failed('Layer 0 cannot be deleted.');
    }
    if (context.document.layer(name) == null) {
      return CommandResult.failed('There is no layer named "$name".');
    }
    final victims = [
      for (final entity in context.document.entities)
        if (entity.props.layer == name) entity.id,
    ];
    if (victims.isNotEmpty) {
      final proceed = await context.services.requestApproval(
        'Delete layer "$name"?',
        'This also deletes ${victims.length} object(s) on that layer.',
      );
      if (!proceed) return const CommandResult.cancelled();
    }
    final committed = context.edit('Delete Layer', (transaction) {
      if (context.document.currentLayer == name) {
        transaction.setCurrentLayer('0');
      }
      transaction
        ..eraseAll(victims)
        ..removeLayer(name);
    });
    if (committed == null) {
      return const CommandResult.failed('The layer was not deleted.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Deleted layer "$name" and ${victims.length} object(s).',
      transaction: committed,
    );
  }
}
