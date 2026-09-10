import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditTextContentCommand extends FanCadCommand {
  const EditTextContentCommand();

  @override
  String get id => 'edit.textContent';
  @override
  String get title => 'Edit Text';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ddedit', 'ted'];
  @override
  String get description =>
      'Changes the content of selected text, mtext, dimensions, '
      'attributes or leaders. On a dimension, empty restores the measured '
      'value and <> stands for that value, same as DIMEDIT.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'text',
      type: ParamType.text,
      description: 'New content, or dimension override',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'DDEDIT  Select text, mtext or a dimension:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <CadEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final CadEntity entity)
          if (isTextEditTarget(entity)) entity,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed(
        'Select text, mtext or a dimension to edit.',
      );
    }

    final incoming = context.args.has('text')
        ? (context.args.text('text') ?? '')
        : await context.input.text(
            'DDEDIT  Enter new text:',
            defaultValue: textEditFieldValue(targets.first),
          );
    final text = context.args.has('text')
        ? incoming
        : textEditCommitValue(targets.first, incoming);
    if (targets.any(textEditRequiresContent) && text.isEmpty) {
      return const CommandResult.failed('Text cannot be empty.');
    }

    final committed = context.edit('Edit Text', (transaction) {
      for (final entity in targets) {
        final updated = entityWithEditedText(entity, text);
        if (updated != null) transaction.modify(updated);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the text is already that value, or the '
        'objects are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Edited ${committed.change.modified.length} text object(s).',
      transaction: committed,
    );
  }
}
