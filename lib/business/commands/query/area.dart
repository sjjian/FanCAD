import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QueryAreaCommand extends FanCadCommand {
  const QueryAreaCommand();

  @override
  String get id => 'query.area';
  @override
  String get title => 'Area';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['aa', 'area'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Reports the area and perimeter of the selected closed objects.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'AREA  Select closed objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    var area = 0.0;
    var perimeter = 0.0;
    var counted = 0;
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      final each = Construct.areaOf(entity).abs();
      if (each == 0) continue;
      area += each;
      perimeter += Construct.lengthOf(entity);
      counted++;
    }
    if (counted == 0) {
      return const CommandResult.failed(
        'None of the selected objects enclose an area.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Area = ${area.toStringAsFixed(4)}, '
          'perimeter = ${perimeter.toStringAsFixed(4)} '
          '($counted object(s)).',
      data: {'area': area, 'perimeter': perimeter, 'count': counted},
    );
  }
}
