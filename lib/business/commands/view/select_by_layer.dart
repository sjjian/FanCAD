import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectByLayerCommand extends FanCadCommand {
  const SelectByLayerCommand();

  @override
  String get id => 'select.byLayer';
  @override
  String get title => 'Select by Layer';
  @override
  String get category => _select;
  @override
  String get description => 'Selects every object on a named layer.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'layer', type: ParamType.layer),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layer = await context.resolveText('layer', 'Enter layer name:');
    if (context.document.layer(layer) == null) {
      return CommandResult.failed('There is no layer named "$layer".');
    }
    final ids = [
      for (final entity in context.document.activeEntities)
        if (entity.props.layer == layer &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(
      message: '${ids.length} object(s) selected on "$layer".',
    );
  }
}
