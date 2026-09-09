import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectByLinetypeCommand extends FanCadCommand {
  const SelectByLinetypeCommand();

  @override
  String get id => 'select.byLinetype';
  @override
  String get title => 'Select by Linetype';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['sellt'];
  @override
  String get description =>
      'Selects every object whose stored linetype matches a name, ByLayer '
      'or ByBlock. Layer-inherited DASHED is not the same as DASHED.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'linetype',
      type: ParamType.text,
      description: 'Linetype name, ByLayer or ByBlock',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final raw = await context.resolveText(
      'linetype',
      'Enter a linetype (DASHED, ByLayer, …):',
    );
    final name = raw.trim();
    if (name.isEmpty) {
      return const CommandResult.failed('Enter a linetype name.');
    }
    final needle = name.toLowerCase();
    final ids = [
      for (final entity in context.document.activeEntities)
        if (entity.props.lineType.toLowerCase() == needle &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(
      message: '${ids.length} object(s) selected with linetype $name.',
    );
  }
}
