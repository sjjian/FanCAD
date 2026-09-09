import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectByLineweightCommand extends FanCadCommand {
  const SelectByLineweightCommand();

  @override
  String get id => 'select.byLineweight';
  @override
  String get title => 'Select by Lineweight';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['sellw'];
  @override
  String get description =>
      'Selects every object whose stored lineweight matches a millimetre '
      'value, hundredths, ByLayer, ByBlock, Default or hairline. '
      'Layer-inherited 0.25 mm is not the same as 25.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'weight',
      type: ParamType.text,
      description: 'Millimetres, hundredths, ByLayer, ByBlock or hairline',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final raw = await context.resolveText(
      'weight',
      'Enter a lineweight (0.25 mm, 25, ByLayer):',
    );
    final weight = LineWeight.tryParse(raw);
    if (weight == null) {
      return CommandResult.failed(
        '"$raw" is not a lineweight. Use 0.25, 25, ByLayer, ByBlock, '
        'Default or hairline.',
      );
    }
    final ids = [
      for (final entity in context.document.activeEntities)
        if (entity.props.lineWeight == weight &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(
      message: '${ids.length} object(s) selected with lineweight $raw.',
    );
  }
}
