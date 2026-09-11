import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditTextObjectCommand extends FanCadCommand {
  const EditTextObjectCommand();

  @override
  String get id => 'edit.textObject';
  @override
  String get title => 'Edit Text Object';
  @override
  String get category => _category;
  @override
  String get description =>
      'Updates content, height, colour and justification of selected text, '
      'mtext, attributes or leaders in one undo. Dimension text height is '
      'a dimstyle property and is ignored.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'text',
      type: ParamType.text,
      description: 'New content, or dimension override',
      required: false,
    ),
    ParamSpec(
      name: 'height',
      type: ParamType.number,
      description: 'Cap height in drawing units',
      required: false,
    ),
    ParamSpec(
      name: 'color',
      type: ParamType.text,
      description: 'ACI index, #rrggbb, ByLayer or ByBlock',
      required: false,
    ),
    ParamSpec(
      name: 'justify',
      type: ParamType.text,
      description: 'Left, Center, Right, TL, TC, TR, ML, MC, MR, BL, BC, BR',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'Select text objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <CadEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final CadEntity entity)
          if (isTextEditTarget(entity)) entity,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed(
        'Select text, mtext, an attribute or a dimension.',
      );
    }

    final hasText = context.args.has('text');
    final hasHeight = context.args.has('height');
    final hasColor = context.args.has('color');
    final hasJustify = context.args.has('justify');
    if (!hasText && !hasHeight && !hasColor && !hasJustify) {
      return const CommandResult.failed(
        'Specify text, height, colour or justification.',
      );
    }

    final text = hasText ? (context.args.text('text') ?? '') : null;
    final height = hasHeight ? context.args.number('height') : null;
    if (hasHeight && (height == null || height <= 0)) {
      return const CommandResult.failed('Text height must be positive.');
    }
    final color = hasColor
        ? cadColorFromJson(context.args.text('color'))
        : null;
    final justify = hasJustify
        ? (context.args.text('justify') ?? '').trim()
        : null;
    if (hasJustify &&
        (justify == null ||
            Construct.parseTextJustify(
                  justify,
                  currentH: TextHAlign.left,
                  currentV: TextVAlign.baseline,
                ) ==
                null ||
            const {'a', 'align', 'aligned', 'f', 'fit'}.contains(
              justify.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ''),
            ))) {
      return CommandResult.failed(
        '"$justify" is not a justification. Use Left, Center, Right or '
        'a corner code such as TL.',
      );
    }
    if (text != null &&
        targets.any(textEditRequiresContent) &&
        text.isEmpty) {
      return const CommandResult.failed('Text cannot be empty.');
    }

    final committed = context.edit('Edit Text', (transaction) {
      for (final entity in targets) {
        var next = entity;
        if (text != null) {
          next = entityWithEditedText(next, text) ?? next;
        }
        if (height != null) {
          next = entityWithHeight(next, height) ?? next;
        }
        if (justify != null && justify.isNotEmpty) {
          next = entityWithJustify(next, justify) ?? next;
        }
        if (color != null && next.props.color != color) {
          next = next.withProps(next.props.copyWith(color: color));
        }
        if (!identical(next, entity)) transaction.modify(next);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the objects already have those values, or '
        'they are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Edited ${committed.change.modified.length} text object(s).',
      transaction: committed,
    );
  }
}
