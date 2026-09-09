import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditMoveCommand extends FanCadCommand {
  const EditMoveCommand();

  @override
  String get id => 'edit.move';
  @override
  String get title => 'Move';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['m', 'move'];
  @override
  String? get icon => 'move';
  @override
  String get description => 'Moves the selected objects by a displacement.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('from', description: 'Base point'),
    ParamSpec.point('to', description: 'Destination of the base point'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) => editTransform(
    context,
    label: 'Move',
    verb: 'MOVE',
    copy: false,
    matrix: (from, to) => Mat3.translation(to.x - from.x, to.y - from.y),
  );
}
