import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QueryIdCommand extends FanCadCommand {
  const QueryIdCommand();

  @override
  String get id => 'query.id';
  @override
  String get title => 'ID Point';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['id'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Reports the X and Y coordinates of a point. Use this when you need '
      'a location, not a distance between two locations.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('at', description: 'The point to identify'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final at = await context.resolvePoint('at', 'ID  Specify point:');
    context.input.write(
      '  X = ${at.x.toStringAsFixed(4)}  Y = ${at.y.toStringAsFixed(4)}',
    );
    return CommandResult(
      status: CommandStatus.ok,
      message: 'X = ${at.x.toStringAsFixed(4)}, Y = ${at.y.toStringAsFixed(4)}',
      data: {'x': at.x, 'y': at.y},
    );
  }
}
