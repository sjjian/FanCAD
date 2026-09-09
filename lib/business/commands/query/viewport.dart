import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QueryViewportCommand extends FanCadCommand {
  const QueryViewportCommand();

  @override
  String get id => 'query.viewport';
  @override
  String get title => 'Query Viewport';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Returns the active camera: centre, scale and visible window as '
      '[minX, minY, maxX, maxY]. Pass that window to query.entities to '
      'list what the user is looking at.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final view = context.services.describeView();
    if (view.isEmpty) {
      return const CommandResult.failed('No view is open.');
    }
    final visible = view['visible'];
    final center = view['center'];
    final scale = view['scale'];
    final message = visible is List && visible.length >= 4
        ? 'Visible [${_num(visible[0])}, ${_num(visible[1])}, '
              '${_num(visible[2])}, ${_num(visible[3])}], '
              'scale ${_num(scale)}.'
        : center is List && center.length >= 2
        ? 'Viewport centre (${_num(center[0])}, ${_num(center[1])}), '
              'scale ${_num(scale)}; size is not known yet.'
        : 'Viewport reported.';
    return CommandResult(
      status: CommandStatus.ok,
      message: message,
      data: view,
    );
  }
}

String _num(Object? value) {
  if (value is num) return value.toStringAsFixed(2);
  return '$value';
}
