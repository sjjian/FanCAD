import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QueryLayersCommand extends FanCadCommand {
  const QueryLayersCommand();

  @override
  String get id => 'query.layers';
  @override
  String get title => 'List Layers';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Returns every layer with its state and object count.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final counts = <String, int>{};
    for (final entity in context.document.entities) {
      counts.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
    }
    final layers = [
      for (final layer in context.document.layers.values)
        {
          'name': layer.name,
          'color': cadColorToJson(layer.color),
          'lineType': layer.lineType,
          'visible': layer.visible,
          'frozen': layer.frozen,
          'locked': layer.locked,
          'current': layer.name == context.document.currentLayer,
          'count': counts[layer.name] ?? 0,
        },
    ];
    return CommandResult(
      status: CommandStatus.ok,
      message: '${layers.length} layer(s).',
      data: {'layers': layers},
    );
  }
}
