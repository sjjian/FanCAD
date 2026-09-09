import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditDimensionTextCommand extends FanCadCommand {
  const EditDimensionTextCommand();

  @override
  String get id => 'edit.dimensionText';
  @override
  String get title => 'Dimension Text';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimedit', 'dimtext'];
  @override
  String get description =>
      'Overrides the text of selected dimensions. Empty restores the '
      'measured value; <> stands for that value; a single space hides '
      'the text.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'text',
      type: ParamType.text,
      description: 'Override text, empty for measured, space to hide',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'DIMEDIT  Select dimensions:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <DimensionEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final DimensionEntity dim) dim,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed('Select at least one dimension.');
    }

    final text = context.args.has('text')
        ? (context.args.text('text') ?? '')
        : await context.input.text(
            'DIMEDIT  Enter dimension text (<> = measured):',
            defaultValue: targets.first.overrideText,
          );

    final committed = context.edit('Dimension Text', (transaction) {
      for (final dim in targets) {
        if (dim.overrideText == text) continue;
        transaction.modify(
          DimensionEntity(
            id: dim.id,
            props: dim.props,
            definitionPoints: dim.definitionPoints,
            textPosition: dim.textPosition,
            measurement: dim.measurement,
            overrideText: text,
            styleName: dim.styleName,
            dimensionType: dim.dimensionType,
          ),
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the text is already that value, or the '
        'dimensions are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Set text on ${committed.change.modified.length} dimension(s).',
      transaction: committed,
    );
  }
}
