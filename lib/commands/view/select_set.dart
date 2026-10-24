import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

/// Replaces the selection with an explicit id list.
class SelectSetCommand extends FanCadCommand {
  const SelectSetCommand();

  @override
  String get id => 'select.set';
  @override
  String get title => 'Set Selection';
  @override
  String get category => _select;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Replaces the current selection with the given entity ids. '
      'Unknown ids are dropped. An empty list clears the selection.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'ids',
      type: ParamType.selection,
      description: 'Entity ids that become the selection',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    if (!context.args.has('ids')) {
      return const CommandResult.failed('select.set needs ids');
    }
    final ids = context.args.ids('ids') ?? const <int>[];
    final kept = [
      for (final id in ids)
        if (context.document.entity(id) != null) id,
    ];
    context.selection.replace(kept);
    return CommandResult.ok(
      message: kept.isEmpty
          ? 'Nothing is selected.'
          : '${kept.length} object(s) selected.',
      data: {'ids': context.selection.ids.toList()},
    );
  }
}
